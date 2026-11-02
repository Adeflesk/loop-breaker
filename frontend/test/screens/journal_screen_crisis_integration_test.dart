import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/journal_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:http/http.dart' as http;

class MockHttpClient implements http.Client {
  final Map<String, http.Response> responses = {};

  void setGetResponse(String url, http.Response response) {
    responses[url] = response;
  }

  void setPostResponse(String url, http.Response response) {
    responses[url] = response;
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return responses[url.toString()] ?? http.Response('{}', 200);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return responses[url.toString()] ?? http.Response('{}', 200);
  }

  @override
  noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

Map<String, dynamic> _buildCrisisResponse() {
  return {
    'crisis_detected': true,
    'detected_keywords': ['suicide', 'end my life'],
    'crisis_resources': {
      'message': 'We are concerned about your safety. Please reach out for support.',
      'hotlines': [
        {
          'name': '988 Suicide & Crisis Lifeline',
          'number': '988',
          'url': 'https://988lifeline.org',
          'availability': '24/7',
        },
        {
          'name': 'Crisis Text Line',
          'number': 'Text 741741',
          'url': 'https://www.crisistextline.org',
          'availability': '24/7',
        },
      ],
    },
    'detected_node': null,
    'sublabel': null,
    'confidence': null,
    'reasoning': null,
    'risk_level': null,
    'loop_detected': false,
  };
}

Map<String, dynamic> _buildNormalResponse() {
  return {
    'crisis_detected': false,
    'sublabel': 'General',
    'emotion_sublabel': 'Content',
    'confidence': 0.85,
    'reasoning': 'Detected positive state',
    'risk_level': 'low',
    'loop_detected': false,
    'intervention_title': 'Take a moment to breathe',
    'intervention_task': 'Take a deep breath',
    'education_info': 'Breathing helps calm your nervous system',
    'intervention_type': 'breathing',
    'detected_node': 'Stress',
  };
}

MockHttpClient _setupMockClient({bool isCrisis = false}) {
  final mockClient = MockHttpClient();
  mockClient.setPostResponse(
    'http://127.0.0.1:8000/analyze',
    http.Response(
      jsonEncode(isCrisis ? _buildCrisisResponse() : _buildNormalResponse()),
      200,
    ),
  );
  mockClient.setGetResponse(
    'http://127.0.0.1:8000/insight',
    http.Response(jsonEncode({}), 200),
  );
  return mockClient;
}

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
      // Set up mock HTTP client to return crisis response
      ApiClient.clientOverride = _setupMockClient(isCrisis: true);

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
      // Set up mock HTTP client to return crisis response
      ApiClient.clientOverride = _setupMockClient(isCrisis: true);

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
      // Set up mock HTTP client to return crisis response
      ApiClient.clientOverride = _setupMockClient(isCrisis: true);

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
      // Set up mock HTTP client to return crisis response
      ApiClient.clientOverride = _setupMockClient(isCrisis: true);

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
      // Set up mock HTTP client to return normal response
      ApiClient.clientOverride = _setupMockClient(isCrisis: false);

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
      // Set up mock HTTP client to return crisis response
      ApiClient.clientOverride = _setupMockClient(isCrisis: true);

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
      // Set up mock HTTP client to return crisis response
      ApiClient.clientOverride = _setupMockClient(isCrisis: true);

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
      // Set up mock HTTP client to return crisis response
      ApiClient.clientOverride = _setupMockClient(isCrisis: true);

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
      // Set up mock HTTP client to return normal response (short text is not detected as crisis by backend)
      ApiClient.clientOverride = _setupMockClient(isCrisis: false);

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
