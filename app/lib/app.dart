import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        secondary: const Color(0xFF0D9488),
        brightness: brightness,
      ),
    );

class CircloApp extends ConsumerWidget {
  const CircloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Circlo',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Shown when the build has no Firebase configuration (see .env.example).
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Circlo',
        theme: _theme(Brightness.light),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Circlo is not connected to Firebase yet.\n\n'
                'Build with the FIREBASE_* --dart-define values described in README.md '
                '(or USE_FIREBASE_EMULATOR=true for local development).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
