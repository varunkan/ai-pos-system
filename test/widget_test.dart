// This is a basic Flutter widget test for the Restaurant POS app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('App should start without crashing', (WidgetTester tester) async {
    // Provide a mock SharedPreferences instance
    final prefs = MockSharedPreferences();
    await tester.pumpWidget(MyApp(prefs: prefs));

    // Verify that the app starts successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
