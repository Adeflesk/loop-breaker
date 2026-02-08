import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const LoopBreakerApp());

class LoopBreakerApp extends StatelessWidget {
  const LoopBreakerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const JournalScreen(),
    );
  }
}

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _controller = TextEditingController();
  String _status = "How are you feeling?";
  String _risk = "Low";
  bool _isLoading = false;

  Future<void> _analyzeEntry() async {
    setState(() => _isLoading = true);
    try {
      // NOTE: Use '127.0.0.1' for iOS Simulator or '10.0.2.2' for Android Emulator
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_text': _controller.text}),
      );

      final data = jsonDecode(response.body);
      setState(() {
        _status = "Detected: ${data['detected_node']}";
        _risk = data['risk_level'];
        _controller.clear();
      });
    } catch (e) {
      setState(() => _status = "Error: Check if FastAPI is running!");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Loop Breaker AI")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              color: _risk == "High" ? Colors.red.shade100 : Colors.blue.shade50,
              child: ListTile(
                title: Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Risk Level: $_risk"),
              ),
            ),
            const Spacer(),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: "Write your thoughts here..."),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(onPressed: _analyzeEntry, child: const Text("Analyze My State")),
          ],
        ),
      ),
    );
  }
}