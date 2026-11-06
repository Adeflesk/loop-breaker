import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../widgets/breathing_circle.dart';
import '../widgets/identity_profile_sheet.dart';

class DailyPracticeScreen extends StatefulWidget {
  const DailyPracticeScreen({super.key});

  @override
  State<DailyPracticeScreen> createState() => _DailyPracticeScreenState();
}

class _DailyPracticeScreenState extends State<DailyPracticeScreen> {
  static const String _reminderPrefKey = 'daily_practice_reminder_time';

  final TextEditingController _intentionController = TextEditingController();
  final TextEditingController _gratitudeController = TextEditingController();

  int _currentStep = 0;
  int _breathingSeconds = 60;
  bool _isSubmitting = false;
  String? _reminderTime;
  List<String> _userValues = [];
  String _identityStatement = '';

  final List<String> _stepTitles = [
    'Physiological Reset',
    'Daily Intention',
    'Gratitude & Grounding',
  ];

  final List<String> _intentionSuggestions = [
    'Pause and take one sigh before reacting',
    'Check HALT needs before scrolling',
    'Start hard tasks with a 5-minute sprint',
    'Speak to myself like a trusted friend',
  ];

  @override
  void initState() {
    super.initState();
    _loadReminderTime();
  }

  @override
  void dispose() {
    _intentionController.dispose();
    _gratitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _reminderTime = prefs.getString(_reminderPrefKey);
      _userValues = prefs.getStringList('user_values') ?? [];
      _identityStatement = prefs.getString('identity_statement') ?? '';
    });
  }

  Future<void> _saveReminderTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderPrefKey, time);
    if (!mounted) return;
    setState(() {
      _reminderTime = time;
    });
  }

  void _showReminderPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Practice Reminder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your preferred daily practice anchor time:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: ['07:30', '08:30', '12:30', '20:00'].map((time) {
                  final isSelected = _reminderTime == time;
                  return ChoiceChip(
                    label: Text(time),
                    selected: isSelected,
                    onSelected: (_) async {
                      final messenger = ScaffoldMessenger.of(context);
                      await _saveReminderTime(time);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Daily practice reminder set for $time'),
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  bool _isCurrentStepComplete() {
    switch (_currentStep) {
      case 0:
        return true;
      case 1:
        return _intentionController.text.trim().isNotEmpty;
      case 2:
        return _gratitudeController.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _submitPractice() async {
    if (!_isCurrentStepComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete this step')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ApiClient.createPracticeSession({
        'intention': _intentionController.text.trim(),
        'gratitude': _gratitudeController.text.trim(),
        'breathing_seconds': _breathingSeconds,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily practice complete! Capacity built.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save practice. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildBreathingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Build regulatory capacity before stress hits. Follow the breathing circle to lower baseline sympathetic tone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        const BreathingCircle(),
        const SizedBox(height: 24),
        const Text(
          'Session duration',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [60, 120, 180].map((seconds) {
            final minutes = seconds ~/ 60;
            return ChoiceChip(
              label: Text('$minutes min'),
              selected: _breathingSeconds == seconds,
              onSelected: (_) {
                setState(() => _breathingSeconds = seconds);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIntentionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF5B9B96).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF5B9B96).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Identity Anchor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5B9B96),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final updated = await IdentityProfileSheet.show(
                        context,
                        initialValues: _userValues,
                        initialStatement: _identityStatement,
                      );
                      if (updated != null && mounted) {
                        setState(() {
                          _userValues =
                              List<String>.from(updated['values'] as List? ?? []);
                          _identityStatement =
                              updated['identity_statement'] as String? ?? '';
                        });
                      }
                    },
                    child: const Text(
                      'Edit Identity',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              Text(
                _identityStatement.isNotEmpty
                    ? _identityStatement
                    : 'I am someone who pauses and responds with intention.',
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_userValues.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Core Values: ${_userValues.join(" • ")}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ],
          ),
        ),
        const Text(
          'What is one intentional response you want to practice today before a loop starts?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _intentionSuggestions.map((suggestion) {
            return ActionChip(
              label: Text(
                suggestion,
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () {
                setState(() {
                  _intentionController.text = suggestion;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _intentionController,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Write your daily intention...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGratitudeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Name one specific thing you are grateful for or grounded by right now:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rewire Principle: Directing attention toward safety and gratitude shifts the default mode network away from threat scanning.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _gratitudeController,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'What are you grateful for today?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBreathingStep();
      case 1:
        return _buildIntentionStep();
      case 2:
        return _buildGratitudeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isComplete = _isCurrentStepComplete();

    return Scaffold(
      appBar: AppBar(
        title: const Text('3-Minute Daily Practice'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showReminderPicker,
            icon: const Icon(Icons.notifications_outlined, size: 18),
            label: Text(_reminderTime ?? 'Reminder'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFAF8F6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${_currentStep + 1} of ${_stepTitles.length}: ${_stepTitles[_currentStep]}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B9B96),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / _stepTitles.length,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE0D5CC),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF5B9B96),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStepContent(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE0D5CC), width: 1),
              ),
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _currentStep--);
                      },
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : (_currentStep == _stepTitles.length - 1
                            ? (isComplete ? _submitPractice : null)
                            : (isComplete
                                ? () => setState(() => _currentStep++)
                                : null)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B9B96),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep == _stepTitles.length - 1
                                ? 'Complete Practice'
                                : 'Next',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

