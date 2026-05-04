import 'package:flutter/material.dart';

class LoopPathChart extends StatelessWidget {
  final List<dynamic> path;
  final String? mostCommonEntry;

  const LoopPathChart({
    super.key,
    required this.path,
    this.mostCommonEntry,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No entries yet. Start journaling to see your loop patterns.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline header
          const Text(
            'Your State Transitions',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Vertical timeline
          for (int i = 0; i < path.length; i++) ...[
            _TimelineEntry(
              state: path[i]['state'] as String,
              confidence: (path[i]['confidence'] as num).toDouble(),
              timestamp: path[i]['timestamp'] as String,
              hasIntervention: path[i]['has_intervention'] as bool? ?? false,
              isHighlighted: path[i]['state'] == mostCommonEntry,
              isLast: i == path.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final String state;
  final double confidence;
  final String timestamp;
  final bool hasIntervention;
  final bool isHighlighted;
  final bool isLast;

  const _TimelineEntry({
    required this.state,
    required this.confidence,
    required this.timestamp,
    required this.hasIntervention,
    required this.isHighlighted,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = timestamp.split('T')[1].substring(0, 5); // HH:MM
    final confidencePercent = (confidence * 100).toInt();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isHighlighted ? Colors.red : Colors.blueGrey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Entry details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isHighlighted ? Colors.red : Colors.black,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Confidence: $confidencePercent%',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (hasIntervention) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Intervention',
                        style: TextStyle(fontSize: 10, color: Colors.green),
                      ),
                    ),
                  ],
                ],
              ),
              if (!isLast) ...[
                const SizedBox(height: 8),
                Container(
                  width: 1,
                  height: 12,
                  color: Colors.blueGrey.shade300,
                  margin: const EdgeInsets.only(left: 7),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
