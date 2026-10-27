import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'app_environment.dart';
import 'auth_emulator_origin_seed.dart'
    if (dart.library.js_interop) 'auth_emulator_origin_seed_web.dart';

/// Initialises Firebase and points every plugin at the backend selected by
/// [AppEnvironment].
///
/// With `USE_FIREBASE_EMULATOR` unset (the default) the app talks to the local
/// Emulator Suite, so no Firebase project is touched. Build with
/// `--dart-define=USE_FIREBASE_EMULATOR=false` to use the deployed project.
Future<void> initializeFirebase() async {
  if (!AppEnvironment.useFirebaseEmulator) {
    await Firebase.initializeApp(options: AppEnvironment.deployedOptions);
    return;
  }

  final host = AppEnvironment.emulatorHost;

  // Web: `Firebase.initializeApp` already initialises Auth, so the later
  // `useAuthEmulator` call would be rejected (and silently ignored). Hand the
  // origin to `firebase_auth_web` up front instead. No-op on native.
  if (kIsWeb) {
    seedAuthEmulatorOrigin('http://$host:${AppEnvironment.authEmulatorPort}');
  }

  await Firebase.initializeApp(options: AppEnvironment.emulatorOptions);

  await FirebaseAuth.instance.useAuthEmulator(
    host,
    AppEnvironment.authEmulatorPort,
  );
  FirebaseFirestore.instance.useFirestoreEmulator(
    host,
    AppEnvironment.firestoreEmulatorPort,
  );
  FirebaseStorage.instance.useStorageEmulator(
    host,
    AppEnvironment.storageEmulatorPort,
  );
}
