import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/expandable_history_entry.dart';
import '../widgets/loop_path_chart.dart';
import '../widgets/weekly_scorecard.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<dynamic>> _historyFuture;
  late Future<List<Map<String, dynamic>>> _weeklyComparisonFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ApiClient.fetchHistory();
    _weeklyComparisonFuture = Future.wait([
      _fetchCurrentWeekSummary(),
      _fetchPreviousWeekSummary(),
    ]);
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = ApiClient.fetchHistory();
      _weeklyComparisonFuture = Future.wait([
        _fetchCurrentWeekSummary(),
        _fetchPreviousWeekSummary(),
      ]);
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
          if (snapshot.hasError) {
            return _buildErrorState('Could not load your journey. Pull to refresh.');
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_graph_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No entries yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Journal your first entry to see your dashboard',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _historyFuture = ApiClient.fetchHistory(useCache: false);
              });
              await _historyFuture;
            },
            child: SingleChildScrollView(
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
              // Weekly Scorecard
              FutureBuilder<Map<String, dynamic>>(
                future: ApiClient.fetchInsight(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final weeklyActivity =
                      snapshot.data!['weekly_activity'] as List? ?? [];
                  final streak =
                      (snapshot.data!['streak'] as num?)?.toInt() ?? 0;
                  if (weeklyActivity.isEmpty) return const SizedBox.shrink();
                  return _buildWeeklyScorecard(weeklyActivity, streak);
                },
              ),
              // Weekly Comparison
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _weeklyComparisonFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final current = snapshot.data![0];
                  final previous = snapshot.data![1];
                  if (current.isEmpty && previous.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Comparison',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        WeeklyScorecard(
                          currentWeek: current,
                          previousWeek: previous,
                        ),
                      ],
                    ),
                  );
                },
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
                      onExpanded: () {},
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
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _fetchCurrentWeekSummary() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = _formatDate(DateTime(monday.year, monday.month, monday.day));
    return ApiClient.getWeeklySummary(weekStart);
  }

  Future<Map<String, dynamic>> _fetchPreviousWeekSummary() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final prevMonday = monday.subtract(const Duration(days: 7));
    final weekStart = _formatDate(DateTime(prevMonday.year, prevMonday.month, prevMonday.day));
    return ApiClient.getWeeklySummary(weekStart);
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

  Widget _buildWeeklyScorecard(List<dynamic> weeklyActivity, int streak) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon, 6=Sun
    final activeDays = weeklyActivity.where((v) => v == true).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final isActive = i < weeklyActivity.length &&
                    weeklyActivity[i] == true;
                final isFuture = i > todayIndex;

                Color dotColor;
                String dotLabel;
                Color dotLabelColor;

                if (isActive) {
                  dotColor = const Color(0xFF5B9B96);
                  dotLabel = '✓';
                  dotLabelColor = Colors.white;
                } else if (isFuture) {
                  dotColor = Colors.grey.shade100;
                  dotLabel = '·';
                  dotLabelColor = Colors.grey.shade400;
                } else {
                  dotColor = Colors.grey.shade200;
                  dotLabel = '–';
                  dotLabelColor = Colors.grey.shade500;
                }

                return Column(
                  children: [
                    Text(
                      dayLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        dotLabel,
                        style: TextStyle(
                          color: dotLabelColor,
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 12),
            Text(
              '$activeDays/7 days active  •  🔥 $streak-day streak',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
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
        if (context.mounted) {
          if (success) {
            _refreshHistory();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Database Wiped')),
            );
          }
        }
      } catch (e) {
        debugPrint('Reset error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reset failed. Please try again.')),
          );
        }
      }
    }
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

