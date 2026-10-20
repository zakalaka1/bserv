import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusinessContent {
  const BusinessContent({required this.notes, required this.pricing});

  final String notes;
  final String pricing;
}

abstract interface class BusinessContentRepository {
  Stream<BusinessContent> watchContent({
    required String defaultNotes,
    required String defaultPricing,
  });

  Future<void> saveContent({required String notes, required String pricing});
}

class FirebaseBusinessContentRepository implements BusinessContentRepository {
  FirebaseBusinessContentRepository(this._firestore, this._auth);

  static const _documentPath = 'publicContent/notesAndPricing';
  static const _maxNotesLength = 2000;
  static const _maxPricingLength = 2000;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<BusinessContent> watchContent({
    required String defaultNotes,
    required String defaultPricing,
  }) {
    return _firestore.doc(_documentPath).snapshots().map((snapshot) {
      final data = snapshot.data();
      return BusinessContent(
        notes: data?['notes'] as String? ?? defaultNotes,
        pricing: data?['pricing'] as String? ?? defaultPricing,
      );
    });
  }

  @override
  Future<void> saveContent({
    required String notes,
    required String pricing,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        'An admin user must be signed in to update public content.',
      );
    }

    final token = await user.getIdTokenResult(true);
    if (token.claims?['admin'] != true) {
      throw StateError('Only an admin user can update public content.');
    }
    if (notes.length > _maxNotesLength || pricing.length > _maxPricingLength) {
      throw ArgumentError('Public content exceeds the allowed length.');
    }

    await _firestore.doc(_documentPath).set({
      'notes': notes.trim(),
      'pricing': pricing.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }
}
