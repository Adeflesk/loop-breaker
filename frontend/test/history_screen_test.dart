import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/history_screen.dart';

void main() {
  testWidgets('HistoryScreen shows dashboard title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(),
      ),
    );

    expect(find.text('Journey Dashboard'), findsOneWidget);
  });
}

