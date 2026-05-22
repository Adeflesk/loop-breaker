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
  // Map of node name to available interventions (primary + variants)
  static const Map<String, List<String>> INTERVENTION_VARIANTS = {
    'Stress': ['Physiological Sigh', 'Somatic Reset'],
    'Anxiety': ['5-4-3-2-1 Grounding', 'Somatic Reset'],
    'Procrastination': ['The 5-Minute Sprint', 'Activation Burst'],
    'Overwhelm': ['Brain Dump', 'Activation Burst'],
    'Numbness': ['Temperature Shock', 'Sensation Snap'],
  };

  // Complete catalog of all interventions with their details (primary + movement variants)
  static const Map<String, Map<String, dynamic>> INTERVENTION_CATALOG = {
    'Physiological Sigh': {
      'title': 'Physiological Sigh',
      'task': 'Take a deep breath in, followed by a second short sharp inhale, then a long slow exhale.',
      'education': 'This is the fastest biological way to offload carbon dioxide and lower your heart rate by activating the Vagus nerve.',
      'type': 'breathing'
    },
    'Somatic Reset': {
      'title': 'Somatic Reset',
      'task': 'Stand up. Shake out your arms and legs vigorously for 30 seconds, then stomp your feet 10 times. Feel the ground beneath you.',
      'education': 'Stress is a sympathetic overdrive. Rhythmic shaking and grounding movements activate your parasympathetic nervous system and signal safety to your body.',
      'type': 'movement'
    },
    '5-4-3-2-1 Grounding': {
      'title': '5-4-3-2-1 Grounding',
      'task': 'Name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, and 1 you can taste.',
      'education': 'Grounding forces your brain to switch from the \'Default Mode Network\' (worrying) to the \'Saliency Network\' (physical reality).',
      'type': 'grounding'
    },
    'The 5-Minute Sprint': {
      'title': 'The 5-Minute Sprint',
      'task': 'Pick the smallest sub-task and do it for exactly 5 minutes. You can stop after that.',
      'education': 'Procrastination is often \'emotional regulation\'—your brain is protecting you from a task that feels threatening or boring.',
      'type': 'cognitive'
    },
    'Activation Burst': {
      'title': 'Activation Burst',
      'task': 'Do 10 jumping jacks, 5 burpees, or 30 seconds of dancing. Move fast and let your body lead.',
      'education': 'Procrastination often hides low activation and avoidance. Vigorous movement wakes up your prefrontal cortex and shifts from avoidance to action.',
      'type': 'movement'
    },
    'Brain Dump': {
      'title': 'Brain Dump',
      'task': 'Write down every single tiny thing on your mind for 2 minutes. Don\'t organize them, just dump them.',
      'education': 'Overwhelm happens when working memory is full. Externalizing the list clears \'RAM\' in your prefrontal cortex.',
      'type': 'cognitive'
    },
    'Temperature Shock': {
      'title': 'Temperature Shock',
      'task': 'Hold an ice cube in your hand or splash very cold water on your face.',
      'education': 'Numbness is a \'Freeze\' response. Intense sensory input can help safely pull your nervous system back into the \'Window of Tolerance\'.',
      'type': 'grounding'
    },
    'Sensation Snap': {
      'title': 'Sensation Snap',
      'task': 'Splash cold water on your face or hold ice cubes, then do 10 arm circles or march in place for 20 seconds. Notice what you feel.',
      'education': 'Numbness is a freeze response. Intense sensory input plus light movement safely reactivate your nervous system and bring you back into your window of tolerance.',
      'type': 'movement'
    },
    'The Compassionate Friend': {
      'title': 'The Compassionate Friend',
      'task': 'Imagine a friend felt this way. What would you say to them? Now, say those exact words to yourself.',
      'education': 'Shame thrives in secrecy. By practicing self-compassion, you break the \'inner critic\' loop that keeps you isolated.',
      'type': 'cognitive'
    },
    'The Low-Stakes Connection': {
      'title': 'The Low-Stakes Connection',
      'task': 'Send a simple \'Thinking of you\' or a meme to one person. No deep conversation required.',
      'education': 'Isolation creates a feedback loop that says \'no one cares.\' Small, low-friction interactions provide proof to the contrary.',
      'type': 'other'
    },
  };

  final TextEditingController _controller = TextEditingController();
  String _statusMessage = 'How are you feeling right now?';
  String _riskLevel = 'Low';
  bool _isLoading = false;
  String _aiReasoning = '';
  int _currentInterventionIndex = 0;  // Track which variant is showing

  @override
  void initState() {
    super.initState();
    _validateInterventionCatalog();
  }

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
    _currentInterventionIndex = 0; // Reset to primary intervention on dialog open
    final String nodeDetected = data['detected_node'] ?? 'Unknown';

    // Check if this node has variants
    final List<String>? variants = INTERVENTION_VARIANTS[nodeDetected];
    final bool hasVariants = variants != null && variants.length > 1;

    // Callback to rebuild dialog with next variant
    void _cycleToNextVariant() {
      setState(() {
        if (hasVariants) {
          _currentInterventionIndex = (_currentInterventionIndex + 1) % variants!.length;
        }
      });
      // Close current dialog and reopen with new variant
      Navigator.pop(context);
      _showStandardInterventionDialog(data);
    };

    // Get the current intervention title based on variant index
    String currentTitle;
    if (hasVariants) {
      currentTitle = variants![_currentInterventionIndex];
    } else {
      currentTitle = data['intervention_title'] ?? 'Pattern Break';
    }

    // Look up the full intervention details by title
    final intervention = _getInterventionByTitle(currentTitle);
    final String title = intervention['title'] ?? currentTitle;
    final String task = intervention['task'] ?? 'Take a moment to breathe.';
    final String education = intervention['education'] ?? '';
    final String interventionType = intervention['type'] ?? 'other';

    final bool isBreathing = title.contains('Sigh') || title.contains('Breathing');
    final bool isWater = title.contains('Bio-Sync') || title.contains('Needs');
    final bool isMovement = interventionType == 'movement';

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
                    : (isMovement ? Icons.directions_run : (isWater ? Icons.water_drop : Icons.psychology)),
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
              // Show variant indicator if available
              if (hasVariants) ...[
                const SizedBox(height: 12),
                Text(
                  '${_currentInterventionIndex + 1} of ${variants!.length} approaches',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (hasVariants)
              TextButton(
                onPressed: _cycleToNextVariant,
                child: const Text(
                  "Try a different approach",
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            TextButton(
              onPressed: () {
                _sendFeedback(false);
                Navigator.pop(context);
                _currentInterventionIndex = 0; // Reset for next use
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
                _currentInterventionIndex = 0; // Reset for next use
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
              child: const Text('I feel better'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to validate that all interventions in INTERVENTION_VARIANTS exist in INTERVENTION_CATALOG
  void _validateInterventionCatalog() {
    INTERVENTION_VARIANTS.forEach((node, interventions) {
      for (String title in interventions) {
        assert(INTERVENTION_CATALOG.containsKey(title),
            'Missing intervention in catalog: $title (from $node)');
      }
    });
  }

  // Helper method to look up intervention by title from the class-level catalog
  Map<String, dynamic> _getInterventionByTitle(String title) {
    return INTERVENTION_CATALOG[title] ?? {'title': title, 'task': '', 'education': '', 'type': 'other'};
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

