import 'package:shared_preferences/shared_preferences.dart';

class GoalService {
  static const _keyGoalDays = 'recovery_goal_days';
  static const _keyGoalCompleted = 'recovery_goal_completed';
  static const int defaultGoalDays = 7;

  Future<int> getGoalDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyGoalDays) ?? defaultGoalDays;
  }

  Future<void> setGoalDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGoalDays, days);
  }

  Future<bool> wasGoalCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGoalCompleted) ?? false;
  }

  Future<void> markGoalCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGoalCompleted, true);
  }

  Future<void> clearGoalCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGoalCompleted);
  }

  /// Counts consecutive calendar days ending today where at least one
  /// entry has was_successful == true. history is sorted newest-first
  /// (the shape returned by GET /history).
  int computeStreak(List<dynamic> history) {
    if (history.isEmpty) return 0;

    // Build a set of calendar dates that have at least one successful entry.
    final Map<String, bool> dayHasSuccess = {};
    for (final entry in history) {
      final timeStr = entry['time'] as String? ?? '';
      if (timeStr.isEmpty) continue;
      final ts = DateTime.tryParse(timeStr);
      if (ts == null) continue;
      final dateKey =
          '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      if (entry['was_successful'] == true) {
        dayHasSuccess[dateKey] = true;
      } else {
        dayHasSuccess.putIfAbsent(dateKey, () => false);
      }
    }

    // Walk backwards from today counting consecutive successful days.
    int streak = 0;
    DateTime day = DateTime.now();
    while (true) {
      final dateKey =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (dayHasSuccess[dateKey] == true) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  bool isGoalCompleted(int streak, int goal) => streak >= goal;
}
