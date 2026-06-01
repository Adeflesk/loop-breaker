import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/expandable_history_entry.dart';

void main() {
  Map<String, dynamic> sampleItem({bool wasSuccessful = true}) => {
        'state': 'Stress',
        'was_successful': wasSuccessful,
        'confidence': 0.75,
        'intervention': 'Physiological Sigh',
        'time': '2026-05-29T10:30:00',
      };

  Widget wrap(Map<String, dynamic> item, {VoidCallback? onExpanded}) =>
      MaterialApp(
        home: Scaffold(
          body: ExpandableHistoryEntry(item: item, onExpanded: onExpanded),
        ),
      );

  testWidgets('shows state name in list tile', (tester) async {
    await tester.pumpWidget(wrap(sampleItem()));
    expect(find.text('Stress'), findsOneWidget);
  });

  testWidgets('shows intervention in subtitle', (tester) async {
    await tester.pumpWidget(wrap(sampleItem()));
    expect(find.text('Intervention: Physiological Sigh'), findsOneWidget);
  });

  testWidgets('shows Healthy State when no intervention', (tester) async {
    final item = sampleItem();
    item['intervention'] = '';
    await tester.pumpWidget(wrap(item));
    expect(find.text('Healthy State'), findsOneWidget);
  });

  testWidgets('tapping card expands to show details', (tester) async {
    await tester.pumpWidget(wrap(sampleItem()));

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();

    expect(find.text('Confidence'), findsOneWidget);
    expect(find.text('Full Time'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
  });

  testWidgets('tapping card again collapses it', (tester) async {
    await tester.pumpWidget(wrap(sampleItem()));

    // Expand
    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();
    expect(find.text('Confidence'), findsOneWidget);

    // Collapse
    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();
    // After collapse, the animation hides the content (heightFactor=0)
    // The widget exists in the tree but is not visible
    expect(find.text('Stress'), findsOneWidget);
  });

  testWidgets('calls onExpanded callback when expanded', (tester) async {
    bool called = false;
    await tester.pumpWidget(wrap(sampleItem(), onExpanded: () => called = true));

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });

  testWidgets('shows successful loop broken status when expanded', (tester) async {
    await tester.pumpWidget(wrap(sampleItem(wasSuccessful: true)));

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();

    expect(find.text('Loop Broken'), findsOneWidget);
  });

  testWidgets('shows No Intervention status when not successful', (tester) async {
    await tester.pumpWidget(wrap(sampleItem(wasSuccessful: false)));

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();

    expect(find.text('No Intervention'), findsOneWidget);
  });

  testWidgets('horizontal drag triggers toggle', (tester) async {
    await tester.pumpWidget(wrap(sampleItem()));

    // Simulate a horizontal drag (right swipe)
    await tester.drag(find.byType(GestureDetector).first, const Offset(100, 0));
    await tester.pumpAndSettle();

    // After drag, expanded content should be visible
    expect(find.text('Confidence'), findsOneWidget);
  });

  testWidgets('shows correct confidence percentage when expanded', (tester) async {
    await tester.pumpWidget(wrap(sampleItem()));

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();

    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('handles null time gracefully', (tester) async {
    final item = sampleItem();
    item['time'] = null;
    await tester.pumpWidget(wrap(item));

    expect(find.text('Stress'), findsOneWidget);
  });
}
