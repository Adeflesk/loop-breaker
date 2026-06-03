import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/journal_screen.dart';
import 'package:frontend/services/api_client.dart';

Map<String, dynamic> _analyzeResponse({
  String node = 'Shame',
  bool includeSteps = false,
  bool includeAlternatives = false,
}) {
  return {
    'detected_node': node,
    'sublabel': null,
    'emotion_sublabel': null,
    'confidence': 0.85,
    'reasoning': 'Test reasoning',
    'risk_level': 'medium',
    'loop_detected': false,
    'intervention_title': 'Mindful Self-Compassion',
    'intervention_task': 'Take a breath. Notice what you\'re feeling without judgment.',
    'education_info': 'Shame thrives in secrecy.',
    'intervention_type': 'cognitive',
    'msc_steps': includeSteps
        ? [
            {'step': 1, 'name': 'Mindfulness', 'task': 'Place a hand on your heart.', 'education': 'Mindfulness means noticing.'},
            {'step': 2, 'name': 'Common Humanity', 'task': 'Think of someone else.', 'education': 'Suffering is universal.'},
            {'step': 3, 'name': 'Self-Kindness', 'task': 'What would you say to a friend?', 'education': 'Self-kindness replaces judgment.'},
          ]
        : null,
    'alternatives': includeAlternatives
        ? [
            {'title': 'Cognitive Reframe', 'task': 'Notice and rewrite the thought.', 'education': 'Reframing reprograms the loop.', 'type': 'cognitive'},
            {'title': 'Zone 2 Walk', 'task': 'Walk for 5-10 minutes.', 'education': 'Zone 2 shifts your nervous system.', 'type': 'movement'},
          ]
        : null,
  };
}

void _setupMocks({required Map<String, dynamic> analyzeData}) {
  ApiClient.clientOverride = MockClient((request) async {
    if (request.url.path.endsWith('/insight')) {
      return http.Response(
        jsonEncode({'message': 'Welcome', 'weekly_activity': [], 'streak': 0}),
        200,
      );
    }
    if (request.url.path.endsWith('/history')) {
      return http.Response(jsonEncode([]), 200);
    }
    if (request.url.path.endsWith('/analyze')) {
      return http.Response(jsonEncode(analyzeData), 200);
    }
    if (request.url.path.endsWith('/feedback')) {
      return http.Response(jsonEncode({'status': 'ok'}), 200);
    }
    return http.Response('Not Found', 404);
  });
}

Future<void> _submitJournal(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'I feel so ashamed of myself right now');
  await tester.pumpAndSettle();

  await tester.tap(find.text('Analyze State'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  group('Show full guidance button', () {
    testWidgets('is absent when msc_steps is null', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: false));
      await _submitJournal(tester);

      expect(find.text('Show full guidance'), findsNothing);
    });

    testWidgets('is present when msc_steps is provided', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true));
      await _submitJournal(tester);

      expect(find.text('Show full guidance'), findsOneWidget);
    });

    testWidgets('tapping it reveals step 1 name and task', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true));
      await _submitJournal(tester);

      await tester.tap(find.text('Show full guidance'));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsOneWidget);
      expect(find.text('Place a hand on your heart.'), findsOneWidget);
    });

    testWidgets('tapping it again hides the steps', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true));
      await _submitJournal(tester);

      await tester.tap(find.text('Show full guidance'));
      await tester.pumpAndSettle();
      expect(find.text('Mindfulness'), findsOneWidget);

      await tester.tap(find.text('Hide guidance'));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsNothing);
    });

    testWidgets('all 3 step names visible when expanded', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true));
      await _submitJournal(tester);

      await tester.tap(find.text('Show full guidance'));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsOneWidget);
      expect(find.text('Common Humanity'), findsOneWidget);
      expect(find.text('Self-Kindness'), findsOneWidget);
    });
  });

  group("This isn't helping button", () {
    testWidgets('is always present on the dialog', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: false));
      await _submitJournal(tester);

      expect(find.text("This isn't helping"), findsOneWidget);
    });

    testWidgets('shows first alternative when tapped once', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: true));
      await _submitJournal(tester);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(find.text('Cognitive Reframe'), findsOneWidget);
      expect(find.text('Notice and rewrite the thought.'), findsOneWidget);
    });

    testWidgets('shows second alternative when tapped twice', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: true));
      await _submitJournal(tester);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(find.text('Zone 2 Walk'), findsOneWidget);
      expect(find.text('Walk for 5-10 minutes.'), findsOneWidget);
    });

    testWidgets('shows fallback message when all alternatives exhausted', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: true));
      await _submitJournal(tester);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(
        find.text("You've tried all the suggestions. Consider reaching out to someone you trust."),
        findsOneWidget,
      );
    });

    testWidgets('shows fallback immediately when no alternatives provided', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: false));
      await _submitJournal(tester);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(
        find.text("You've tried all the suggestions. Consider reaching out to someone you trust."),
        findsOneWidget,
      );
    });

    testWidgets('resets show-steps state when cycling to next alternative', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true, includeAlternatives: true));
      await _submitJournal(tester);

      await tester.tap(find.text('Show full guidance'));
      await tester.pumpAndSettle();
      expect(find.text('Mindfulness'), findsOneWidget);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsNothing);
    });
  });
}

// Diagnostic test - remove after debugging
void _diagnosticGroup() {
  group('Diagnostic', () {
    testWidgets('dialog appears with includeAlternatives true', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: true));
      await _submitJournal(tester);
      // Check if intervention title appears (any sign of dialog)
      expect(find.text('Mindful Self-Compassion'), findsOneWidget);
    });
  });
}
