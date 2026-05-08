import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'thought_record_screen.dart';

class ThoughtRecordsTab extends StatefulWidget {
  const ThoughtRecordsTab({super.key});

  @override
  State<ThoughtRecordsTab> createState() => _ThoughtRecordsTabState();
}

class _ThoughtRecordsTabState extends State<ThoughtRecordsTab> {
  late Future<List<dynamic>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = ApiClient.fetchThoughtRecords();
  }

  void _refreshRecords() {
    setState(() {
      _recordsFuture = ApiClient.fetchThoughtRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thought Records'),
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Could not load exercises. Pull to refresh.',
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No thought records yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first thought record to explore your thinking patterns using CBT principles.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ThoughtRecordScreen(),
                          ),
                        );
                        if (result == true) {
                          _refreshRecords();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Thought Record'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _recordsFuture = ApiClient.fetchThoughtRecords();
              });
              await _recordsFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: records.length + 1,
              itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ThoughtRecordScreen(),
                        ),
                      );
                      if (result == true) {
                        _refreshRecords();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Thought Record'),
                  ),
                );
              }

              final record = records[index - 1];
              final String balancedThought =
                  record['balanced_thought']?.toString() ?? '';
              final String linkedNode =
                  record['linked_node']?.toString() ?? 'Unlinked';
              final String timeStr =
                  (record['timestamp']?.toString() ?? '').substring(0, 10);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0D5CC),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD89E6F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFFD89E6F),
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    balancedThought.length > 60
                        ? '${balancedThought.substring(0, 60)}...'
                        : balancedThought,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '$linkedNode • $timeStr',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildThoughtField(
                            'Situation:',
                            record['situation'],
                          ),
                          const SizedBox(height: 16),
                          _buildThoughtField(
                            'Automatic Thought:',
                            record['automatic_thought'],
                          ),
                          const SizedBox(height: 16),
                          _buildThoughtField(
                            'Evidence For:',
                            record['evidence_for'],
                          ),
                          const SizedBox(height: 16),
                          _buildThoughtField(
                            'Evidence Against:',
                            record['evidence_against'],
                          ),
                          const SizedBox(height: 16),
                          _buildThoughtField(
                            'Balanced Alternative:',
                            record['balanced_thought'],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              },
            ),
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
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey[700],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey[200]!,
              width: 0.5,
            ),
          ),
          child: Text(
            value?.toString() ?? '',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
