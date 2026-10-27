import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'auth_emulator_origin_seed.dart'
    if (dart.library.js_interop) 'auth_emulator_origin_seed_web.dart';

const _firebaseAuthEmulatorPort = 9299;
const _firestoreEmulatorPort = 8180;
const _storageEmulatorPort = 9298;

Future<void> initializeFirebase() async {
  // The Android emulator reaches the host machine through 10.0.2.2; every
  // other platform (including web) talks to loopback directly.
  final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';

  // Web: `Firebase.initializeApp` already initialises Auth, so the later
  // `useAuthEmulator` call would be rejected (and silently ignored). Hand the
  // origin to `firebase_auth_web` up front instead. No-op on native.
  if (kIsWeb) {
    seedAuthEmulatorOrigin('http://$host:$_firebaseAuthEmulatorPort');
  }

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:1234567890:web:bserv-demo',
      messagingSenderId: '1234567890',
      projectId: 'demo-bserv',
      storageBucket: 'demo-bserv.appspot.com',
    ),
  );

  await FirebaseAuth.instance.useAuthEmulator(host, _firebaseAuthEmulatorPort);
  FirebaseFirestore.instance.useFirestoreEmulator(host, _firestoreEmulatorPort);
  FirebaseStorage.instance.useStorageEmulator(host, _storageEmulatorPort);
}
