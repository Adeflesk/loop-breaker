import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/journal_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  testWidgets('HistoryScreen shows dashboard title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(),
      ),
    );

    expect(find.text('Journey Dashboard'), findsOneWidget);
  });

  testWidgets('HistoryScreen shows no-data state when history is empty',
      (WidgetTester tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path.endsWith('/stats')) {
        return http.Response(jsonEncode({}), 200);
      }
      return http.Response('Not Found', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No data yet.'), findsOneWidget);
  });

  testWidgets('Reset Journey Data calls backend and refreshes state',
      (WidgetTester tester) async {
    var resetCalled = false;

    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode([
          {
            'state': 'Stress',
            'was_successful': false,
            'confidence': 0.4,
            'intervention': 'None',
            'time': '2026-04-29T21:00:00',
          }
        ]), 200);
      }
      if (request.url.path.endsWith('/stats')) {
        return http.Response(jsonEncode({}), 200);
      }
      if (request.url.path.endsWith('/reset')) {
        resetCalled = true;
        return http.Response('', 200);
      }
      return http.Response('Not Found', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final resetButton = find.text('Reset Journey Data');
    expect(resetButton, findsOneWidget);
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    final dialogReset = find.widgetWithText(TextButton, 'Reset');
    expect(dialogReset, findsOneWidget);
    await tester.tap(dialogReset);
    await tester.pumpAndSettle();

    expect(resetCalled, isTrue);
    expect(find.text('Database Wiped'), findsOneWidget);
  });

  testWidgets('JournalScreen shows backend error message when analyze fails',
      (WidgetTester tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/insight')) {
        return http.Response(
          jsonEncode({
            'message': "Welcome! Let's break some loops today.",
            'success_rate': 0,
            'top_loop': 'None',
            'trend': 'unknown',
            'streak': 0,
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/analyze')) {
        return http.Response('Server failure', 500);
      }
      return http.Response('Not Found', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: JournalScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Feeling stuck');
    await tester.tap(find.text('Analyze State'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Error: Backend unreachable.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

