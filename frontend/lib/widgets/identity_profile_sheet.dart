import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

class IdentityProfileSheet extends StatefulWidget {
  final List<String> initialValues;
  final String initialStatement;

  const IdentityProfileSheet({
    super.key,
    this.initialValues = const [],
    this.initialStatement = '',
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    List<String> initialValues = const [],
    String initialStatement = '',
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => IdentityProfileSheet(
        initialValues: initialValues,
        initialStatement: initialStatement,
      ),
    );
  }

  @override
  State<IdentityProfileSheet> createState() => _IdentityProfileSheetState();
}

class _IdentityProfileSheetState extends State<IdentityProfileSheet> {
  static const List<String> curatedValues = [
    'Presence',
    'Compassion',
    'Focus',
    'Growth',
    'Connection',
    'Courage',
    'Integrity',
    'Balance',
    'Creativity',
    'Vitality',
  ];

  late final Set<String> _selectedValues;
  late final TextEditingController _statementController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedValues = Set<String>.from(widget.initialValues);
    _statementController = TextEditingController(
      text: widget.initialStatement.isNotEmpty
          ? widget.initialStatement
          : 'I am someone who pauses and responds with intention.',
    );
  }

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  void _toggleValue(String value) {
    setState(() {
      if (_selectedValues.contains(value)) {
        _selectedValues.remove(value);
      } else if (_selectedValues.length < 5) {
        _selectedValues.add(value);
      }
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final values = _selectedValues.toList();
    final statement = _statementController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('user_values', values);
      await prefs.setString('identity_statement', statement);

      await ApiClient.saveUserProfile({
        'values': values,
        'identity_statement': statement,
      });

      if (mounted) {
        Navigator.pop(context, {
          'values': values,
          'identity_statement': statement,
        });
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, {
          'values': values,
          'identity_statement': statement,
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Values & Identity Anchor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select up to 5 core values and craft your identity statement.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: curatedValues.map((value) {
                final selected = _selectedValues.contains(value);
                return FilterChip(
                  label: Text(value),
                  selected: selected,
                  selectedColor: const Color(0xFF5B9B96).withValues(alpha: 0.25),
                  onSelected: (_) => _toggleValue(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Identity Statement ("I am someone who…")',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _statementController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'I am someone who...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9B96),
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Identity Anchor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
