import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin-only running notes stored as a single Firestore document.
class WorkNotes {
  const WorkNotes({required this.notes});

  final String notes;
}

abstract interface class WorkNotesRepository {
  Stream<WorkNotes> watchWorkNotes({required String defaultNotes});

  Future<void> saveWorkNotes(String notes);
}

class FirebaseWorkNotesRepository implements WorkNotesRepository {
  FirebaseWorkNotesRepository(this._firestore, this._auth);

  static const _documentPath = 'workNotes/main';
  static const _maxNotesLength = 32000;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<WorkNotes> watchWorkNotes({required String defaultNotes}) {
    return _firestore.doc(_documentPath).snapshots().map((snapshot) {
      final data = snapshot.data();
      return WorkNotes(notes: data?['notes'] as String? ?? defaultNotes);
    });
  }

  @override
  Future<void> saveWorkNotes(String notes) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An admin user must be signed in to update work notes.');
    }

    final token = await user.getIdTokenResult(true);
    if (token.claims?['admin'] != true) {
      throw StateError('Only an admin user can update work notes.');
    }
    if (notes.length > _maxNotesLength) {
      throw ArgumentError('Work notes exceed the allowed length.');
    }

    await _firestore.doc(_documentPath).set({
      'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }
}
