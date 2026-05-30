import 'package:flutter/material.dart';

class WeeklyScorecard extends StatelessWidget {
  final Map<String, dynamic> currentWeek;
  final Map<String, dynamic> previousWeek;

  const WeeklyScorecard({
    super.key,
    required this.currentWeek,
    required this.previousWeek,
  });

  Widget _statTile(String label, String field, {bool isPercent = false}) {
    final current = (currentWeek[field] as num?)?.toDouble() ?? 0.0;
    final previous = (previousWeek[field] as num?)?.toDouble() ?? 0.0;

    final IconData icon;
    final Color color;
    if (current > previous) {
      icon = Icons.arrow_upward;
      color = Colors.green;
    } else if (current < previous) {
      icon = Icons.arrow_downward;
      color = Colors.red;
    } else {
      icon = Icons.arrow_forward;
      color = Colors.grey;
    }

    final String display = isPercent
        ? '${current.toStringAsFixed(0)}%'
        : current.toInt().toString();

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            display,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B9B96),
            ),
          ),
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _statTile('Entries', 'total_entries'),
          _statTile('Success Rate', 'intervention_success_rate', isPercent: true),
          _statTile('Active Days', 'days_with_entries'),
        ],
      ),
    );
  }
}
