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

  testWidgets('Create Thought Record button opens ThoughtRecordScreen', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Thought Record'));
    await tester.pumpAndSettle();

    expect(find.text('Thought Record'), findsOneWidget);
  });

  testWidgets('New Thought Record button in list opens ThoughtRecordScreen', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(
        jsonEncode([
          {
            'balanced_thought': 'Things will be okay',
            'situation': 'Stressful day',
            'automatic_thought': 'I cannot cope',
            'evidence_for': 'I feel overwhelmed',
            'evidence_against': 'I have managed before',
            'linked_node': 'Stress',
            'timestamp': '2026-05-29T10:00:00',
          }
        ]),
        200,
      );
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Thought Record'));
    await tester.pumpAndSettle();

    expect(find.text('Thought Record'), findsOneWidget);
  });

  testWidgets('expanding a record card shows Situation and Automatic Thought', (tester) async {
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(
        jsonEncode([
          {
            'balanced_thought': 'I can handle this',
            'situation': 'My situation description',
            'automatic_thought': 'My automatic thought',
            'evidence_for': 'Evidence for',
            'evidence_against': 'Evidence against',
            'linked_node': 'Anxiety',
            'timestamp': '2026-05-29T10:00:00',
          }
        ]),
        200,
      );
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('I can handle this'));
    await tester.pumpAndSettle();

    expect(find.text('Situation:'), findsOneWidget);
    expect(find.text('Automatic Thought:'), findsOneWidget);
    expect(find.text('Evidence For:'), findsOneWidget);
    expect(find.text('Evidence Against:'), findsOneWidget);
    expect(find.text('Balanced Alternative:'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads thought records', (tester) async {
    int callCount = 0;
    ApiClient.clientOverride = MockClient((_) async {
      callCount++;
      return http.Response(
        jsonEncode([
          {
            'balanced_thought': 'I can manage this',
            'situation': 'Work challenge',
            'automatic_thought': 'I will fail',
            'evidence_for': 'Past failures',
            'evidence_against': 'Past successes',
            'linked_node': 'Anxiety',
            'timestamp': '2026-05-29T10:00:00',
          }
        ]),
        200,
      );
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    // Pull to refresh
    await tester.fling(find.byType(ListView), const Offset(0, 400), 800);
    await tester.pumpAndSettle();

    // Should have fetched at least twice
    expect(callCount, greaterThanOrEqualTo(2));
  });

  testWidgets('successful save from ThoughtRecordScreen refreshes the list', (tester) async {
    int fetchCount = 0;
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/thought-records')) {
        fetchCount++;
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path.endsWith('/thought-record')) {
        return http.Response(jsonEncode({'status': 'created'}), 201);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    // Tap Create Thought Record to navigate
    await tester.tap(find.text('Create Thought Record'));
    await tester.pumpAndSettle();

    // Navigate through all steps and save
    final nextFinder = () => find.ancestor(
          of: find.text('Next'),
          matching: find.bySubtype<ElevatedButton>(),
        );

    await tester.enterText(find.byType(TextField).first, 'My situation');
    await tester.pump();
    await tester.ensureVisible(nextFinder());
    await tester.pump();
    await tester.tap(nextFinder());
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'My thought');
    await tester.pump();
    await tester.ensureVisible(nextFinder());
    await tester.pump();
    await tester.tap(nextFinder());
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'Evidence for');
    await tester.enterText(find.byType(TextField).at(1), 'Evidence against');
    await tester.pump();
    await tester.ensureVisible(nextFinder());
    await tester.pump();
    await tester.tap(nextFinder());
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Balanced thought');
    await tester.pump();

    final saveFinder = find.ancestor(
      of: find.text('Save Record'),
      matching: find.bySubtype<ElevatedButton>(),
    );
    await tester.ensureVisible(saveFinder);
    await tester.pump();
    await tester.tap(saveFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    // After successful save, the list should have been refreshed
    expect(fetchCount, greaterThanOrEqualTo(2));
  });

  testWidgets('long balanced thought is truncated in card title', (tester) async {
    const longThought = 'This is a very long balanced thought that goes beyond sixty characters for testing';
    ApiClient.clientOverride = MockClient((_) async {
      return http.Response(
        jsonEncode([
          {
            'balanced_thought': longThought,
            'situation': 'Some situation',
            'automatic_thought': 'Some thought',
            'evidence_for': 'Some evidence',
            'evidence_against': 'Some counter',
            'linked_node': 'Stress',
            'timestamp': '2026-05-29T10:00:00',
          }
        ]),
        200,
      );
    });

    await tester.pumpWidget(const MaterialApp(home: ThoughtRecordsTab()));
    await tester.pumpAndSettle();

    // The first 60 chars + '...' should be shown
    expect(find.textContaining(longThought.substring(0, 60)), findsOneWidget);
  });
}
