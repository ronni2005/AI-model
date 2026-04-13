// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:rural_health_ai/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We use RuralHealthApp() because that is the name in your main.dart
    await tester.pumpWidget(const RuralHealthApp());

    // Verify that the home screen loads by checking for the app title
    // (Adjust 'RuralHealth AI' if your home screen title is different)
    expect(find.text('RuralHealth AI'), findsWidgets);
  });
}