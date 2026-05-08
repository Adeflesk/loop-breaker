import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../widgets/risk_level_badge.dart';

class JournalHistoryScreen extends StatefulWidget {
  const JournalHistoryScreen({super.key});

  @override
  State<JournalHistoryScreen> createState() => _JournalHistoryScreenState();
}

class _JournalHistoryScreenState extends State<JournalHistoryScreen> {
  late Future<List<dynamic>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = ApiClient.fetchJournalEntries();
  }

  void _refresh() {
    setState(() {
      _entriesFuture = ApiClient.fetchJournalEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journal'),
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Text('No entries yet. Start journaling!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) => _EntryCard(
              entry: entries[index],
              onOutcomeRecorded: _refresh,
            ),
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onOutcomeRecorded;

  const _EntryCard({
    required this.entry,
    required this.onOutcomeRecorded,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  late String _currentOutcome;

  @override
  void initState() {
    super.initState();
    _currentOutcome = widget.entry['user_outcome'] as String? ?? '';
  }

  Future<void> _recordOutcome(String outcome) async {
    try {
      await ApiClient.recordJournalOutcome(
        widget.entry['id'] as String,
        outcome,
      );
      setState(() {
        _currentOutcome = outcome;
      });
      widget.onOutcomeRecorded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Outcome recorded'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording outcome: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final str = timestamp.toString();
    try {
      final dt = DateTime.parse(str);
      return '${dt.month}/${dt.day}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return str;
    }
  }

  Widget _buildOutcomeBadge() {
    if (_currentOutcome.isEmpty) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    IconData badgeIcon;

    switch (_currentOutcome) {
      case 'helped':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle;
        break;
      case "didn't help":
        badgeColor = Colors.orange;
        badgeIcon = Icons.cancel;
        break;
      case 'neutral':
        badgeColor = Colors.blue;
        badgeIcon = Icons.radio_button_unchecked;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            _currentOutcome,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawText = widget.entry['raw_text'] as String? ?? '';
    final detectedState = widget.entry['detected_state'] as String? ?? 'Unknown';
    final sublabel = widget.entry['sublabel'] as String? ?? 'unspecified';
    final confidence = widget.entry['confidence'] as num? ?? 0.0;
    final reasoning = widget.entry['reasoning'] as String? ?? '';
    final riskLevel = widget.entry['risk_level'] as String? ?? 'Low';
    final interventionTitle = widget.entry['intervention_title'] as String? ?? 'Pattern Break';
    final timestamp = widget.entry['timestamp'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detected: $detectedState ($sublabel)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            _buildOutcomeBadge(),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'What you wrote:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    rawText,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'State Analysis',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              RiskLevelBadge(
                                riskLevel: riskLevel,
                                showLabel: true,
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(confidence * 100).toStringAsFixed(0)}% confident',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'AI Reasoning',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reasoning,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blueGrey[700],
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B9B96).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF5B9B96).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        interventionTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF5B9B96),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Suggested intervention',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Did this intervention help?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _currentOutcome != 'helped'
                          ? () => _recordOutcome('helped')
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _currentOutcome == 'helped'
                            ? Colors.green.withOpacity(0.2)
                            : null,
                      ),
                      child: Text(
                        'Helped',
                        style: TextStyle(
                          color: _currentOutcome == 'helped'
                              ? Colors.green
                              : null,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _currentOutcome != 'neutral'
                          ? () => _recordOutcome('neutral')
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _currentOutcome == 'neutral'
                            ? Colors.blue.withOpacity(0.2)
                            : null,
                      ),
                      child: Text(
                        'Neutral',
                        style: TextStyle(
                          color: _currentOutcome == 'neutral'
                              ? Colors.blue
                              : null,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _currentOutcome != "didn't help"
                          ? () => _recordOutcome("didn't help")
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _currentOutcome == "didn't help"
                            ? Colors.orange.withOpacity(0.2)
                            : null,
                      ),
                      child: Text(
                        "Didn't Help",
                        style: TextStyle(
                          color: _currentOutcome == "didn't help"
                              ? Colors.orange
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
