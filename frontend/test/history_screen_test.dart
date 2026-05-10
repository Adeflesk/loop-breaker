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

    expect(find.text('No entries yet'), findsOneWidget);
  });

  testWidgets('HistoryScreen loads and shows dashboard',
      (WidgetTester tester) async {
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
        return http.Response(jsonEncode({'Stress': 0.5}), 200);
      }
      if (request.url.path.contains('loop-path')) {
        return http.Response(jsonEncode({'path': [], 'analysis': {}}), 200);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dashboard title is displayed and widget tree is rendered
    expect(find.text('Journey Dashboard'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('JournalScreen displays entry form and analysis UI',
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
      return http.Response('Not Found', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: JournalScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify key UI elements of JournalScreen
    expect(find.text('How are you feeling right now?'), findsOneWidget);
    expect(find.text('Analyze State'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}

