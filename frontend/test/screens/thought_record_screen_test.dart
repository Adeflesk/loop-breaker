import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/thought_record_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  /// Simple wrap for tests that don't navigate away on success.
  Widget wrap({String? prefilledNode}) => MaterialApp(
        home: ThoughtRecordScreen(prefilledNode: prefilledNode),
      );

  /// Wrap with a previous route so Navigator.pop works correctly and the
  /// root ScaffoldMessenger retains the snackbar after the screen is popped.
  Widget wrapWithNav({String? prefilledNode}) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ThoughtRecordScreen(prefilledNode: prefilledNode),
                ),
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      );

  /// ElevatedButton.icon renders as _ElevatedButtonWithIcon, a private subclass
  /// of ElevatedButton not matched by find.byType(ElevatedButton).
  Finder nextButtonFinder() => find.ancestor(
        of: find.text('Next'),
        matching: find.bySubtype<ElevatedButton>(),
      );

  Finder saveButtonFinder() => find.ancestor(
        of: find.text('Save Record'),
        matching: find.bySubtype<ElevatedButton>(),
      );

  /// Scroll the target button into view and tap it.
  Future<void> tapButton(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  /// Navigate through all 4 steps on a widget already pumped. Assumes the
  /// ThoughtRecordScreen is already visible.
  Future<void> navigateToLastStep(WidgetTester tester) async {
    // Step 0 → 1
    await tester.enterText(find.byType(TextField).first, 'My situation');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    // Step 1 → 2
    await tester.enterText(find.byType(TextField).first, 'My automatic thought');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    // Step 2 → 3
    await tester.enterText(find.byType(TextField).at(0), 'Evidence for it');
    await tester.enterText(find.byType(TextField).at(1), 'Evidence against it');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    // Now on step 3 (final step)
    await tester.enterText(find.byType(TextField).first, 'My balanced thought');
    await tester.pump();
  }

  testWidgets('shows Thought Record title in AppBar', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Thought Record'), findsOneWidget);
  });

  testWidgets('shows 4 step indicators on initial render', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('The Situation'), findsOneWidget);
    expect(find.text('Your Automatic Thought'), findsOneWidget);
    expect(find.text('Examining the Evidence'), findsOneWidget);
    expect(find.text('The Balanced Alternative'), findsOneWidget);
  });

  testWidgets('Next button is disabled when situation field is empty', (tester) async {
    await tester.pumpWidget(wrap());

    final nextButton = tester.widget<ElevatedButton>(nextButtonFinder());
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('Next button enables after typing situation', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byType(TextField).first, 'I had a stressful meeting');
    await tester.pump();

    final nextButton = tester.widget<ElevatedButton>(nextButtonFinder());
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets('tapping Next advances to step 2', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byType(TextField).first, 'Stressful meeting at work');
    await tester.pump();

    await tapButton(tester, nextButtonFinder());

    expect(find.text('What was the first thought or belief that came to mind?'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
  });

  testWidgets('Previous button goes back to step 1', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byType(TextField).first, 'A situation');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Previous'));
    await tester.pump();

    expect(find.text('What happened? Describe the situation that triggered this state.'), findsOneWidget);
  });

  testWidgets('step 3 shows two evidence text fields', (tester) async {
    await tester.pumpWidget(wrap());

    // Step 0 → 1
    await tester.enterText(find.byType(TextField).first, 'My situation');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    // Step 1 → 2
    await tester.enterText(find.byType(TextField).first, 'My automatic thought');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    expect(find.text('What supports this thought?'), findsOneWidget);
    expect(find.text('What challenges this thought?'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('Save Record button appears on step 4 (last step)', (tester) async {
    await tester.pumpWidget(wrap());

    // Step 0 → 1
    await tester.enterText(find.byType(TextField).first, 'My situation');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    // Step 1 → 2
    await tester.enterText(find.byType(TextField).first, 'My automatic thought');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    // Step 2 → 3
    await tester.enterText(find.byType(TextField).at(0), 'Evidence for');
    await tester.enterText(find.byType(TextField).at(1), 'Evidence against');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    expect(find.text('Save Record'), findsOneWidget);
  });

  testWidgets('successful submission shows success snackbar', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/thought-record')) {
        return http.Response(jsonEncode({'status': 'created'}), 201);
      }
      return http.Response('', 404);
    });

    // Use a navigator with a previous route so the snackbar persists after
    // Navigator.pop removes the ThoughtRecordScreen.
    await tester.pumpWidget(wrapWithNav());
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    await navigateToLastStep(tester);

    await tapButton(tester, saveButtonFinder());
    await tester.pumpAndSettle();

    expect(find.text('Thought record saved. Well done!'), findsOneWidget);
  });

  testWidgets('failed submission shows error snackbar', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/thought-record')) {
        return http.Response('Error', 500);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(wrap());

    // Step 0 → 1
    await tester.enterText(find.byType(TextField).first, 'Situation');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    // Step 1 → 2
    await tester.enterText(find.byType(TextField).first, 'Thought');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    // Step 2 → 3
    await tester.enterText(find.byType(TextField).at(0), 'For');
    await tester.enterText(find.byType(TextField).at(1), 'Against');
    await tester.pump();
    await tapButton(tester, nextButtonFinder());

    await tester.enterText(find.byType(TextField).first, 'Balanced');
    await tester.pump();

    await tapButton(tester, saveButtonFinder());
    await tester.pumpAndSettle();

    expect(find.text('Failed to save. Please try again.'), findsOneWidget);
  });

  testWidgets('prefilled node is accepted without error', (tester) async {
    await tester.pumpWidget(wrap(prefilledNode: 'Anxiety'));
    expect(find.text('Thought Record'), findsOneWidget);
  });
}
