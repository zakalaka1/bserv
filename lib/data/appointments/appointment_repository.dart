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
    required this.serviceType,
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

  /// What the customer booked, for example `maintain heat`.
  final String serviceType;
  final XFile? photo;
}

/// Normalizes a phone number to `999-999-9999` for storage.
///
/// The form accepts `9999999999`, `999-999-9999`, and `999-9999999`; every one
/// of those becomes `999-999-9999`. Input that does not carry 10 digits is
/// returned trimmed so nothing is silently lost. Applying this twice is safe.
String formatPhoneNumber(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-'
        '${digits.substring(6)}';
  }
  return input.trim();
}

/// Normalizes a postal code to `A9A 9A9` for storage (uppercase, one space
/// after the third character). Accepts `A9A9A9` and `A9A 9A9`, any case.
/// Input without six alphanumerics is returned trimmed and uppercased. Applying
/// this twice is safe.
String formatPostalCode(String input) {
  final characters = input
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toUpperCase();
  if (characters.length == 6) {
    return '${characters.substring(0, 3)} ${characters.substring(3)}';
  }
  return input.trim().toUpperCase();
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
    this.adminNote = '',
    this.serviceType = '',
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

  /// Admin-only free-text note about this booking; blank when none was saved.
  final String adminNote;

  /// The booked service, for example `maintain heat`; blank for older records.
  final String serviceType;

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
      adminNote: data['adminNote'] as String? ?? '',
      serviceType: data['serviceType'] as String? ?? '',
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

  /// Every customer appointment on [date]; blocked-off entries are excluded.
  Stream<List<AppointmentRecord>> watchAppointmentsByDate(DateTime date);

  /// A download URL for a stored appointment photo, or null if unavailable.
  Future<String?> appointmentPhotoUrl(String photoPath);

  /// Marks [appointmentId] `completed` or `cancelled` (admin only).
  Future<void> updateAppointmentStatus(String appointmentId, String status);

  /// Stores the admin's free-text note on [appointmentId]; an empty [note]
  /// clears it.
  Future<void> updateAppointmentNote(String appointmentId, String note);

  /// Cancels the signed-in customer's own appointment and frees its time slot
  /// so another customer can book it.
  Future<void> cancelAppointment(AppointmentRecord appointment);

  /// Edits the signed-in customer's own appointment, changing only the fields
  /// that are provided. A [photo] is uploaded and stored as an attachment; the
  /// booking rules allow adding a photo only when none is stored yet.
  Future<void> updateOwnAppointment(
    String appointmentId, {
    String? customerName,
    String? issueDescription,
    XFile? photo,
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
        'phone': formatPhoneNumber(draft.phone),
        'streetAddress': draft.streetAddress.trim(),
        'city': draft.city.trim(),
        'postalCode': formatPostalCode(draft.postalCode),
        'issueDescription': draft.issueDescription.trim(),
        'serviceType': draft.serviceType.trim(),
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

  @override
  Stream<List<AppointmentRecord>> watchAppointmentsByDate(DateTime date) {
    // A single equality filter keeps this on the automatic single-field index;
    // blocked-off entries are dropped in Dart because they are not bookings.
    return _firestore
        .collection('appointments')
        .where(
          'appointmentDate',
          isEqualTo: Timestamp.fromDate(_dateOnly(date)),
        )
        .snapshots()
        .map(
          (snapshot) => [
            for (final document in snapshot.docs)
              if (document.data()['status'] != 'blockedoff')
                AppointmentRecord.fromDocument(document),
          ],
        );
  }

  @override
  Future<String?> appointmentPhotoUrl(String photoPath) async {
    try {
      return await _storage.ref(photoPath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    String status,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An authenticated admin user is required.');
    }

    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
    });
  }

  @override
  Future<void> updateAppointmentNote(String appointmentId, String note) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An authenticated admin user is required.');
    }

    // An empty string keeps the field always present, which keeps the
    // Firestore rule simple and lets the admin clear a note.
    await _firestore.collection('appointments').doc(appointmentId).update({
      'adminNote': note.trim(),
    });
  }

  @override
  Future<void> cancelAppointment(AppointmentRecord appointment) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An authenticated user is required to cancel.');
    }

    final day = _dateOnly(appointment.appointmentDate);
    final batch = _firestore.batch();
    batch.update(_firestore.collection('appointments').doc(appointment.id), {
      'status': 'cancelled',
    });
    // Releasing the slot lets another customer book the same time.
    batch.delete(
      _firestore
          .collection('bookedSlots')
          .doc(_slotId(day, appointment.timeSlot)),
    );
    await batch.commit();
  }

  @override
  Future<void> updateOwnAppointment(
    String appointmentId, {
    String? customerName,
    String? issueDescription,
    XFile? photo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An authenticated user is required to update.');
    }

    String? photoPath;
    try {
      if (photo != null) {
        final reference = _storage
            .ref('appointment-photos/${user.uid}/$appointmentId')
            .child(_safeFileName(photo.name));
        final Uint8List bytes = await photo.readAsBytes();
        await reference.putData(
          bytes,
          SettableMetadata(contentType: _contentType(photo.name)),
        );
        photoPath = reference.fullPath;
      }

      final updates = <String, Object>{
        if (customerName != null) 'customerName': customerName.trim(),
        if (issueDescription != null)
          'issueDescription': issueDescription.trim(),
        'photoPath': ?photoPath,
      };
      if (updates.isEmpty) return;

      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update(updates);
    } catch (_) {
      // Do not leave an orphaned object behind when the document write fails.
      if (photoPath != null) {
        try {
          await _storage.ref(photoPath).delete();
        } catch (_) {}
      }
      rethrow;
    }
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
