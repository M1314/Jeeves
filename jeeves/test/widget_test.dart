import 'package:flutter_test/flutter_test.dart';
import 'package:jeeves/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const JeevesApp());
    expect(find.byType(JeevesApp), findsOneWidget);
  });
}
