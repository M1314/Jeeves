import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeves/widgets/retro_error_widget.dart';

void main() {
  group('RetroErrorWidget', () {
    testWidgets('renders with error message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroErrorWidget(message: 'Something went wrong'),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('ERROR 404'), findsOneWidget);
    });

    testWidgets('shows RETRY button when onRetry is provided',
        (WidgetTester tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroErrorWidget(
              message: 'Network error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('RETRY'), findsOneWidget);
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('hides RETRY button when onRetry is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroErrorWidget(message: 'No retry'),
          ),
        ),
      );

      expect(find.text('RETRY'), findsNothing);
    });
  });
}
