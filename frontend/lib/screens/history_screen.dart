import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';

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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _buildStatCard('Entries', totalEntries.toString(), Colors.blue),
                    _buildStatCard(
                      'Loops Broken',
                      loopsBroken.toString(),
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Avg Focus',
                      '${(avgConfidence * 100).toStringAsFixed(0)}%',
                      Colors.green,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Emotional Composition',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
              Container(
                height: 150,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                        color: Colors.deepPurple,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.deepPurple.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final bool isLoop = (item['intervention'] != null && 
                        item['intervention'] != 'None' && 
                        item['intervention'].toString().isNotEmpty);
                    final String state = item['state']?.toString() ?? 'Unknown';
                    final String intervention = item['intervention']?.toString() ?? '';
                    
                    // Safe time formatting: check if time exists and has sufficient length
                    String timeStr = '';
                    if (item['time'] != null) {
                      final timeString = item['time'].toString();
                      if (timeString.length >= 16) {
                        timeStr = timeString.substring(11, 16);
                      } else {
                        timeStr = timeString;
                      }
                    }
                    
                    return ListTile(
                      leading: Icon(
                        item['was_successful'] == true
                            ? Icons.verified
                            : Icons.circle,
                        color: item['was_successful'] == true
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: Text(state),
                      subtitle: Text(
                        isLoop
                            ? 'Intervention: $intervention'
                            : 'Healthy State',
                      ),
                      trailing: Text(timeStr),
                    );
                  },
                ),
              ),
              // Thought Records Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                child: Text(
                  'Thought Records',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              FutureBuilder<List<dynamic>>(
                future: ApiClient.fetchThoughtRecords(),
                builder: (context, thoughtSnapshot) {
                  if (thoughtSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    );
                  }

                  final thoughtRecords = thoughtSnapshot.data ?? [];
                  if (thoughtRecords.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No thought records yet.'),
                    );
                  }

                  return Expanded(
                    child: ListView.builder(
                      itemCount: thoughtRecords.length,
                      itemBuilder: (context, index) {
                        final record = thoughtRecords[index];
                        final String balancedThought = record['balanced_thought']?.toString() ?? '';
                        final String linkedNode = record['linked_node']?.toString() ?? 'Unlinked';
                        final String timeStr = (record['timestamp']?.toString() ?? '').substring(0, 10);

                        return ExpansionTile(
                          leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                          title: Text(
                            balancedThought.length > 50
                                ? '${balancedThought.substring(0, 50)}...'
                                : balancedThought,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('$linkedNode · $timeStr'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildThoughtField('Situation:', record['situation']),
                                  const SizedBox(height: 12),
                                  _buildThoughtField('Automatic Thought:', record['automatic_thought']),
                                  const SizedBox(height: 12),
                                  _buildThoughtField('Evidence For:', record['evidence_for']),
                                  const SizedBox(height: 12),
                                  _buildThoughtField('Evidence Against:', record['evidence_against']),
                                  const SizedBox(height: 12),
                                  _buildThoughtField('Balanced Alternative:', record['balanced_thought']),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton.icon(
                  onPressed: () => _resetData(context),
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  label: const Text(
                    'Reset Journey Data',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThoughtField(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value?.toString() ?? '',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(Map<String, double> data) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          sections: data.entries.map((entry) {
            return PieChartSectionData(
              color: _getColorForState(entry.key),
              value: entry.value,
              title: '${entry.value.toInt()}',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getColorForState(String state) {
    switch (state) {
      case 'Stress':
        return Colors.redAccent;
      case 'Anxiety':
        return Colors.orangeAccent;
      case 'Procrastination':
        return Colors.purpleAccent;
      case 'Shame':
        return Colors.blueGrey;
      default:
        return Colors.blueAccent;
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

