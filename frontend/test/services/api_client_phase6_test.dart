import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  group('ApiClient.getWeeklySummary', () {
    test('returns parsed map on 200', () async {
      ApiClient.clientOverride = MockClient((request) async {
        expect(request.url.path, endsWith('/weekly-summary'));
        expect(request.url.queryParameters['week_start'], '2026-05-26');
        return http.Response(
          jsonEncode({
            'week_start': '2026-05-26',
            'total_entries': 5,
            'days_with_entries': 4,
            'avg_confidence': 0.72,
            'intervention_success_rate': 80.0,
            'top_states': {'Stress': 3},
          }),
          200,
        );
      });

      final result = await ApiClient.getWeeklySummary('2026-05-26');
      expect(result['total_entries'], 5);
      expect(result['days_with_entries'], 4);
      expect(result['intervention_success_rate'], 80.0);
    });

    test('returns empty map on network error', () async {
      ApiClient.clientOverride = MockClient((_) async {
        throw Exception('Network error');
      });

      final result = await ApiClient.getWeeklySummary('2026-05-26');
      expect(result, isEmpty);
    });

    test('returns empty map on non-200 status', () async {
      ApiClient.clientOverride = MockClient((_) async {
        return http.Response('Internal Server Error', 500);
      });

      final result = await ApiClient.getWeeklySummary('2026-05-26');
      expect(result, isEmpty);
    });
  });

  group('ApiClient.getHistoryDateRange', () {
    test('returns list on 200', () async {
      ApiClient.clientOverride = MockClient((request) async {
        expect(request.url.path, endsWith('/history'));
        expect(request.url.queryParameters['start_date'], '2026-05-01');
        expect(request.url.queryParameters['end_date'], '2026-05-31');
        expect(request.url.queryParameters['limit'], '500');
        return http.Response(
          jsonEncode([
            {'state': 'Stress', 'confidence': 0.5},
            {'state': 'Anxiety', 'confidence': 0.7},
          ]),
          200,
        );
      });

      final result = await ApiClient.getHistoryDateRange('2026-05-01', '2026-05-31');
      expect(result.length, 2);
      expect(result[0]['state'], 'Stress');
    });

    test('returns empty list on network error', () async {
      ApiClient.clientOverride = MockClient((_) async {
        throw Exception('Network error');
      });

      final result = await ApiClient.getHistoryDateRange('2026-05-01', '2026-05-31');
      expect(result, isEmpty);
    });

    test('returns empty list on non-200 status', () async {
      ApiClient.clientOverride = MockClient((_) async {
        return http.Response('Not Found', 404);
      });

      final result = await ApiClient.getHistoryDateRange('2026-05-01', '2026-05-31');
      expect(result, isEmpty);
    });
  });

  group('ApiClient.createDailyCheck', () {
    test('completes without throwing on 201', () async {
      ApiClient.clientOverride = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/daily-check'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sleep_hours'], 7.5);
        expect(body['hydration_rating'], 3);
        expect(body['food_quality'], 4);
        expect(body['movement_minutes'], 30);
        expect(body['stress_level'], 2);
        return http.Response(jsonEncode({'status': 'recorded'}), 201);
      });

      await expectLater(
        ApiClient.createDailyCheck({
          'sleep_hours': 7.5,
          'hydration_rating': 3,
          'food_quality': 4,
          'movement_minutes': 30,
          'stress_level': 2,
        }),
        completes,
      );
    });

    test('throws on non-201 response', () async {
      ApiClient.clientOverride = MockClient((_) async {
        return http.Response('Service Unavailable', 503);
      });

      await expectLater(
        ApiClient.createDailyCheck({
          'sleep_hours': 7.0,
          'hydration_rating': 3,
          'food_quality': 3,
          'movement_minutes': 20,
          'stress_level': 3,
        }),
        throwsException,
      );
    });
  });
}
