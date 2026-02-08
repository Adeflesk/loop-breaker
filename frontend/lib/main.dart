import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const LoopBreakerApp());
}

class LoopBreakerApp extends StatelessWidget {
  const LoopBreakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoopBreaker AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
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
  String _statusMessage = "How are you feeling right now?";
  String _riskLevel = "Low";
  bool _isLoading = false;

  // --- API LOGIC ---

  Future<void> _analyzeEntry() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_text': _controller.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _statusMessage = "Detected: ${data['detected_node']}";
          _riskLevel = data['risk_level'];
        });

        if (data['loop_detected'] == true) {
          _showInterventionDialog(
            data['intervention_title'] ?? "Pattern Break",
            data['intervention_task'] ?? "Take a moment to breathe.",
          );
        }
      }
      _controller.clear();
    } catch (e) {
      setState(() => _statusMessage = "Error: Backend unreachable.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFeedback(bool success) async {
    try {
      await http.post(
        Uri.parse('http://127.0.0.1:8000/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'success': success}),
      );
    } catch (e) {
      debugPrint("Feedback failed: $e");
    }
  }

  // --- ENHANCED JUST-IN-TIME DIALOG ---

  void _showInterventionDialog(String title, String task) {
    bool isBreathing = title.contains("Sigh") || title.contains("Breathing");
    bool isWater = title.contains("Bio-Sync") || title.contains("Needs");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isBreathing ? Icons.air : (isWater ? Icons.water_drop : Icons.bolt),
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(task, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 25),
              if (isBreathing) const BreathingCircle(),
              if (isWater) const Icon(Icons.directions_walk, size: 60, color: Colors.blueAccent),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _sendFeedback(false);
                Navigator.pop(context);
              },
              child: const Text("Didn't help", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                _sendFeedback(true);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text("Action Completed"),
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
        title: const Text("LoopBreaker AI"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Card(
                color: _riskLevel == "High" ? Colors.red.shade50 : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(_statusMessage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("Risk Level: $_riskLevel", style: TextStyle(color: _riskLevel == "High" ? Colors.red : Colors.green)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Describe your current state...",
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
                        child: const Text("Analyze State"),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- BREATHING VISUAL AID ---

class BreathingCircle extends StatefulWidget {
  const BreathingCircle({super.key});

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 120 + (60 * _animation.value),
          height: 120 + (60 * _animation.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blueAccent.withOpacity(0.2),
            border: Border.all(color: Colors.blueAccent, width: 3),
          ),
          child: Center(
            child: Text(
              _animation.value > 0.5 ? "INHALE" : "EXHALE",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ),
        );
      },
    );
  }
}

// --- HISTORY SCREEN ---

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<List<dynamic>> fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/history'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Journey History")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No entries yet."));
          
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final item = snapshot.data![index];
              return ListTile(
                leading: const Icon(Icons.history_edu),
                title: Text(item['state'] ?? "Unknown"),
                subtitle: Text("Intervention: ${item['intervention']}"),
                trailing: Text(item['time'].toString().split('.')[0].substring(11, 16)),
              );
            },
          );
        },
      ),
    );
  }
}