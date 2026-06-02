import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/journal_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  void setupMocks({int dailyCheckStatus = 201}) {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/insight')) {
        return http.Response(
          jsonEncode({'message': 'Welcome', 'weekly_activity': [], 'streak': 0}),
          200,
        );
      }
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path.endsWith('/daily-check')) {
        return http.Response(jsonEncode({'status': 'recorded'}), dailyCheckStatus);
      }
      return http.Response('Not Found', 404);
    });
  }

  testWidgets('shows Daily Check-In FAB with heart icon', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('FAB has tooltip Daily Check-In', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    expect(fab.tooltip, 'Daily Check-In');
  });

  testWidgets('tapping FAB opens daily check-in dialog', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Daily Check-In'), findsAtLeastNWidgets(1));
  });

  testWidgets('dialog shows all 5 input labels', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Sleep (hours)'), findsOneWidget);
    expect(find.text('Hydration'), findsOneWidget);
    expect(find.text('Food Quality'), findsOneWidget);
    expect(find.text('Movement (minutes)'), findsOneWidget);
    expect(find.text('Stress Level'), findsOneWidget);
  });

  testWidgets('dialog shows Skip and Save Check-In buttons', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Save Check-In'), findsOneWidget);
  });

  testWidgets('Skip button dismisses dialog without API call', (tester) async {
    bool apiCalled = false;
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/insight')) {
        return http.Response(
          jsonEncode({'message': 'Hi', 'weekly_activity': [], 'streak': 0}),
          200,
        );
      }
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path.endsWith('/daily-check')) {
        apiCalled = true;
        return http.Response(jsonEncode({'status': 'recorded'}), 201);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Check-In'), findsNothing);
    expect(apiCalled, isFalse);
  });

  testWidgets('Save Check-In calls API and shows success snackbar on 201', (tester) async {
    setupMocks(dailyCheckStatus: 201);
    await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Check-In'));
    await tester.pumpAndSettle();

    expect(find.text('Check-in saved!'), findsOneWidget);
  });
}
