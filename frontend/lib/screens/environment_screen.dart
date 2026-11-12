import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

class EnvironmentScreen extends StatefulWidget {
  final String? initialLoop;

  const EnvironmentScreen({super.key, this.initialLoop});

  @override
  State<EnvironmentScreen> createState() => _EnvironmentScreenState();
}

class _EnvironmentScreenState extends State<EnvironmentScreen> {
  static const List<String> _loops = [
    'Procrastination',
    'Stress',
    'Anxiety',
    'Overwhelm',
    'Shame',
    'Restlessness',
    'Numbness',
  ];

  static const List<String> _checklistItems = [
    'Put phone in another room during focus blocks',
    'Close all browser tabs except the single active task',
    'Keep a filled water bottle visible on desk before starting',
    'Set a 5-minute physical timer on desk',
    'Turn off non-human push notifications',
    'Prepare tomorrow’s first micro-step the night before',
    'Place walking shoes by the door for quick Zone 2 resets',
  ];

  late String _selectedLoop;
  final Set<String> _checkedItems = {};
  final TextEditingController _customController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedLoop = widget.initialLoop ?? 'Procrastination';
    _loadSavedAudit();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAudit() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLoop = prefs.getString('env_audit_target_loop');
    final savedItems = prefs.getStringList('env_audit_checked_items');
    final savedCustom = prefs.getString('env_audit_custom_step');

    if (mounted) {
      setState(() {
        if (widget.initialLoop == null && savedLoop != null && savedLoop.isNotEmpty) {
          _selectedLoop = savedLoop;
        }
        if (savedItems != null) {
          _checkedItems
            ..clear()
            ..addAll(savedItems);
        }
        if (savedCustom != null) {
          _customController.text = savedCustom;
        }
      });
    }
  }

  Future<void> _saveAudit() async {
    setState(() => _isSaving = true);
    final items = _checkedItems.toList();
    final customStep = _customController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('env_audit_target_loop', _selectedLoop);
      await prefs.setStringList('env_audit_checked_items', items);
      await prefs.setString('env_audit_custom_step', customStep);

      await ApiClient.saveEnvironmentAudit({
        'target_loop': _selectedLoop,
        'checked_items': items,
        'custom_friction_step': customStep,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Environment audit saved! Friction redesigned.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally. Could not reach server.'),
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment Audit'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rewire Principle: Willpower fails when your environment cues the old loop. Add friction to triggers and remove friction from recovery.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Target Loop to Redesign',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _loops.map((loop) {
                      return ChoiceChip(
                        label: Text(loop),
                        selected: _selectedLoop == loop,
                        onSelected: (_) {
                          setState(() => _selectedLoop = loop);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Environmental Friction Checklist',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ..._checklistItems.map((item) {
                    final checked = _checkedItems.contains(item);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item, style: const TextStyle(fontSize: 14)),
                      value: checked,
                      activeColor: const Color(0xFF5B9B96),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _checkedItems.add(item);
                          } else {
                            _checkedItems.remove(item);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text(
                    'Custom Environmental Friction Rule',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'e.g., Charge phone in the kitchen after 9:30 PM',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE0D5CC), width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAudit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9B96),
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Environment Audit'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

