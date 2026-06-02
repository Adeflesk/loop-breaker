import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/widgets/weekly_scorecard.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  Map<String, dynamic> weeklyData(int entries) => {
        'week_start': '2026-05-26',
        'total_entries': entries,
        'days_with_entries': entries,
        'avg_confidence': 0.7,
        'intervention_success_rate': 70.0,
        'top_states': {},
      };

  http.Response jsonResp(Object body, [int code = 200]) =>
      http.Response(jsonEncode(body), code);

  MockClient buildMockClient({bool weeklySummaryHasData = true}) {
    return MockClient((request) async {
      if (request.url.path.endsWith('/history')) {
        return jsonResp([
          {
            'state': 'Stress',
            'was_successful': true,
            'confidence': 0.6,
            'intervention': 'X',
            'time': '2026-05-29T10:00:00',
          }
        ]);
      }
      if (request.url.path.endsWith('/weekly-summary')) {
        return jsonResp(weeklySummaryHasData ? weeklyData(3) : {});
      }
      if (request.url.path.endsWith('/stats')) return jsonResp({'Stress': 1.0});
      if (request.url.path.contains('loop-path')) {
        return jsonResp({'path': [], 'analysis': {}});
      }
      if (request.url.path.endsWith('/insight')) {
        return jsonResp({'message': 'Hi', 'weekly_activity': [], 'streak': 0});
      }
      return jsonResp({}, 404);
    });
  }

  testWidgets('shows Weekly Comparison label when summary has data', (tester) async {
    ApiClient.clientOverride = buildMockClient(weeklySummaryHasData: true);

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Comparison'), findsOneWidget);
  });

  testWidgets('renders WeeklyScorecard when summary has data', (tester) async {
    ApiClient.clientOverride = buildMockClient(weeklySummaryHasData: true);

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(WeeklyScorecard), findsAtLeastNWidgets(1));
  });

  testWidgets('hides Weekly Comparison when both summaries are empty', (tester) async {
    ApiClient.clientOverride = buildMockClient(weeklySummaryHasData: false);

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Comparison'), findsNothing);
  });

  testWidgets('shows Journey Dashboard title in AppBar', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = buildMockClient();
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pump();
    expect(find.text('Journey Dashboard'), findsOneWidget);
  });

  testWidgets('shows empty state when no history entries', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) return jsonResp([]);
      return jsonResp({});
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.text('Journal your first entry to see your dashboard'), findsOneWidget);
  });

  testWidgets('shows loading indicator while fetching history', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = MockClient((request) async {
      await Future.delayed(const Duration(seconds: 1));
      if (request.url.path.endsWith('/history')) return jsonResp([]);
      return jsonResp({});
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('shows stat cards (Entries, Loops Broken, Avg Focus)', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = buildMockClient();
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    // 'Entries' appears in both the stat card and the WeeklyScorecard label
    expect(find.text('Entries'), findsAtLeastNWidgets(1));
    expect(find.text('Loops Broken'), findsOneWidget);
    expect(find.text('Avg Focus'), findsOneWidget);
  });

  testWidgets('shows Emotional Composition label with data', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = buildMockClient();
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Emotional Composition'), findsOneWidget);
  });

  testWidgets('shows Recent Entries label with data', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = buildMockClient();
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Recent Entries'), findsOneWidget);
  });

  testWidgets('shows Reset Journey Data button', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = buildMockClient();
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reset Journey Data'));
    expect(find.text('Reset Journey Data'), findsOneWidget);
  });

  testWidgets('shows weekly activity scorecard when insight has weekly_activity', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) {
        return jsonResp([{
          'state': 'Stress',
          'was_successful': true,
          'confidence': 0.6,
          'intervention': 'X',
          'time': '2026-05-29T10:00:00',
        }]);
      }
      if (request.url.path.endsWith('/weekly-summary')) return jsonResp(weeklyData(3));
      if (request.url.path.endsWith('/stats')) return jsonResp({'Stress': 1.0});
      if (request.url.path.contains('loop-path')) return jsonResp({'path': [], 'analysis': {}});
      if (request.url.path.endsWith('/insight')) {
        return jsonResp({
          'message': 'Good progress!',
          'weekly_activity': [true, false, true, true, false, false, true],
          'streak': 3,
        });
      }
      return jsonResp({}, 404);
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    // Weekly scorecard from insight should render 'This Week' label
    expect(find.text('This Week'), findsOneWidget);
  });

  testWidgets('shows loop path analysis text when analysis data available', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) {
        return jsonResp([{
          'state': 'Stress',
          'was_successful': true,
          'confidence': 0.7,
          'intervention': 'Sigh',
          'time': '2026-05-29T10:00:00',
        }]);
      }
      if (request.url.path.endsWith('/weekly-summary')) return jsonResp(weeklyData(1));
      if (request.url.path.endsWith('/stats')) return jsonResp({'Stress': 1.0});
      if (request.url.path.contains('loop-path')) {
        return jsonResp({
          'path': [
            {'state': 'Stress', 'confidence': 0.7, 'timestamp': '2026-05-29T10:00:00', 'has_intervention': true},
            {'state': 'Anxiety', 'confidence': 0.6, 'timestamp': '2026-05-29T12:00:00', 'has_intervention': false},
          ],
          'analysis': {
            'most_common_entry': 'Stress',
            'cycle_length_hours': 24,
          },
        });
      }
      if (request.url.path.endsWith('/insight')) {
        return jsonResp({'message': 'Hi', 'weekly_activity': [], 'streak': 0});
      }
      return jsonResp({}, 404);
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Most common entry: Stress'), findsOneWidget);
  });

  testWidgets('reset data shows confirmation dialog', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = buildMockClient();
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reset Journey Data'));
    await tester.pump();
    await tester.tap(find.text('Reset Journey Data'));
    await tester.pumpAndSettle();

    expect(find.text('Reset All Data?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('cancel on reset dialog dismisses without resetting', (tester) async {
    ApiClient.clearCache();
    ApiClient.clientOverride = buildMockClient();
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reset Journey Data'));
    await tester.pump();
    await tester.tap(find.text('Reset Journey Data'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Journey Dashboard'), findsOneWidget);
    expect(find.text('Reset All Data?'), findsNothing);
  });

  testWidgets('confirming reset calls API and shows snackbar', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) return jsonResp([sampleEntry()]);
      if (request.url.path.endsWith('/weekly-summary')) return jsonResp(weeklyData(1));
      if (request.url.path.endsWith('/stats')) return jsonResp({'Stress': 1.0});
      if (request.url.path.contains('loop-path')) return jsonResp({'path': [], 'analysis': {}});
      if (request.url.path.endsWith('/insight')) return jsonResp({'message': 'Hi', 'weekly_activity': [], 'streak': 0});
      if (request.method == 'DELETE' && request.url.path.endsWith('/reset')) {
        return http.Response('', 200);
      }
      return jsonResp({}, 404);
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reset Journey Data'));
    await tester.pump();
    await tester.tap(find.text('Reset Journey Data'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Database Wiped'), findsOneWidget);
  });
}

Map<String, dynamic> sampleEntry() => {
      'state': 'Stress',
      'was_successful': true,
      'confidence': 0.6,
      'intervention': 'Physiological Sigh',
      'time': '2026-05-29T10:00:00',
    };
