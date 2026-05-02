import 'package:flutter/material.dart';

import '../services/api_client.dart';

class ThoughtRecordScreen extends StatefulWidget {
  final String? prefilledNode;

  const ThoughtRecordScreen({super.key, this.prefilledNode});

  @override
  State<ThoughtRecordScreen> createState() => _ThoughtRecordScreenState();
}

class _ThoughtRecordScreenState extends State<ThoughtRecordScreen> {
  final TextEditingController _situationController = TextEditingController();
  final TextEditingController _automaticThoughtController = TextEditingController();
  final TextEditingController _evidenceForController = TextEditingController();
  final TextEditingController _evidenceAgainstController = TextEditingController();
  final TextEditingController _balancedThoughtController = TextEditingController();

  int _currentStep = 0;
  bool _isSubmitting = false;

  final List<String> _stepTitles = [
    'The Situation',
    'Your Automatic Thought',
    'Examining the Evidence',
    'The Balanced Alternative',
  ];

  final List<String> _stepPrompts = [
    'What happened? Describe the situation that triggered this state.',
    'What was the first thought or belief that came to mind?',
    'Look at both sides: What supports and challenges this thought?',
    'What\'s a more balanced, realistic way to see this?',
  ];

  @override
  void dispose() {
    _situationController.dispose();
    _automaticThoughtController.dispose();
    _evidenceForController.dispose();
    _evidenceAgainstController.dispose();
    _balancedThoughtController.dispose();
    super.dispose();
  }

  bool _isCurrentStepComplete() {
    switch (_currentStep) {
      case 0:
        return _situationController.text.trim().isNotEmpty;
      case 1:
        return _automaticThoughtController.text.trim().isNotEmpty;
      case 2:
        return _evidenceForController.text.trim().isNotEmpty &&
            _evidenceAgainstController.text.trim().isNotEmpty;
      case 3:
        return _balancedThoughtController.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _submitThoughtRecord() async {
    if (!_isCurrentStepComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete this step')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ApiClient.createThoughtRecord({
        'situation': _situationController.text,
        'automatic_thought': _automaticThoughtController.text,
        'evidence_for': _evidenceForController.text,
        'evidence_against': _evidenceAgainstController.text,
        'balanced_thought': _balancedThoughtController.text,
        'linked_node': widget.prefilledNode,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thought record saved. Well done!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildStepInput(
          controller: _situationController,
          prompt: _stepPrompts[0],
          hint: 'Describe what happened...',
          helper: 'Example: "I was asked to present my project ideas in a meeting"',
        );
      case 1:
        return _buildStepInput(
          controller: _automaticThoughtController,
          prompt: _stepPrompts[1],
          hint: 'What thought came up?',
          helper: 'Example: "I will mess up and everyone will judge me"',
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _stepPrompts[2],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'What supports this thought?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _evidenceForController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Evidence for...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What challenges this thought?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _evidenceAgainstController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Evidence against...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ],
        );
      case 3:
        return _buildStepInput(
          controller: _balancedThoughtController,
          prompt: _stepPrompts[3],
          hint: 'What\'s a more balanced thought?',
          helper: 'Example: "I\'ve prepared well. I can handle questions and learn from feedback."',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepInput({
    required TextEditingController controller,
    required String prompt,
    required String hint,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          prompt,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          helper,
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[100],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thought Record'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Step indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) {
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index <= _currentStep ? Colors.blueAccent : Colors.grey[300],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index <= _currentStep ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stepTitles[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: index <= _currentStep ? Colors.blueAccent : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            // Content
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildStep(),
              ),
            ),
            const SizedBox(height: 40),
            // Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => setState(() => _currentStep--),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  )
                else
                  const SizedBox.shrink(),
                if (_currentStep < 3)
                  ElevatedButton.icon(
                    onPressed: !_isCurrentStepComplete() || _isSubmitting
                        ? null
                        : () => setState(() => _currentStep++),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitThoughtRecord,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: const Text('Save Record'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
