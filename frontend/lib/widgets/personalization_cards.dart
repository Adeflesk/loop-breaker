import 'package:flutter/material.dart';

class LoopPatternCard extends StatelessWidget {
  final Map<String, dynamic>? personalLoop;

  const LoopPatternCard({
    super.key,
    required this.personalLoop,
  });

  @override
  Widget build(BuildContext context) {
    if (personalLoop == null) return const SizedBox.shrink();

    final String mostCommonEntry = personalLoop?['most_common_entry'] ?? 'Unknown';
    final double? cycleLength = personalLoop?['cycle_length_hours']?.toDouble();
    final String? whereInCycle = personalLoop?['where_in_cycle'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Your Loop Pattern',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Most common entry: $mostCommonEntry',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          if (cycleLength != null) ...[
            const SizedBox(height: 8),
            Text(
              'Cycle length: ${cycleLength.toStringAsFixed(1)} hours',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
          if (whereInCycle != null && whereInCycle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Position in Cycle: $whereInCycle',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}

class EffectivenessCard extends StatelessWidget {
  final Map<String, dynamic>? interventionEffectiveness;
  final String? interventionTitle;

  const EffectivenessCard({
    super.key,
    required this.interventionEffectiveness,
    required this.interventionTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (interventionEffectiveness == null || interventionTitle == null) {
      return const SizedBox.shrink();
    }

    final Map<String, dynamic>? effectiveness =
        interventionEffectiveness?[interventionTitle];

    if (effectiveness == null) {
      return const SizedBox.shrink();
    }

    final int helped = effectiveness['helped'] as int? ?? 0;
    final int neutral = effectiveness['neutral'] as int? ?? 0;
    final int didntHelp = effectiveness['didn_help'] as int? ?? 0;
    final int total = effectiveness['total'] as int? ?? 1;
    final int percentage = effectiveness['percentage'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                   color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Effectiveness Track Record',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Helped: $helped',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    Text(
                      'Neutral: $neutral',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    Text(
                      'Didn\'t help: $didntHelp',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
