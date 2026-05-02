import 'package:flutter/material.dart';

import '../screens/history_screen.dart';
import '../screens/thought_record_screen.dart';
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
  String? _arcLabel;  // Node position in 8-node loop

  Future<void> _analyzeEntry() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final data = await ApiClient.analyzeEntry(_controller.text);
      setState(() {
        final node = data['detected_node'] ?? 'Unknown';
        final sublabel = data['sublabel'] ?? data['emotion_sublabel'] ?? 'unspecified';
        _statusMessage = 'Detected: $node ($sublabel)';
        _riskLevel = data['risk_level'] as String? ?? 'Low';
        _aiReasoning = data['reasoning'] ?? 'Analysis complete.';
        _arcLabel = data['node_arc_label'] as String?;  // Capture arc position
      });

      // Check for MSC protocol (Shame intervention with 3-step sequence)
      final mscSteps = data['msc_steps'] as List?;
      final shameSafetyAlert = data['shame_safety_alert'] as bool? ?? false;

      if (mscSteps != null && mscSteps.isNotEmpty) {
        if (shameSafetyAlert) {
          _showShameSafetyDialog(data);
        } else {
          _showMSCDialog(data, mscSteps);
        }
      } else {
        // Check if there are intervention variants to choose from
        final variants = data['intervention_variants'] as List?;
        if (variants != null && variants.isNotEmpty) {
          _showApproachChooser(data, variants);
        } else if (data['loop_detected'] == true && _riskLevel == 'High') {
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

  void _showApproachChooser(Map<String, dynamic> data, List<dynamic> variants) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Choose Your Approach',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Different approaches work for different people. Pick one that resonates:',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ...variants.map((variant) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      // Create modified data with selected variant
                      final selectedData = {...data};
                      selectedData['intervention_title'] = variant['title'] ?? data['intervention_title'];
                      selectedData['intervention_task'] = variant['task'] ?? data['intervention_task'];
                      selectedData['education_info'] = variant['education'] ?? data['education_info'];
                      selectedData['intervention_type'] = variant['type'] ?? data['intervention_type'];
                      selectedData['chosen_variant'] = variant['title']; // Track selection

                      if (selectedData['loop_detected'] == true && _riskLevel == 'High') {
                        _showHALTCheckIn(selectedData);
                      } else {
                        _showInterventionDialog(selectedData);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.blue.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            variant['title'] ?? 'Approach',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            variant['task'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendFeedback(bool success, {Map<String, bool>? needsCheck, String? chosenVariant}) async {
    try {
      await ApiClient.sendFeedback(success, needsCheck: needsCheck, chosenVariant: chosenVariant);
    } catch (e) {
      debugPrint('Feedback failed: $e');
    }
  }

  void _showInterventionDialog(Map<String, dynamic> data) {
    _showStandardInterventionDialog(data);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                    final chosenVariant = data['chosen_variant'] as String?;
                    _sendFeedback(true, needsCheck: needsPayload, chosenVariant: chosenVariant);
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
            if (data['intervention_type'] == 'cognitive')
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ThoughtRecordScreen(
                        prefilledNode: data['detected_node'] as String?,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Dig deeper →'),
              ),
            TextButton(
              onPressed: () {
                final chosenVariant = data['chosen_variant'] as String?;
                _sendFeedback(false, chosenVariant: chosenVariant);
                Navigator.pop(context);
              },
              child: const Text(
                "Didn't help",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final chosenVariant = data['chosen_variant'] as String?;
                _sendFeedback(true, chosenVariant: chosenVariant);
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

  void _showMSCDialog(Map<String, dynamic> data, List<dynamic> mscSteps) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int currentMscStep = 0;

            return StatefulBuilder(
              builder: (context, setInnerState) {
                final step = mscSteps[currentMscStep] as Map<String, dynamic>;
                final stepNum = step['step'] as int? ?? 1;
                final stepName = step['name'] as String? ?? '';
                final stepTask = step['task'] as String? ?? '';
                final stepEducation = step['education'] as String? ?? '';

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step $stepNum of ${mscSteps.length} — $stepName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stepNum / mscSteps.length,
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade300,
                          color: Colors.deepPurple.shade400,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stepTask,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                size: 20, color: Colors.blueAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stepEducation,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey.shade700,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    if (currentMscStep < mscSteps.length - 1)
                      ElevatedButton(
                        onPressed: () {
                          setInnerState(() => currentMscStep++);
                        },
                        child: const Text('Continue'),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          final chosenVariant = data['chosen_variant'] as String?;
                          _sendFeedback(true, chosenVariant: chosenVariant);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You practiced self-compassion. Well done.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text('Complete'),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showShameSafetyDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Check In With Yourself',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "You've visited this space several times today. That takes courage to acknowledge. "
            "If you're finding things heavy, consider reaching out to someone you trust.",
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Find Support',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showMSCDialog(data, data['msc_steps'] as List? ?? []);
              },
              child: const Text('Continue to Exercise'),
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
                  final String? trend = snapshot.data?['trend'];
                  final int? streak = snapshot.data?['streak'];

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
                          if (trend != null && trend != 'unknown') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  trend == 'improving'
                                      ? Icons.trending_up
                                      : trend == 'declining'
                                          ? Icons.trending_down
                                          : Icons.trending_flat,
                                  color: trend == 'improving'
                                      ? Colors.green
                                      : trend == 'declining'
                                          ? Colors.orange
                                          : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Recovery Trend: ${trend[0].toUpperCase()}${trend.substring(1)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (streak != null && streak > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department,
                                    color: Colors.orange, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Streak: $streak day${streak > 1 ? "s" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                      if (_arcLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _arcLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

