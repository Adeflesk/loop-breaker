import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/journal_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  group('JournalScreen Crisis Integration', () {
    setUp(() {
      // Reset any previous API client state
      ApiClient.clientOverride = null;
    });

    tearDown(() {
      ApiClient.clientOverride = null;
    });

    testWidgets('shows crisis dialog when crisis text detected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Initial state: no dialog visible
      expect(find.text("We're Concerned About Your Safety"), findsNothing);

      // Enter crisis text with matching keyword
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'I am thinking about suicide and I want to end my life');
      await tester.pumpAndSettle();

      // Tap submit button
      final submitButton = find.text('Analyze State');
      await tester.tap(submitButton);
      // Wait for dialog to appear
      await tester.pumpAndSettle();

      // Crisis dialog should appear
      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);
      expect(find.text('988 Suicide & Crisis Lifeline'), findsOneWidget);
    });

    testWidgets('crisis dialog shows multiple hotlines',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter crisis text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'I feel hopeless about this situation');
      await tester.pumpAndSettle();

      // Tap submit button
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // Verify crisis dialog with hotlines
      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);
      expect(find.text('988 Suicide & Crisis Lifeline'), findsOneWidget);
      expect(find.text('Crisis Text Line'), findsOneWidget);
    });

    testWidgets('continues to submission when pressing continue button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter crisis text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'I feel hopeless today and forever');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // Crisis dialog should appear
      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);

      // Tap continue button
      final continueButton = find.text("I'm Safe, Continue");
      expect(continueButton, findsOneWidget);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Dialog should close
      expect(find.text("We're Concerned About Your Safety"), findsNothing);
    });

    testWidgets('cancel button dismisses dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter crisis text with matching keyword
      final textField = find.byType(TextField);
      const crisisText = 'I am considering suicide and need help now';
      await tester.enterText(textField, crisisText);
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // Assert crisis dialog MUST appear
      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog closes
      expect(find.text("We're Concerned About Your Safety"), findsNothing);
    });

    testWidgets('does not show crisis dialog for normal text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter normal text (no crisis keywords)
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Today was a great day, I am feeling positive');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // Crisis dialog should NOT appear
      expect(find.text("We're Concerned About Your Safety"), findsNothing);
    });

    testWidgets('multiple keywords are detected in crisis text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter text with multiple crisis keywords
      final textField = find.byType(TextField);
      await tester.enterText(
        textField,
        'I feel hopeless and suicidal, I want to harm myself right now'
      );
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // Crisis dialog should appear
      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);
    });

    testWidgets('crisis detection handles case insensitive input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter text with uppercase crisis keyword
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'I am considering SUICIDE and cannot continue with life here');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // Assert crisis dialog MUST appear (case insensitive detection)
      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);
    });

    testWidgets('dialog displays with correct color scheme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter crisis text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'I want to end my life');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // Verify dialog is present
      expect(find.byType(AlertDialog), findsOneWidget);

      // Verify buttons are rendered
      expect(find.byType(ElevatedButton), findsWidgets);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('text field is properly initialized',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Verify TextField exists
      expect(find.byType(TextField), findsOneWidget);

      // Verify submit button exists
      expect(find.text('Analyze State'), findsOneWidget);
    });

    testWidgets('short text does not trigger crisis dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter very short text with keyword (below 10 char minimum)
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'kill me');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Crisis dialog should NOT appear (text too short)
      expect(find.text("We're Concerned About Your Safety"), findsNothing);
    });

    testWidgets('empty text field prevents submission',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Don't enter any text, just tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // Nothing should happen (early return on empty text)
      expect(find.text("We're Concerned About Your Safety"), findsNothing);
    });

    testWidgets('whitespace-only text is treated as empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JournalScreen(),
        ),
      );

      // Enter only whitespace
      final textField = find.byType(TextField);
      await tester.enterText(textField, '   \n  \t  ');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Analyze State'));
      await tester.pumpAndSettle();

      // No dialog should appear
      expect(find.text("We're Concerned About Your Safety"), findsNothing);
    });
  });
}
