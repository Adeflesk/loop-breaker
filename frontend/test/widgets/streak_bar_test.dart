import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/streak_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('StreakBar normal state', () {
    testWidgets('renders Day X of Y label', (tester) async {
      await tester.pumpWidget(_wrap(
        StreakBar(
          streak: 3,
          goalDays: 7,
          isCompleted: false,
          onTap: () {},
        ),
      ));
      expect(find.text('Day 3 of 7'), findsOneWidget);
    });

    testWidgets('renders LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(
        StreakBar(
          streak: 3,
          goalDays: 7,
          isCompleted: false,
          onTap: () {},
        ),
      ));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('does not render completed banner text', (tester) async {
      await tester.pumpWidget(_wrap(
        StreakBar(
          streak: 3,
          goalDays: 7,
          isCompleted: false,
          onTap: () {},
        ),
      ));
      expect(find.textContaining('Streak Complete'), findsNothing);
    });
  });

  group('StreakBar completed state', () {
    testWidgets('renders completed banner with streak count', (tester) async {
      await tester.pumpWidget(_wrap(
        StreakBar(
          streak: 7,
          goalDays: 7,
          isCompleted: true,
          onTap: () {},
        ),
      ));
      expect(find.textContaining('7-Day Streak Complete'), findsOneWidget);
    });

    testWidgets('does not render progress bar', (tester) async {
      await tester.pumpWidget(_wrap(
        StreakBar(
          streak: 7,
          goalDays: 7,
          isCompleted: true,
          onTap: () {},
        ),
      ));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('StreakBar tap callback', () {
    testWidgets('onTap is called in normal state', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(
        StreakBar(
          streak: 3,
          goalDays: 7,
          isCompleted: false,
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, isTrue);
    });

    testWidgets('onTap is called in completed state', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(
        StreakBar(
          streak: 7,
          goalDays: 7,
          isCompleted: true,
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, isTrue);
    });
  });
}
