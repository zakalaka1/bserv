import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'app/firebase_bootstrap.dart';
import 'app/book_service_app.dart';
import 'data/appointments/appointment_repository.dart';
import 'data/content/business_content_repository.dart';
import 'data/content/work_notes_repository.dart';
import 'services/firebase_auth_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(
    BookServiceApp(
      authGateway: FirebaseAuthGateway(FirebaseAuth.instance),
      appointmentRepository: FirebaseAppointmentRepository(
        FirebaseFirestore.instance,
        FirebaseStorage.instance,
        FirebaseAuth.instance,
      ),
      businessContentRepository: FirebaseBusinessContentRepository(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      ),
      workNotesRepository: FirebaseWorkNotesRepository(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      ),
    ),
  );
}
