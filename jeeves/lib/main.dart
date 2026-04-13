/// Jeeves — multiplatform blog search, storage, and backup for the
/// Ecosophia community.
///
/// Entry point: bootstraps the dependency-injection tree (via [Provider])
/// and launches the Material 3 application.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/sync_service.dart';

/// Application entry point.
///
/// Calls [WidgetsFlutterBinding.ensureInitialized] before [runApp] so that
/// platform channels (used by sqflite) are ready before any database work
/// begins. The [SyncService] is provided at the root of the widget tree so
/// every descendant can read or watch sync state without manual passing.
void main() {
  // Ensure the Flutter engine is fully initialised before any plugin or
  // platform-channel code runs (required by sqflite on all platforms).
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // Provide SyncService at the root so all screens can access live sync
    // status via context.watch / context.read without rebuilding unrelated
    // subtrees.
    ChangeNotifierProvider(
      create: (_) => SyncService(),
      child: const JeevesApp(),
    ),
  );
}

/// Root widget of the Jeeves application.
///
/// Configures the global [MaterialApp] with a Material 3 theme seeded from
/// [Colors.indigo] and installs [HomeScreen] as the initial route.
class JeevesApp extends StatelessWidget {
  const JeevesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jeeves',
      theme: ThemeData(
        // Material 3 colour scheme derived from an indigo seed colour.
        // All child widgets inherit their colours from this scheme, ensuring
        // a cohesive, accessible palette across light mode.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
