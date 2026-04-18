/// Widget tests for [JeevesApp].
///
/// These tests verify the top-level application structure — specifically that
/// the root widget tree renders correctly and exposes the three primary
/// navigation destinations to the user.
///
/// All tests use a [ChangeNotifierProvider] wrapping a real [SyncService] to
/// mirror the production app setup, while avoiding any actual HTTP or database
/// calls (those are exercised by unit/integration tests elsewhere).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jeeves/main.dart';
import 'package:jeeves/services/sync_service.dart';

void main() {
  /// Verifies that [JeevesApp] renders [HomeScreen] with its three
  /// [NavigationBar] destinations visible.
  ///
  /// This is a smoke test that guards against accidental removal of the
  /// navigation structure during refactoring.
  testWidgets('JeevesApp renders HomeScreen with bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      // Wrap with a ChangeNotifierProvider to mirror the production
      // bootstrap in main() — required by any widget that calls
      // context.watch<SyncService>() or context.read<SyncService>().
      ChangeNotifierProvider(
        create: (_) => SyncService(),
        child: const JeevesApp(),
      ),
    );
    // Allow one frame for any synchronous FutureBuilders or initState calls
    // (e.g. the database query in SettingsScreen / AnalyticsScreen) to begin.
    await tester.pump();

    // All three NavigationBar destinations should be visible in the widget tree.
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

