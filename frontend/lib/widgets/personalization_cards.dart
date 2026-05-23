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
              Expanded(
                child: Text(
                  'Your Loop Pattern',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Most common entry',
            style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
          ),
          Text(
            mostCommonEntry,
            style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
          if (cycleLength != null) ...[
            const SizedBox(height: 8),
            Text(
              'Cycle length',
              style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
            ),
            Text(
              '${cycleLength.toStringAsFixed(1)} hours',
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
          ],
          if (whereInCycle != null && whereInCycle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Position in Cycle',
              style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
            ),
            Text(
              whereInCycle,
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
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
    if (interventionEffectiveness == null || interventionEffectiveness!.isEmpty) {
      return const SizedBox.shrink();
    }

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
              Expanded(
                child: Text(
                  'Effectiveness Track Record',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          ...interventionEffectiveness!.entries.map((entry) {
            final Map<String, dynamic> e = entry.value as Map<String, dynamic>;
            final int helped = e['helped'] as int? ?? 0;
            final int neutral = e['neutral'] as int? ?? 0;
            final int didntHelp = e['didn_help'] as int? ?? 0;
            final int total = e['total'] as int? ?? 1;
            final int percentage = e['percentage'] as int? ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "$helped helped · $neutral neutral · $didntHelp didn't help · n=$total",
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$percentage%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
            );
          }),
        ],
      ),
    );
  }
}
