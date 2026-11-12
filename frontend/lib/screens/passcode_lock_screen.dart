import 'package:flutter/material.dart';
import '../services/api_client.dart';

class PasscodeLockScreen extends StatefulWidget {
  final ValueChanged<String> onUnlocked;

  const PasscodeLockScreen({super.key, required this.onUnlocked});

  @override
  State<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends State<PasscodeLockScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter your passcode.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final ok = await ApiClient.verifyPasscode(code);
    if (!mounted) return;

    if (ok) {
      widget.onUnlocked(code);
    } else {
      setState(() {
        _submitting = false;
        _error = 'Incorrect passcode. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 44,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'LoopBreaker',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your private passcode to unlock your journal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _controller,
                      obscureText: true,
                      autofocus: true,
                      onSubmitted: (_) => _submitting ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Passcode',
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Unlock'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

