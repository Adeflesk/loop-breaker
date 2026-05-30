import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/weekly_scorecard.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  testWidgets('shows all three stat labels', (tester) async {
    await tester.pumpWidget(wrap(
      const WeeklyScorecard(currentWeek: {}, previousWeek: {}),
    ));

    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Success Rate'), findsOneWidget);
    expect(find.text('Active Days'), findsOneWidget);
  });

  testWidgets('shows up arrow when current > previous', (tester) async {
    await tester.pumpWidget(wrap(
      const WeeklyScorecard(
        currentWeek: {'total_entries': 5, 'intervention_success_rate': 80.0, 'days_with_entries': 4},
        previousWeek: {'total_entries': 3, 'intervention_success_rate': 60.0, 'days_with_entries': 2},
      ),
    ));

    final upIcons = tester.widgetList<Icon>(find.byIcon(Icons.arrow_upward));
    expect(upIcons.length, greaterThanOrEqualTo(1));
    final greenIcons = upIcons.where((i) => i.color == Colors.green);
    expect(greenIcons, isNotEmpty);
  });

  testWidgets('shows down arrow when current < previous', (tester) async {
    await tester.pumpWidget(wrap(
      const WeeklyScorecard(
        currentWeek: {'total_entries': 2, 'intervention_success_rate': 40.0, 'days_with_entries': 1},
        previousWeek: {'total_entries': 5, 'intervention_success_rate': 80.0, 'days_with_entries': 4},
      ),
    ));

    final downIcons = tester.widgetList<Icon>(find.byIcon(Icons.arrow_downward));
    expect(downIcons.length, greaterThanOrEqualTo(1));
    final redIcons = downIcons.where((i) => i.color == Colors.red);
    expect(redIcons, isNotEmpty);
  });

  testWidgets('shows neutral arrow when values equal', (tester) async {
    await tester.pumpWidget(wrap(
      const WeeklyScorecard(
        currentWeek: {'total_entries': 3, 'intervention_success_rate': 50.0, 'days_with_entries': 3},
        previousWeek: {'total_entries': 3, 'intervention_success_rate': 50.0, 'days_with_entries': 3},
      ),
    ));

    final forwardIcons = tester.widgetList<Icon>(find.byIcon(Icons.arrow_forward));
    expect(forwardIcons.length, greaterThanOrEqualTo(1));
    final greyIcons = forwardIcons.where((i) => i.color == Colors.grey);
    expect(greyIcons, isNotEmpty);
  });

  testWidgets('formats success rate as percentage string', (tester) async {
    await tester.pumpWidget(wrap(
      const WeeklyScorecard(
        currentWeek: {'total_entries': 5, 'intervention_success_rate': 75.0, 'days_with_entries': 4},
        previousWeek: {},
      ),
    ));

    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('renders with empty maps without error', (tester) async {
    await tester.pumpWidget(wrap(
      const WeeklyScorecard(currentWeek: {}, previousWeek: {}),
    ));

    expect(find.text('0'), findsWidgets);
    expect(find.text('0%'), findsOneWidget);
  });
}
