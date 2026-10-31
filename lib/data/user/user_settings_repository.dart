import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// The layout preferences a signed-in user keeps between sessions.
class UserSettings {
  const UserSettings({required this.isLeftHanded, required this.themeMode});

  /// What an account that has never saved any settings starts from: the
  /// right-handed layout that follows the device's light/dark mode.
  static const defaults = UserSettings(
    isLeftHanded: false,
    themeMode: ThemeMode.system,
  );

  final bool isLeftHanded;
  final ThemeMode themeMode;
}

abstract interface class UserSettingsRepository {
  /// Emits [userId]'s saved preferences, or [UserSettings.defaults] until the
  /// account saves its first change.
  Stream<UserSettings> watchUserSettings({required String userId});

  Future<void> saveUserSettings({
    required String userId,
    required UserSettings settings,
  });
}

class FirebaseUserSettingsRepository implements UserSettingsRepository {
  FirebaseUserSettingsRepository(this._firestore, this._auth);

  static String _documentPath(String userId) => 'userSettings/$userId';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<UserSettings> watchUserSettings({required String userId}) {
    return _firestore.doc(_documentPath(userId)).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return UserSettings.defaults;
      }
      return UserSettings(
        isLeftHanded: data['leftHanded'] as bool? ?? false,
        themeMode: _themeModeFromName(data['themeMode'] as String?),
      );
    });
  }

  @override
  Future<void> saveUserSettings({
    required String userId,
    required UserSettings settings,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      throw StateError('A user can only save their own settings.');
    }

    await _firestore.doc(_documentPath(userId)).set({
      'leftHanded': settings.isLeftHanded,
      // `ThemeMode.name` is the value the rules accept: system, light or dark.
      'themeMode': settings.themeMode.name,
    });
  }
}

ThemeMode _themeModeFromName(String? name) => switch (name) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};
