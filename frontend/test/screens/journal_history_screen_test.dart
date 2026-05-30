import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/journal_history_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  // The _EntryCard reads 'detected_state', 'sublabel', 'risk_level', etc.
  Map<String, dynamic> sampleEntry() => {
        'id': 'entry-1',
        'raw_text': 'I am feeling stressed about work',
        'detected_state': 'Stress',
        'sublabel': 'General',
        'risk_level': 'Medium',
        'confidence': 0.75,
        'reasoning': 'User seems stressed.',
        'loop_detected': false,
        'intervention_title': 'Physiological Sigh',
        'user_outcome': '',
        'timestamp': '2026-05-29T10:00:00',
      };

  testWidgets('shows My Journal title in AppBar', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pump();

    expect(find.text('My Journal'), findsOneWidget);
  });

  testWidgets('shows empty state when no entries', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No journal entries yet'), findsOneWidget);
    expect(find.textContaining('after journaling'), findsOneWidget);
  });

  testWidgets('shows loading indicator while fetching', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      await Future.delayed(const Duration(seconds: 1));
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('shows entry cards when entries available', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(jsonEncode([sampleEntry()]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    // _EntryCard title shows "Detected: $detectedState ($sublabel)"
    expect(find.textContaining('Stress'), findsWidgets);
  });

  testWidgets('shows detected state in entry card title', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(jsonEncode([sampleEntry()]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    // The title text is "Detected: Stress (General)"
    expect(find.textContaining('Detected: Stress'), findsOneWidget);
  });
}
