import 'package:flutter/material.dart';

class StreakBar extends StatelessWidget {
  final int streak;
  final int goalDays;
  final bool isCompleted;
  final VoidCallback onTap;

  const StreakBar({
    super.key,
    required this.streak,
    required this.goalDays,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return isCompleted ? _buildCompletedBanner() : _buildProgressBar();
  }

  Widget _buildProgressBar() {
    final progress =
        goalDays > 0 ? (streak / goalDays).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'Day $streak of $goalDays',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.edit, size: 14, color: Colors.orange.shade400),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.orange.shade100,
              color: Colors.orange.shade600,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedBanner() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$streak-Day Streak Complete! Tap to set a new one',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
