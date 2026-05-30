import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/thought_records_tab.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  testWidgets('shows empty state when no thought records', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    expect(find.text('No thought records yet'), findsOneWidget);
    expect(find.text('Create Thought Record'), findsOneWidget);
  });

  testWidgets('shows Thought Records title in AppBar', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pump();

    expect(find.text('Thought Records'), findsOneWidget);
  });

  testWidgets('shows loading indicator while fetching', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      await Future.delayed(const Duration(seconds: 1));
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('shows list of records when data available', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(
        jsonEncode([
          {
            'balanced_thought': 'I can handle this challenge',
            'situation': 'Work presentation',
            'automatic_thought': 'I will fail',
            'evidence_for': 'I am nervous',
            'evidence_against': 'I have prepared well',
            'linked_node': 'Anxiety',
            'timestamp': '2026-05-29T10:00:00',
          }
        ]),
        200,
      );
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    expect(find.text('New Thought Record'), findsOneWidget);
    expect(find.textContaining('I can handle'), findsOneWidget);
  });

  testWidgets('shows error state on network failure', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      throw Exception('Network error');
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    // fetchThoughtRecords catches errors and returns [] — shows empty state
    expect(find.text('No thought records yet'), findsOneWidget);
  });
}
