import 'package:flutter/material.dart';
import 'screens/journal_screen.dart';

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