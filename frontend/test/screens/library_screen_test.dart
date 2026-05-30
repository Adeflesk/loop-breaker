import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/library_screen.dart';

void main() {
  Widget wrap() => const MaterialApp(home: LibraryScreen());

  testWidgets('shows all 7 emotional state tiles', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('Anxiety'), findsOneWidget);
    expect(find.text('Procrastination'), findsOneWidget);
    expect(find.text('Shame'), findsOneWidget);
    expect(find.text('Overwhelm'), findsOneWidget);
    expect(find.text('Restlessness'), findsOneWidget);
    expect(find.text('Numbness'), findsOneWidget);
  });

  testWidgets('collapsed tiles show "3 depth levels" subtitle', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('3 depth levels'), findsNWidgets(7));
  });

  testWidgets('expanding Stress tile reveals all three section labels', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();

    expect(find.text('Getting Started'), findsOneWidget);
    expect(find.text('Going Deeper'), findsOneWidget);
    expect(find.text('Advanced Understanding'), findsOneWidget);
  });

  testWidgets('expanding Anxiety tile reveals education sections', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Anxiety'));
    await tester.pumpAndSettle();

    expect(find.text('Getting Started'), findsOneWidget);
    expect(find.text('Going Deeper'), findsOneWidget);
    expect(find.text('Advanced Understanding'), findsOneWidget);
  });

  testWidgets('multiple tiles can be expanded simultaneously', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anxiety'));
    await tester.pumpAndSettle();

    expect(find.text('Getting Started'), findsNWidgets(2));
  });

  testWidgets('screen title is Rewire Library', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Rewire Library'), findsOneWidget);
  });
}
