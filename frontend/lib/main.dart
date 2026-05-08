import 'package:flutter/material.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(const LoopBreakerApp());
}

class LoopBreakerApp extends StatelessWidget {
  const LoopBreakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Warm, organic therapeutic palette
    const Color primaryTeal = Color(0xFF5B9B96);      // Warm sage teal
    const Color accentWarm = Color(0xFFD89E6F);       // Warm clay/terracotta
    const Color surfaceWarm = Color(0xFFF9F5F0);      // Off-white with warmth
    const Color neutralGrey = Color(0xFF6B6B6B);      // Warm grey

    return MaterialApp(
      title: 'LoopBreaker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: primaryTeal,
          onPrimary: Colors.white,
          secondary: accentWarm,
          onSecondary: Colors.white,
          tertiary: const Color(0xFF8B7355),
          surface: surfaceWarm,
          onSurface: neutralGrey,
          error: const Color(0xFFC16B4B),
        ),
        scaffoldBackgroundColor: surfaceWarm,
        appBarTheme: AppBarTheme(
          backgroundColor: surfaceWarm,
          foregroundColor: neutralGrey,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            color: Color(0xFF3A3A3A),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0D5CC), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0D5CC), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryTeal, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryTeal,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE0D5CC),
          thickness: 1,
          space: 24,
        ),
      ),
      home: const HomeShell(),
    );
  }
}