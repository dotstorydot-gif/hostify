// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostify/main.dart';

void main() {
  testWidgets('Splash screen renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the splash screen text is displayed.
    expect(find.text('.Hostify'), findsOneWidget);
    
    // Verify that the logo is displayed (Image widget)
    expect(find.byType(Image), findsOneWidget);
  });

}
