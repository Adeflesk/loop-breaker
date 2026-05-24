import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GoalService service;

  setUp(() {
    service = GoalService();
    SharedPreferences.setMockInitialValues({});
  });

  // ── computeStreak ────────────────────────────────────────────────────────
  group('computeStreak', () {
    test('returns 0 for empty history', () {
      expect(service.computeStreak([]), 0);
    });

    test('returns 1 when only today has a successful entry', () {
      final today = DateTime.now();
      final history = [
        {
          'time': today.toIso8601String(),
          'was_successful': true,
        }
      ];
      expect(service.computeStreak(history), 1);
    });

    test('counts consecutive successful days ending today', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final dayBefore = today.subtract(const Duration(days: 2));
      final history = [
        {'time': today.toIso8601String(), 'was_successful': true},
        {'time': yesterday.toIso8601String(), 'was_successful': true},
        {'time': dayBefore.toIso8601String(), 'was_successful': true},
      ];
      expect(service.computeStreak(history), 3);
    });

    test('resets streak at a missed day', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));
      final threeDaysAgo = today.subtract(const Duration(days: 3));
      final history = [
        {'time': today.toIso8601String(), 'was_successful': true},
        {'time': yesterday.toIso8601String(), 'was_successful': false},
        {'time': twoDaysAgo.toIso8601String(), 'was_successful': true},
        {'time': threeDaysAgo.toIso8601String(), 'was_successful': true},
      ];
      // Streak stops at yesterday because it was not successful
      expect(service.computeStreak(history), 1);
    });

    test('returns 0 when today has no successful entry', () {
      final today = DateTime.now();
      final history = [
        {'time': today.toIso8601String(), 'was_successful': false},
      ];
      expect(service.computeStreak(history), 0);
    });

    test('multiple entries same day — counts as 1 day if any successful', () {
      final today = DateTime.now();
      final history = [
        {'time': today.toIso8601String(), 'was_successful': false},
        {'time': today.toIso8601String(), 'was_successful': true},
      ];
      expect(service.computeStreak(history), 1);
    });
  });

  // ── isGoalCompleted ───────────────────────────────────────────────────────
  group('isGoalCompleted', () {
    test('returns true when streak equals goal', () {
      expect(service.isGoalCompleted(7, 7), isTrue);
    });

    test('returns true when streak exceeds goal', () {
      expect(service.isGoalCompleted(10, 7), isTrue);
    });

    test('returns false when streak is below goal', () {
      expect(service.isGoalCompleted(3, 7), isFalse);
    });
  });

  // ── getGoalDays / setGoalDays ─────────────────────────────────────────────
  group('getGoalDays / setGoalDays', () {
    test('returns default 7 when not set', () async {
      final days = await service.getGoalDays();
      expect(days, 7);
    });

    test('persists and retrieves goal days', () async {
      await service.setGoalDays(14);
      final days = await service.getGoalDays();
      expect(days, 14);
    });
  });

  // ── markGoalCompleted / clearGoalCompleted ────────────────────────────────
  group('markGoalCompleted / clearGoalCompleted', () {
    test('wasGoalCompleted returns false initially', () async {
      expect(await service.wasGoalCompleted(), isFalse);
    });

    test('wasGoalCompleted returns true after markGoalCompleted', () async {
      await service.markGoalCompleted();
      expect(await service.wasGoalCompleted(), isTrue);
    });

    test('wasGoalCompleted returns false after clearGoalCompleted', () async {
      await service.markGoalCompleted();
      await service.clearGoalCompleted();
      expect(await service.wasGoalCompleted(), isFalse);
    });
  });
}
