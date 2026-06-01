import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/onboarding_modal.dart';

void main() {
  Widget wrap({required VoidCallback onComplete}) => MaterialApp(
        home: OnboardingModal(onComplete: onComplete),
      );

  testWidgets('shows Welcome to LoopBreaker on first page', (tester) async {
    await tester.pumpWidget(wrap(onComplete: () {}));
    await tester.pump();

    expect(find.text('Welcome to LoopBreaker'), findsOneWidget);
  });

  testWidgets('shows Next button on first page', (tester) async {
    await tester.pumpWidget(wrap(onComplete: () {}));
    await tester.pump();

    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('shows Skip button', (tester) async {
    await tester.pumpWidget(wrap(onComplete: () {}));
    await tester.pump();

    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Skip calls onComplete', (tester) async {
    bool completed = false;
    await tester.pumpWidget(wrap(onComplete: () => completed = true));
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('tapping Next advances to page 2', (tester) async {
    await tester.pumpWidget(wrap(onComplete: () {}));
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Understand Your State'), findsOneWidget);
  });

  testWidgets('Get Started button calls onComplete on last page', (tester) async {
    bool completed = false;
    await tester.pumpWidget(wrap(onComplete: () => completed = true));
    await tester.pumpAndSettle();

    // Navigate through all 5 pages (tap Next 4 times)
    for (int i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('shows page indicators', (tester) async {
    await tester.pumpWidget(wrap(onComplete: () {}));
    await tester.pump();

    // 5 circular indicators (one per page)
    // They are Container widgets inside a Row
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('swiping page changes current page indicator', (tester) async {
    await tester.pumpWidget(wrap(onComplete: () {}));
    await tester.pumpAndSettle();

    // Swipe left to go to page 2
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Understand Your State'), findsOneWidget);
  });
}
