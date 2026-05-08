import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/expandable_history_entry.dart';
import '../widgets/loop_path_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ApiClient.fetchHistory();
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = ApiClient.fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journey Dashboard')),
      body: FutureBuilder<List<dynamic>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No data yet.'));
          }

          final data = snapshot.data!;

          final int totalEntries = data.length;
          final int loopsBroken =
              data.where((item) => item['was_successful'] == true).length;
          final double avgConfidence = data.isNotEmpty
              ? data
                      .map((e) => (e['confidence'] as num).toDouble())
                      .reduce((a, b) => a + b) /
                  data.length
              : 0.0;

          return SingleChildScrollView(
            child: Column(
              children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Row(
                  children: [
                    _buildStatCard('Entries', totalEntries.toString(), const Color(0xFF5B9B96)),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Loops Broken',
                      loopsBroken.toString(),
                      const Color(0xFFD89E6F),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Avg Focus',
                      '${(avgConfidence * 100).toStringAsFixed(0)}%',
                      const Color(0xFF8B7355),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Emotional Composition',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              FutureBuilder<Map<String, dynamic>>(
                future: ApiClient.fetchStats(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _buildTrendChart(
                    snapshot.data!.map((key, value) =>
                        MapEntry(key, (value as num).toDouble())),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Confidence Trend',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Container(
                  height: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: data
                              .asMap()
                              .entries
                              .map(
                                (e) => FlSpot(
                                  e.key.toDouble(),
                                  (e.value['confidence'] as num?)?.toDouble() ??
                                      0.0,
                                ),
                              )
                              .toList(),
                          isCurved: true,
                          color: const Color(0xFF5B9B96),
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF5B9B96).withOpacity(0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Entries',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    return ExpandableHistoryEntry(
                      item: data[index],
                      onExpanded: () {
                        // Haptic feedback on expand (optional)
                        // HapticFeedback.lightImpact();
                      },
                    );
                  },
                ),
              ),
              // Loop Path Section
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your Loop Pattern',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              FutureBuilder<Map<String, dynamic>>(
                future: ApiClient.getLoopPath(days: 30),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final pathData = snapshot.data!;
                  final path = pathData['path'] as List? ?? [];
                  final analysis = pathData['analysis'] as Map? ?? {};

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LoopPathChart(
                        path: path,
                        mostCommonEntry: analysis['most_common_entry'] as String?,
                      ),
                      if (analysis['most_common_entry'] != null &&
                          analysis['cycle_length_hours'] != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Most common entry: ${analysis['most_common_entry']} (repeats every ${analysis['cycle_length_hours']}h)',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: OutlinedButton.icon(
                  onPressed: () => _resetData(context),
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Reset Journey Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC16B4B),
                    side: const BorderSide(
                      color: Color(0xFFC16B4B),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(Map<String, double> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 45,
                  sections: data.entries.map((entry) {
                    return PieChartSectionData(
                      color: _getColorForState(entry.key),
                      value: entry.value,
                      title: '${entry.value.toInt()}',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black26,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: data.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getColorForState(entry.key),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForState(String state) {
    switch (state) {
      case 'Stress':
        return const Color(0xFFC16B4B);  // Warm terracotta red
      case 'Anxiety':
        return const Color(0xFFD89E6F);  // Clay orange
      case 'Procrastination':
        return const Color(0xFF8B7355);  // Warm brown
      case 'Shame':
        return const Color(0xFF5B9B96);  // Sage teal
      default:
        return const Color(0xFF6B9A92);  // Muted teal
    }
  }

  Future<void> _resetData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will permanently delete your history and broken loops. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await ApiClient.resetData();
        if (success) {
          _refreshHistory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database Wiped')),
          );
        }
      } catch (e) {
        debugPrint('Reset error: $e');
      }
    }
  }
}

