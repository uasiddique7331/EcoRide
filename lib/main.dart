import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(SetupRequiredApp(details: e.toString()));
    return;
  }
  runApp(const ProviderScope(child: EcoRideApp()));
}

/// Shown when Firebase has not been configured yet (first run).
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.details});
  final String details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.settings_suggest_rounded, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Firebase setup required', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('1. Create a Firebase project (Auth, Firestore, Storage).\n'
                  '2. Run  flutterfire configure  in the project folder.\n'
                  '3. Deploy firestore.rules and storage.rules.\n'
                  '4. Restart the app.\n\nSee README.md for the full guide.'),
              const SizedBox(height: 16),
              Text(details, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
