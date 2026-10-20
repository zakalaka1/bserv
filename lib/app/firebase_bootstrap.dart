import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

const _firebaseAuthEmulatorPort = 9299;
const _firestoreEmulatorPort = 8180;
const _storageEmulatorPort = 9298;

Future<void> initializeFirebase() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:1234567890:web:bserv-demo',
      messagingSenderId: '1234567890',
      projectId: 'demo-bserv',
      storageBucket: 'demo-bserv.appspot.com',
    ),
  );

  final host = switch (defaultTargetPlatform) {
    TargetPlatform.android => '10.0.2.2',
    _ => '127.0.0.1',
  };
  await FirebaseAuth.instance.useAuthEmulator(host, _firebaseAuthEmulatorPort);
  FirebaseFirestore.instance.useFirestoreEmulator(host, _firestoreEmulatorPort);
  FirebaseStorage.instance.useStorageEmulator(host, _storageEmulatorPort);
}
