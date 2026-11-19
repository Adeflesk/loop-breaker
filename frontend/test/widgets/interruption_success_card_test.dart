import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/interruption_success_card.dart';

void main() {
  test('computeMetrics handles empty list', () {
    final metrics = InterruptionSuccessCard.computeMetrics([]);
    expect(metrics['attempted'], 0);
    expect(metrics['broken'], 0);
    expect(metrics['successRate'], 0.0);
    expect(metrics['topIntervention'], isNull);
  });

  test('computeMetrics ignores non-intervention entries and finds top intervention', () {
    final metrics = InterruptionSuccessCard.computeMetrics([
      {'intervention': null, 'was_successful': null},
      {'intervention': 'Box Breathing', 'was_successful': true},
      {'intervention': 'Box Breathing', 'was_successful': false},
      {'intervention': '5-Min Walk', 'was_successful': true},
      {'intervention': '5-Min Walk', 'was_successful': true},
    ]);

    expect(metrics['attempted'], 4);
    expect(metrics['broken'], 3);
    expect(metrics['notHelped'], 1);
    expect(metrics['successRate'], 0.75);
    expect(metrics['topIntervention'], '5-Min Walk');
    expect(metrics['topWins'], 2);
    expect(metrics['topTotal'], 2);
  });

  test('computeMetrics distinguishes behavioural shifts from emotional relief', () {
    final metrics = InterruptionSuccessCard.computeMetrics([
      {'intervention': '5-Min Walk', 'was_successful': true, 'outcome_type': 'took_action'},
      {'intervention': '5-Min Walk', 'was_successful': true, 'outcome_type': 'interrupted_pattern'},
      {'intervention': 'Box Breathing', 'was_successful': true, 'outcome_type': 'felt_better'},
      {'intervention': 'Box Breathing', 'was_successful': false, 'outcome_type': 'no_change'},
      {'intervention': 'Box Breathing', 'was_successful': false, 'outcome_type': 'didnt_help'},
    ]);

    expect(metrics['attempted'], 5);
    expect(metrics['broken'], 3);
    expect(metrics['behaviouralShifts'], 2);
    expect(metrics['emotionalRelief'], 1);
    expect(metrics['notHelped'], 1);
  });

  testWidgets('renders percentage, counts, and most effective intervention', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InterruptionSuccessCard(
            historyEntries: [
              {'intervention': 'Box Breathing', 'was_successful': true},
              {'intervention': 'Box Breathing', 'was_successful': true},
              {'intervention': 'Journaling', 'was_successful': false},
            ],
          ),
        ),
      ),
    );

    expect(find.text('Interruption Success Rate'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.textContaining('2 broken of 3 attempted'), findsOneWidget);
    expect(find.text('Most effective: Box Breathing (2/2)'), findsOneWidget);
  });

  testWidgets('renders empty guidance when no interventions attempted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InterruptionSuccessCard(historyEntries: []),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
    expect(
      find.text('Try an intervention and rate whether it helped to track your interruption rate.'),
      findsOneWidget,
    );
  });
}
