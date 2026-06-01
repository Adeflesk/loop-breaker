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

  testWidgets('expanding entry card reveals raw text and outcome buttons', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/journal-entries')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'entry-1',
              'raw_text': 'I feel overwhelmed today',
              'detected_state': 'Overwhelm',
              'sublabel': 'Paralysis',
              'confidence': 0.8,
              'reasoning': 'Multiple stressors detected',
              'risk_level': 'Medium',
              'intervention_title': 'Brain Dump',
              'user_outcome': '',
              'timestamp': '2026-05-29T10:30:00',
            }
          ]),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Detected: Overwhelm (Paralysis)'));
    await tester.pumpAndSettle();

    expect(find.text('What you wrote:'), findsOneWidget);
    expect(find.text('Did this intervention help?'), findsOneWidget);
    expect(find.text('Helped'), findsOneWidget);
    expect(find.text('Neutral'), findsOneWidget);
    expect(find.text("Didn't Help"), findsOneWidget);
  });

  testWidgets('recording Helped outcome calls API and shows snackbar', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/journal-entries')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'entry-1',
              'raw_text': 'Felt stressed',
              'detected_state': 'Stress',
              'sublabel': 'General',
              'confidence': 0.7,
              'reasoning': 'Stress detected',
              'risk_level': 'Low',
              'intervention_title': 'Physiological Sigh',
              'user_outcome': '',
              'timestamp': '2026-05-29T10:00:00',
            }
          ]),
          200,
        );
      }
      if (request.url.path.contains('/outcome')) {
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Detected: Stress (General)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Helped'));
    await tester.pumpAndSettle();

    expect(find.text('Outcome recorded'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads journal entries', (tester) async {
    int callCount = 0;
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/journal-entries')) {
        callCount++;
        return http.Response(
          jsonEncode([
            {
              'id': 'entry-1',
              'raw_text': 'Felt stressed',
              'detected_state': 'Stress',
              'sublabel': 'General',
              'confidence': 0.7,
              'reasoning': 'Stress detected',
              'risk_level': 'Low',
              'intervention_title': 'Physiological Sigh',
              'user_outcome': '',
              'timestamp': '2026-05-29T10:00:00',
            }
          ]),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    // Simulate pull to refresh
    await tester.fling(find.byType(ListView), const Offset(0, 400), 800);
    await tester.pumpAndSettle();

    // Should have fetched at least twice (initial + refresh)
    expect(callCount, greaterThanOrEqualTo(2));
  });

  testWidgets('entry with helped outcome shows helped badge', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/journal-entries')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'entry-1',
              'raw_text': 'Felt stressed',
              'detected_state': 'Stress',
              'sublabel': 'General',
              'confidence': 0.7,
              'reasoning': 'Stress detected',
              'risk_level': 'Low',
              'intervention_title': 'Physiological Sigh',
              'user_outcome': 'helped',
              'timestamp': '2026-05-29T10:00:00',
            }
          ]),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    // The badge text matches the outcome value 'helped'
    expect(find.text('helped'), findsOneWidget);
  });

  testWidgets('entry with neutral outcome shows neutral badge', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/journal-entries')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'entry-2',
              'raw_text': 'Felt neutral',
              'detected_state': 'Stress',
              'sublabel': 'General',
              'confidence': 0.5,
              'reasoning': 'Neutral detected',
              'risk_level': 'Low',
              'intervention_title': 'Brain Dump',
              'user_outcome': 'neutral',
              'timestamp': '2026-05-29T09:00:00',
            }
          ]),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('neutral'), findsOneWidget);
  });

  testWidgets("entry with didn't help outcome shows badge", (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/journal-entries')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'entry-3',
              'raw_text': 'Felt bad',
              'detected_state': 'Anxiety',
              'sublabel': 'Social',
              'confidence': 0.6,
              'reasoning': 'Anxiety detected',
              'risk_level': 'Medium',
              'intervention_title': '5-4-3-2-1 Grounding',
              "user_outcome": "didn't help",
              'timestamp': '2026-05-28T08:00:00',
            }
          ]),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text("didn't help"), findsOneWidget);
  });

  testWidgets('recording Neutral outcome shows snackbar', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/journal-entries')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'entry-1',
              'raw_text': 'Felt okay',
              'detected_state': 'Stress',
              'sublabel': 'General',
              'confidence': 0.6,
              'reasoning': 'Stress detected',
              'risk_level': 'Low',
              'intervention_title': 'Physiological Sigh',
              'user_outcome': '',
              'timestamp': '2026-05-29T10:00:00',
            }
          ]),
          200,
        );
      }
      if (request.url.path.contains('/outcome')) {
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Detected: Stress (General)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Neutral'));
    await tester.pumpAndSettle();

    expect(find.text('Outcome recorded'), findsOneWidget);
  });

  testWidgets("recording Didn't Help outcome shows snackbar", (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/journal-entries')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'entry-1',
              'raw_text': 'Still stressed',
              'detected_state': 'Stress',
              'sublabel': 'General',
              'confidence': 0.6,
              'reasoning': 'Stress detected',
              'risk_level': 'Low',
              'intervention_title': 'Physiological Sigh',
              'user_outcome': '',
              'timestamp': '2026-05-29T10:00:00',
            }
          ]),
          200,
        );
      }
      if (request.url.path.contains('/outcome')) {
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: JournalHistoryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Detected: Stress (General)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Didn't Help"));
    await tester.pumpAndSettle();

    expect(find.text('Outcome recorded'), findsOneWidget);
  });
}
