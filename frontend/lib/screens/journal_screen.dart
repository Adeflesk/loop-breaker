import 'package:flutter/material.dart';

import '../screens/history_screen.dart';
import '../services/api_client.dart';
import '../widgets/breathing_circle.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _controller = TextEditingController();
  String _statusMessage = 'How are you feeling right now?';
  String _riskLevel = 'Low';
  bool _isLoading = false;
  String _aiReasoning = '';

  Future<void> _analyzeEntry() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final data = await ApiClient.analyzeEntry(_controller.text);
      setState(() {
        final node = data['detected_node'] ?? 'Unknown';
        final sublabel = data['sublabel'] ?? data['emotion_sublabel'] ?? 'General';
        _statusMessage = 'Detected: $node ($sublabel)';
        _riskLevel = data['risk_level'] as String? ?? 'Low';
        _aiReasoning = data['reasoning'] ?? 'Analysis complete.';
      });

      if (data['loop_detected'] == true) {
        if (_riskLevel == 'High') {
          _showHALTCheckIn(data);
        } else {
          _showInterventionDialog(data);
        }
      }
      _controller.clear();
    } catch (e) {
      setState(() => _statusMessage = 'Error: Backend unreachable.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFeedback(bool success, {Map<String, bool>? needsCheck}) async {
    try {
      await ApiClient.sendFeedback(success, needsCheck: needsCheck);
    } catch (e) {
      debugPrint('Feedback failed: $e');
    }
  }

  void _showInterventionDialog(Map<String, dynamic> data) {
    _showStandardInterventionDialog(data);
  }

  void _showHALTCheckIn(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> needs = [
      {'icon': Icons.water_drop, 'label': 'Hydration (Water)', 'checked': false},
      {'icon': Icons.restaurant, 'label': 'Fuel (Food)', 'checked': false},
      {'icon': Icons.bed, 'label': 'Rest (Sleep)', 'checked': false},
      {'icon': Icons.directions_walk, 'label': 'Movement (Zone 1-2)', 'checked': false},
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Physiological Check-in',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rewire Principle: You cannot regulate emotions if your basic needs are unmet.',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  const Divider(height: 30),
                  ...needs.map(
                    (need) => CheckboxListTile(
                      secondary: Icon(need['icon'], color: Colors.blueAccent),
                      title: Text(need['label']),
                      value: need['checked'] as bool,
                      onChanged: (val) {
                        setDialogState(() => need['checked'] = val ?? false);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showInterventionDialog(data);
                  },
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final needsPayload = {
                      'hydration': needs[0]['checked'] as bool,
                      'fuel': needs[1]['checked'] as bool,
                      'rest': needs[2]['checked'] as bool,
                      'movement': needs[3]['checked'] as bool,
                    };
                    _sendFeedback(true, needsCheck: needsPayload);
                    Navigator.pop(context);
                    _showInterventionDialog(data);
                  },
                  child: const Text("I've Checked These"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStandardInterventionDialog(Map<String, dynamic> data) {
    final String title = data['intervention_title'] ?? 'Pattern Break';
    final String task = data['intervention_task'] ?? 'Take a moment to breathe.';
    final String education = data['education_info'] ?? '';

    final bool isBreathing = title.contains('Sigh') || title.contains('Breathing');
    final bool isWater = title.contains('Bio-Sync') || title.contains('Needs');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isBreathing
                    ? Icons.air
                    : (isWater ? Icons.water_drop : Icons.psychology),
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 25),
              if (isBreathing) const BreathingCircle(),
              // --- NEW: Educational Content Section ---
              if (education.isNotEmpty) ...[
                const Divider(height: 30),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 20, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          education,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey.shade800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _sendFeedback(false);
                Navigator.pop(context);
              },
              child: const Text(
                "Didn't help",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _sendFeedback(true);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loop Broken! Proud of you.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('I feel better /Action Completed'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LoopBreaker AI'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // AI Insight Card
              FutureBuilder<Map<String, dynamic>>(
                future: ApiClient.fetchInsight(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final String message = snapshot.data?['message'] ?? "";
                  final double? successRate =
                      snapshot.data?['success_rate']?.toDouble();
                  final String? topLoop = snapshot.data?['top_loop'];

                  return Card(
                    elevation: 0,
                    color: Colors.deepPurple.shade50.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.deepPurple.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome,
                                  color: Colors.deepPurple, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "AI Insight",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                _riskLevel == 'High'
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline,
                                color: _riskLevel == 'High'
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _riskLevel == 'High'
                                    ? 'State: Sympathetic Activation'
                                    : 'State: Parasympathetic Recovery',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (successRate != null) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: successRate / 100,
                              backgroundColor: Colors.white,
                              color: Colors.green.shade400,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Resilience Score: ${successRate.toStringAsFixed(0)}%",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Status Card
              Card(
                elevation: 4,
                shadowColor: _riskLevel == 'High'
                    ? Colors.red.withOpacity(0.5)
                    : Colors.black12,
                color: _riskLevel == 'High'
                    ? Colors.red.shade50
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _riskLevel == 'High'
                                  ? Colors.red
                                  : Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_riskLevel Risk',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_aiReasoning.isNotEmpty) ...[const Text(
                        "AI OBSERVATION:",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiReasoning,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe your current state...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _analyzeEntry,
                        child: const Text('Analyze State'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

