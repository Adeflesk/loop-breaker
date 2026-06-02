import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/risk_level_badge.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  testWidgets('shows High Risk label for high level', (tester) async {
    await tester.pumpWidget(wrap(
      const RiskLevelBadge(riskLevel: 'High'),
    ));
    expect(find.text('High Risk'), findsOneWidget);
  });

  testWidgets('shows Medium Risk label for medium level', (tester) async {
    await tester.pumpWidget(wrap(
      const RiskLevelBadge(riskLevel: 'Medium'),
    ));
    expect(find.text('Medium Risk'), findsOneWidget);
  });

  testWidgets('shows Low Risk label for low level', (tester) async {
    await tester.pumpWidget(wrap(
      const RiskLevelBadge(riskLevel: 'Low'),
    ));
    expect(find.text('Low Risk'), findsOneWidget);
  });

  testWidgets('compact mode shows short label', (tester) async {
    await tester.pumpWidget(wrap(
      const RiskLevelBadge(riskLevel: 'High', compact: true),
    ));
    expect(find.text('High Risk'), findsOneWidget);
  });

  testWidgets('tapping badge toggles explanation text', (tester) async {
    await tester.pumpWidget(wrap(
      const RiskLevelBadge(riskLevel: 'High'),
    ));

    expect(find.text('High Risk'), findsOneWidget);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    // High explanation contains 'Priority'
    expect(find.textContaining('Priority'), findsOneWidget);
  });

  testWidgets('tapping explanation toggles back to badge', (tester) async {
    await tester.pumpWidget(wrap(
      const RiskLevelBadge(riskLevel: 'Medium'),
    ));

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    // Medium explanation contains 'Mild stress'
    expect(find.textContaining('Mild stress'), findsOneWidget);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    expect(find.text('Medium Risk'), findsOneWidget);
  });

  testWidgets('Low level shows stable state explanation', (tester) async {
    await tester.pumpWidget(wrap(
      const RiskLevelBadge(riskLevel: 'Low'),
    ));

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('stable'), findsOneWidget);
  });

  testWidgets('showLabel false shows riskLevel without Risk suffix', (tester) async {
    await tester.pumpWidget(wrap(
      const RiskLevelBadge(riskLevel: 'High', showLabel: false),
    ));
    expect(find.text('High'), findsOneWidget);
  });
}
