import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jeeves/main.dart';
import 'package:jeeves/services/sync_service.dart';

void main() {
  testWidgets('JeevesApp renders HomeScreen with bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SyncService(),
        child: const JeevesApp(),
      ),
    );
    // Allow async widget work (e.g., FutureBuilders) to settle
    await tester.pump();

    // Bottom navigation should show the three main destinations
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

