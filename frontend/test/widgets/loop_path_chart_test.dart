import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/loop_path_chart.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: w)),
      );

  testWidgets('shows placeholder when path is empty', (tester) async {
    await tester.pumpWidget(wrap(
      const LoopPathChart(path: []),
    ));
    expect(
      find.text('No entries yet. Start journaling to see your loop patterns.'),
      findsOneWidget,
    );
  });

  testWidgets('shows timeline header when path has items', (tester) async {
    await tester.pumpWidget(wrap(
      LoopPathChart(
        path: [
          {
            'state': 'Stress',
            'confidence': 0.7,
            'timestamp': '2026-05-29T10:30:00',
            'has_intervention': false,
          }
        ],
      ),
    ));
    await tester.pump();
    expect(find.text('Your State Transitions'), findsOneWidget);
  });

  testWidgets('shows state name in timeline entry', (tester) async {
    await tester.pumpWidget(wrap(
      LoopPathChart(
        path: [
          {
            'state': 'Anxiety',
            'confidence': 0.5,
            'timestamp': '2026-05-29T14:20:00',
            'has_intervention': false,
          }
        ],
      ),
    ));
    await tester.pump();
    expect(find.text('Anxiety'), findsOneWidget);
  });

  testWidgets('shows confidence percentage for entry', (tester) async {
    await tester.pumpWidget(wrap(
      LoopPathChart(
        path: [
          {
            'state': 'Stress',
            'confidence': 0.75,
            'timestamp': '2026-05-29T09:00:00',
            'has_intervention': false,
          }
        ],
      ),
    ));
    await tester.pump();
    expect(find.text('Confidence: 75%'), findsOneWidget);
  });

  testWidgets('shows Intervention badge when has_intervention is true', (tester) async {
    await tester.pumpWidget(wrap(
      LoopPathChart(
        path: [
          {
            'state': 'Stress',
            'confidence': 0.6,
            'timestamp': '2026-05-29T10:00:00',
            'has_intervention': true,
          }
        ],
      ),
    ));
    await tester.pump();
    expect(find.text('Intervention'), findsOneWidget);
  });

  testWidgets('renders multiple entries', (tester) async {
    await tester.pumpWidget(wrap(
      LoopPathChart(
        path: [
          {
            'state': 'Stress',
            'confidence': 0.6,
            'timestamp': '2026-05-29T10:00:00',
            'has_intervention': false,
          },
          {
            'state': 'Anxiety',
            'confidence': 0.4,
            'timestamp': '2026-05-29T11:00:00',
            'has_intervention': true,
          },
        ],
        mostCommonEntry: 'Stress',
      ),
    ));
    await tester.pump();
    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('Anxiety'), findsOneWidget);
  });
}
