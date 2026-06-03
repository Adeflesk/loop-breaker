import 'package:flutter/material.dart';

import '../screens/history_screen.dart';
import '../services/api_client.dart';
import '../services/goal_service.dart';
import '../widgets/breathing_circle.dart';
import '../widgets/crisis_safety_dialog.dart';
import '../widgets/personalization_cards.dart';
import '../widgets/streak_bar.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
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
  int _alternativeIndex = -1; // -1 = primary; 0,1,... = alternatives[index]
  late final GoalService _goalService;
  late Future<Map<String, dynamic>> _streakFuture;

  @override
  void initState() {
    super.initState();
    _goalService = GoalService();
    _streakFuture = _loadStreakData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyzeEntry() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final data = await ApiClient.analyzeEntry(_controller.text);

      // CRISIS DETECTION: Check if API returned crisis_detected=true
      if (data['crisis_detected'] == true) {
        // Extract crisis resources and keywords
        final crisisResources = data['crisis_resources'];
        final List<Map<String, String>> hotlines = [];

        if (crisisResources != null && crisisResources['hotlines'] != null) {
          for (var hotline in crisisResources['hotlines']) {
            hotlines.add({
              'name': hotline['name'] ?? 'Crisis Support',
              'phone': hotline['phone'] ?? '',
              'text': hotline['text'] ?? '',
              'url': hotline['url'] ?? '',
              'available': hotline['available'] ?? '24/7',
              'emergency': crisisResources['emergency'] ?? 'Call 911 for immediate danger',
            });
          }
        }

        // Show crisis dialog
        _showCrisisDialog(hotlines, data);
        _controller.clear();
        setState(() => _isLoading = false);
        return;
      }

      // NORMAL FLOW: Update status and proceed to intervention
      setState(() {
        final node = data['detected_node'] ?? 'Unknown';
        final sublabel = data['sublabel'] ?? data['emotion_sublabel'] ?? 'General';
        _statusMessage = 'Detected: $node ($sublabel)';
        _riskLevel = (data['risk_level'] ?? 'Low') as String;
        _aiReasoning = data['reasoning'] ?? 'Analysis complete.';
      });

      if (data['loop_detected'] == true && _riskLevel == 'High') {
        _showHALTCheckIn(data);
      } else {
        _showInterventionDialog(data);
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

  void _showCrisisDialog(
    List<Map<String, String>> hotlines,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CrisisSafetyDialog(
          hotlines: hotlines,
          onContinue: () {
            Navigator.pop(context);
            // After user acknowledges, show intervention dialog
            _showInterventionDialog(data);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        );
      },
    );
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
    _alternativeIndex = -1;

    final List<dynamic>? rawAlternatives = data['alternatives'] as List<dynamic>?;
    final List<Map<String, dynamic>> alternatives = rawAlternatives
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final List<dynamic>? rawSteps = data['msc_steps'] as List<dynamic>?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool showSteps = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isExhausted = alternatives.isEmpty
                ? _alternativeIndex >= 0
                : _alternativeIndex >= alternatives.length;

            final Map<String, dynamic> content;
            if (!isExhausted && _alternativeIndex >= 0) {
              content = alternatives[_alternativeIndex];
            } else if (isExhausted) {
              content = {};
            } else {
              content = {
                'title': data['intervention_title'] ?? 'Pattern Break',
                'task': data['intervention_task'] ?? 'Take a moment to breathe.',
                'education': data['education_info'] ?? '',
                'type': data['intervention_type'] ?? 'other',
              };
            }

            final String title = content['title'] as String? ?? 'Pattern Break';
            final String task = content['task'] as String? ?? '';
            final String education = content['education'] as String? ?? '';
            final String interventionType = content['type'] as String? ?? 'other';

            final bool isBreathing = title.contains('Sigh') || title.contains('Breathing');
            final bool isWater = title.contains('Bio-Sync') || title.contains('Needs');
            final bool isMovement = interventionType == 'movement';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    isBreathing
                        ? Icons.air
                        : (isMovement
                            ? Icons.directions_run
                            : (isWater ? Icons.water_drop : Icons.psychology)),
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isExhausted ? 'All suggestions tried' : title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isExhausted) ...[
                      const Text(
                        "You've tried all the suggestions. Consider reaching out to someone you trust.",
                        style: TextStyle(fontSize: 15),
                      ),
                    ] else ...[
                      Text(
                        task,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 25),
                      if (isBreathing) const BreathingCircle(),
                      if (education.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Why this works (neuroscience)'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                education,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (rawSteps != null && rawSteps.isNotEmpty && _alternativeIndex < 0) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setDialogState(() => showSteps = !showSteps),
                          child: Text(
                            showSteps ? 'Hide guidance' : 'Show full guidance',
                            style: const TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                        if (showSteps)
                          ...rawSteps.map((s) {
                            final step = Map<String, dynamic>.from(s as Map);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step['name'] as String? ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    step['task'] as String? ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                      if (data['personal_loop'] != null) ...[
                        const SizedBox(height: 16),
                        LoopPatternCard(personalLoop: data['personal_loop']),
                      ],
                      if (data['intervention_effectiveness'] != null) ...[
                        const SizedBox(height: 16),
                        EffectivenessCard(
                          interventionEffectiveness: data['intervention_effectiveness'],
                          interventionTitle: title,
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => setDialogState(() {
                    showSteps = false;
                    setState(() => _alternativeIndex++);
                  }),
                  child: const Text(
                    "This isn't helping",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                if (!isExhausted) ...[
                  TextButton(
                    onPressed: () {
                      _sendFeedback(false);
                      Navigator.pop(context);
                      setState(() => _alternativeIndex = -1);
                    },
                    child: const Text(
                      "Didn't help",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _sendFeedback(true);
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      setState(() => _alternativeIndex = -1);
                      messenger.showSnackBar(
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
              ],
            );
          },
        );
      },
    );
  }

  // Helper method to look up intervention by title from the class-level catalog
  Map<String, dynamic> _getInterventionByTitle(String title) {
    return INTERVENTION_CATALOG[title] ?? {'title': title, 'task': '', 'education': '', 'type': 'other'};
  }

  Future<Map<String, dynamic>> _loadStreakData() async {
    final history = await ApiClient.fetchHistory();
    final goalDays = await _goalService.getGoalDays();
    final streak = _goalService.computeStreak(history);
    final isCompleted = _goalService.isGoalCompleted(streak, goalDays);
    if (isCompleted) await _goalService.markGoalCompleted();
    return {
      'streak': streak,
      'goalDays': goalDays,
      'isCompleted': isCompleted,
    };
  }

  Future<void> _showDailyCheckIn() async {
    double sleepHours = 7.0;
    int hydration = 3;
    int foodQuality = 3;
    double movementMinutes = 30.0;
    int stressLevel = 3;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget ratingButtons(
              int value,
              ValueChanged<int> onChanged, {
              bool isStress = false,
            }) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final selected = (i + 1) == value;
                  final color = isStress ? Colors.red : const Color(0xFF5B9B96);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => onChanged(i + 1),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? color : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Daily Check-In',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sleep (hours)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: sleepHours,
                      min: 0,
                      max: 12,
                      divisions: 24,
                      label: sleepHours.toStringAsFixed(1),
                      onChanged: (v) => setDialogState(() => sleepHours = v),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hydration',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ratingButtons(
                      hydration,
                      (v) => setDialogState(() => hydration = v),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Food Quality',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ratingButtons(
                      foodQuality,
                      (v) => setDialogState(() => foodQuality = v),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Movement (minutes)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: movementMinutes,
                      min: 0,
                      max: 180,
                      divisions: 18,
                      label: movementMinutes.toInt().toString(),
                      onChanged: (v) => setDialogState(() => movementMinutes = v),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Stress Level',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ratingButtons(
                      stressLevel,
                      (v) => setDialogState(() => stressLevel = v),
                      isStress: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    try {
                      await ApiClient.createDailyCheck({
                        'sleep_hours': sleepHours,
                        'hydration_rating': hydration,
                        'food_quality': foodQuality,
                        'movement_minutes': movementMinutes.toInt(),
                        'stress_level': stressLevel,
                      });
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Check-in saved!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Failed to save check-in. Please try again.'),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B9B96),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Check-In'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGoalPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set Recovery Goal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'How many consecutive days do you want to aim for?',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [3, 7, 14, 30].map((days) {
                  return ActionChip(
                    label: Text('$days days'),
                    onPressed: () async {
                      await _goalService.setGoalDays(days);
                      await _goalService.clearGoalCompleted();
                      if (context.mounted) Navigator.pop(context);
                      setState(() {
                        _streakFuture = _loadStreakData();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LoopBreaker'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showDailyCheckIn,
        tooltip: 'Daily Check-In',
        backgroundColor: const Color(0xFF5B9B96),
        foregroundColor: Colors.white,
        child: const Icon(Icons.favorite),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Streak Bar
              FutureBuilder<Map<String, dynamic>>(
                future: _streakFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final streak = snapshot.data!['streak'] as int;
                  final goalDays = snapshot.data!['goalDays'] as int;
                  final isCompleted = snapshot.data!['isCompleted'] as bool;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StreakBar(
                      streak: streak,
                      goalDays: goalDays,
                      isCompleted: isCompleted,
                      onTap: _showGoalPicker,
                    ),
                  );
                },
              ),
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
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
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

