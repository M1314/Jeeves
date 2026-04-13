import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeves/widgets/retro_button.dart';

void main() {
  group('RetroButton', () {
    testWidgets('renders with label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroButton(label: 'CLICK ME'),
          ),
        ),
      );

      expect(find.text('CLICK ME'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroButton(
              label: 'TAP',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(RetroButton));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('renders without onPressed (disabled state)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroButton(label: 'DISABLED'),
          ),
        ),
      );

      expect(find.text('DISABLED'), findsOneWidget);
    });
  });
}
