import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/daily_practice_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiClient.clientOverride = null;
  });

  testWidgets('DailyPracticeScreen walks through all 3 steps and submits',
      (tester) async {
    Map<String, dynamic>? submittedPayload;

    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/practice') && request.method == 'POST') {
        submittedPayload =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'status': 'recorded'}), 201);
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DailyPracticeScreen(),
      ),
    );
    await tester.pump();

    // Step 1: Physiological Reset (Breathing)
    expect(
      find.text('Step 1 of 3: Physiological Reset'),
      findsOneWidget,
    );
    expect(find.text('2 min'), findsOneWidget);
    await tester.tap(find.text('2 min'));
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pump();

    // Step 2: Daily Intention
    expect(find.text('Step 2 of 3: Daily Intention'), findsOneWidget);
    await tester.tap(find.text('Pause and take one sigh before reacting'));
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pump();

    // Step 3: Gratitude & Grounding
    expect(find.text('Step 3 of 3: Gratitude & Grounding'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Quiet morning focus and good health',
    );
    await tester.pump();

    await tester.tap(find.text('Complete Practice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(submittedPayload, isNotNull);
    expect(
      submittedPayload!['intention'],
      'Pause and take one sigh before reacting',
    );
    expect(
      submittedPayload!['gratitude'],
      'Quiet morning focus and good health',
    );
    expect(submittedPayload!['breathing_seconds'], 120);
  });

  testWidgets('DailyPracticeScreen reminder picker persists reminder time',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DailyPracticeScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Reminder'), findsOneWidget);
    await tester.tap(find.text('Reminder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Daily Practice Reminder'), findsOneWidget);
    await tester.tap(find.text('08:30'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('08:30'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_practice_reminder_time'), '08:30');
  });
}
