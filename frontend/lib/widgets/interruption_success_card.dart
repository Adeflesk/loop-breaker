import 'package:flutter/material.dart';

/// Summarizes how often suggested interventions successfully interrupted a loop,
/// turning raw check-in counts into an actionable behavioral effectiveness rate.
class InterruptionSuccessCard extends StatelessWidget {
  final List<dynamic> historyEntries;

  const InterruptionSuccessCard({super.key, required this.historyEntries});

  static Map<String, dynamic> computeMetrics(List<dynamic> entries) {
    int attempted = 0;
    int broken = 0;
    int notHelped = 0;
    int behaviouralShifts = 0;
    int emotionalRelief = 0;
    final Map<String, int> totalByIntervention = {};
    final Map<String, int> brokenByIntervention = {};

    for (final raw in entries) {
      if (raw is! Map) continue;
      final intervention = (raw['intervention'] as String?)?.trim() ?? '';
      final wasSuccessful = raw['was_successful'];
      final outcomeType = (raw['outcome_type'] as String?)?.trim();
      final hasIntervention = intervention.isNotEmpty || wasSuccessful != null;
      if (!hasIntervention) continue;

      attempted++;
      if (wasSuccessful == true) {
        broken++;
        if (outcomeType == 'took_action' || outcomeType == 'interrupted_pattern') {
          behaviouralShifts++;
        } else if (outcomeType == 'felt_better') {
          emotionalRelief++;
        }
      } else if (wasSuccessful == false) {
        if (outcomeType != 'no_change') {
          notHelped++;
        }
      }

      if (intervention.isNotEmpty) {
        totalByIntervention[intervention] =
            (totalByIntervention[intervention] ?? 0) + 1;
        if (wasSuccessful == true) {
          brokenByIntervention[intervention] =
              (brokenByIntervention[intervention] ?? 0) + 1;
        }
      }
    }

    String? topIntervention;
    int topWins = 0;
    int topTotal = 0;
    for (final entry in brokenByIntervention.entries) {
      final wins = entry.value;
      final total = totalByIntervention[entry.key] ?? wins;
      if (wins > topWins) {
        topWins = wins;
        topTotal = total;
        topIntervention = entry.key;
      }
    }

    final double successRate = attempted > 0 ? broken / attempted : 0.0;
    return {
      'attempted': attempted,
      'broken': broken,
      'notHelped': notHelped,
      'behaviouralShifts': behaviouralShifts,
      'emotionalRelief': emotionalRelief,
      'successRate': successRate,
      'topIntervention': topIntervention,
      'topWins': topWins,
      'topTotal': topTotal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final metrics = computeMetrics(historyEntries);
    final int attempted = metrics['attempted'] as int;
    final int broken = metrics['broken'] as int;
    final int notHelped = metrics['notHelped'] as int;
    final int behaviouralShifts = metrics['behaviouralShifts'] as int;
    final int emotionalRelief = metrics['emotionalRelief'] as int;
    final double successRate = metrics['successRate'] as double;
    final String? topIntervention = metrics['topIntervention'] as String?;
    final int topWins = metrics['topWins'] as int;
    final int topTotal = metrics['topTotal'] as int;
    final int percent = (successRate * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Interruption Success Rate',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3142),
                  ),
                ),
                Text(
                  attempted > 0 ? '$percent%' : '—',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B9B96),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: successRate.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF5B9B96),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (attempted == 0)
              Text(
                'Try an intervention and rate whether it helped to track your interruption rate.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              )
            else ...[
              Text(
                '$broken broken of $attempted attempted'
                '${notHelped > 0 ? ' • $notHelped didn\'t help' : ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (behaviouralShifts > 0 || emotionalRelief > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Behavioural shifts: $behaviouralShifts • Emotional relief: $emotionalRelief',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              if (topIntervention != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Most effective: $topIntervention ($topWins/$topTotal)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B9B96),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
