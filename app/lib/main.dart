import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!CircloFirebase.isConfigured) {
    runApp(const SetupRequiredApp());
    return;
  }
  await Firebase.initializeApp(options: CircloFirebase.currentOptions);
  if (CircloFirebase.useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(CircloFirebase.emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(CircloFirebase.emulatorHost, 8080);
  }
  runApp(const ProviderScope(child: CircloApp()));
}
