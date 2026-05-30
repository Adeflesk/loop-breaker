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
}
