import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AppointmentDraft {
  const AppointmentDraft({
    required this.appointmentDate,
    required this.timeSlot,
    required this.customerName,
    required this.phone,
    required this.streetAddress,
    required this.city,
    required this.postalCode,
    required this.issueDescription,
    this.photo,
  });

  final DateTime appointmentDate;
  final String timeSlot;
  final String customerName;
  final String phone;
  final String streetAddress;
  final String city;
  final String postalCode;
  final String issueDescription;
  final XFile? photo;
}

class AppointmentRecord {
  const AppointmentRecord({
    required this.id,
    required this.appointmentDate,
    required this.timeSlot,
    required this.customerName,
    required this.phone,
    required this.streetAddress,
    required this.city,
    required this.postalCode,
    required this.issueDescription,
    required this.status,
    required this.createdAt,
    this.photoPath,
  });

  final String id;
  final DateTime appointmentDate;
  final String timeSlot;
  final String customerName;
  final String phone;
  final String streetAddress;
  final String city;
  final String postalCode;
  final String issueDescription;
  final String status;
  final DateTime createdAt;
  final String? photoPath;

  factory AppointmentRecord.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return AppointmentRecord(
      id: document.id,
      appointmentDate: (data['appointmentDate'] as Timestamp).toDate(),
      timeSlot: data['timeSlot'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      streetAddress: data['streetAddress'] as String? ?? '',
      city: data['city'] as String? ?? '',
      postalCode: data['postalCode'] as String? ?? '',
      issueDescription: data['issueDescription'] as String? ?? '',
      status: data['status'] as String? ?? 'scheduled',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970),
      photoPath: data['photoPath'] as String?,
    );
  }
}

/// One blocked-off time slot, stored as an appointment with status `blockedoff`.
class BlockedOffTime {
  const BlockedOffTime({required this.date, required this.timeSlot});

  final DateTime date;
  final String timeSlot;
}

/// A date and time slot that is no longer bookable (booked or blocked off).
class BookedSlot {
  const BookedSlot({required this.date, required this.timeSlot});

  final DateTime date;
  final String timeSlot;
}

abstract interface class AppointmentRepository {
  Future<void> createAppointment(AppointmentDraft draft);

  Stream<AppointmentRecord?> watchLatestAppointment();

  /// Upcoming unavailable slots; safe for any signed-in user (no personal data).
  Stream<List<BookedSlot>> watchBookedSlots();

  Stream<List<BlockedOffTime>> watchBlockedOffTimes();

  /// Blocks and unblocks slots of [date] in one atomic write (admin only).
  Future<void> updateBlockedOffTimes(
    DateTime date, {
    required Set<String> block,
    required Set<String> unblock,
  });
}

class FirebaseAppointmentRepository implements AppointmentRepository {
  FirebaseAppointmentRepository(this._firestore, this._storage, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  @override
  Future<void> createAppointment(AppointmentDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An authenticated user is required to book.');
    }

    final appointment = _firestore.collection('appointments').doc();
    String? photoPath;

    try {
      final photo = draft.photo;
      if (photo != null) {
        final reference = _storage
            .ref('appointment-photos/${user.uid}/${appointment.id}')
            .child(_safeFileName(photo.name));
        final Uint8List bytes = await photo.readAsBytes();
        await reference.putData(
          bytes,
          SettableMetadata(contentType: _contentType(photo.name)),
        );
        photoPath = reference.fullPath;
      }

      final day = _dateOnly(draft.appointmentDate);
      final batch = _firestore.batch();
      batch.set(appointment, {
        'appointmentDate': Timestamp.fromDate(day),
        'timeSlot': draft.timeSlot,
        'customerName': draft.customerName.trim(),
        'phone': draft.phone.trim(),
        'streetAddress': draft.streetAddress.trim(),
        'city': draft.city.trim(),
        'postalCode': draft.postalCode.trim().toUpperCase(),
        'issueDescription': draft.issueDescription.trim(),
        'userId': user.uid,
        'userEmail': ?user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'scheduled',
        'photoPath': ?photoPath,
      });
      // Fails if another user already took this slot (document exists).
      batch.set(
        _firestore.collection('bookedSlots').doc(_slotId(day, draft.timeSlot)),
        {
          'appointmentDate': Timestamp.fromDate(day),
          'timeSlot': draft.timeSlot,
          'appointmentId': appointment.id,
        },
      );
      await batch.commit();
    } catch (_) {
      if (photoPath != null) {
        try {
          await _storage.ref(photoPath).delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Stream<AppointmentRecord?> watchLatestAppointment() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : AppointmentRecord.fromDocument(snapshot.docs.first),
        );
  }

  @override
  Stream<List<BookedSlot>> watchBookedSlots() {
    return _firestore
        .collection('bookedSlots')
        .where(
          'appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_dateOnly(DateTime.now())),
        )
        .snapshots()
        .map(
          (snapshot) => [
            for (final document in snapshot.docs)
              BookedSlot(
                date: _dateOnly(
                  (document.data()['appointmentDate'] as Timestamp).toDate(),
                ),
                timeSlot: document.data()['timeSlot'] as String? ?? '',
              ),
          ],
        );
  }

  @override
  Stream<List<BlockedOffTime>> watchBlockedOffTimes() {
    return _firestore
        .collection('appointments')
        .where('status', isEqualTo: 'blockedoff')
        .snapshots()
        .map(
          (snapshot) => [
            for (final document in snapshot.docs)
              BlockedOffTime(
                date: _dateOnly(
                  (document.data()['appointmentDate'] as Timestamp).toDate(),
                ),
                timeSlot: document.data()['timeSlot'] as String? ?? '',
              ),
          ],
        );
  }

  @override
  Future<void> updateBlockedOffTimes(
    DateTime date, {
    required Set<String> block,
    required Set<String> unblock,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An authenticated admin user is required.');
    }

    final day = DateTime(date.year, date.month, date.day);
    final batch = _firestore.batch();
    for (final slot in block) {
      final id = _slotId(day, slot);
      batch.set(_firestore.collection('appointments').doc(id), {
        'appointmentDate': Timestamp.fromDate(day),
        'timeSlot': slot,
        'status': 'blockedoff',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('bookedSlots').doc(id), {
        'appointmentDate': Timestamp.fromDate(day),
        'timeSlot': slot,
        'appointmentId': id,
      });
    }
    for (final slot in unblock) {
      final id = _slotId(day, slot);
      batch.delete(_firestore.collection('appointments').doc(id));
      batch.delete(_firestore.collection('bookedSlots').doc(id));
    }
    await batch.commit();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  // Deterministic ID: a date+slot can only be taken once.
  String _slotId(DateTime day, String slot) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    final slotKey = slot.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    return 'slot-${day.year}$month$dayOfMonth-$slotKey';
  }

  String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  String _contentType(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}
