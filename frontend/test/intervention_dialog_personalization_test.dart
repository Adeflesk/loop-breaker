import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/journal_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  group('Intervention Dialog Personalization Tests', () {
    tearDown(() {
      ApiClient.clientOverride = null;
    });

    group('Loop Context Card', () {
      testWidgets('renders when personal_loop data is available with all fields',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'Work-related',
                'emotion_sublabel': 'Anxious',
                'confidence': 0.85,
                'reasoning': 'User mentioned work deadline pressure.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Breathing Exercise',
                'intervention_task': 'Take three deep breaths.',
                'intervention_type': 'breathing',
                'education_info': 'Deep breathing activates the parasympathetic nervous system.',
                'personal_loop': {
                  'most_common_entry': 'Stress',
                  'cycle_length_hours': 4.5,
                  'where_in_cycle': 'procrastination_phase',
                },
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'I feel stressed about my work');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Your Loop Pattern'), findsOneWidget);
        expect(find.text('Stress'), findsWidgets);
        expect(find.text('4.5 hours'), findsOneWidget);
        expect(find.text('procrastination_phase'), findsOneWidget);
      });

      testWidgets('does not render when personal_loop is null',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Anxiety',
                'sublabel': 'General',
                'emotion_sublabel': 'Worried',
                'confidence': 0.7,
                'reasoning': 'Mild anxiety detected.',
                'risk_level': 'low',
                'loop_detected': false,
                'intervention_title': 'Breathing Exercise',
                'intervention_task': 'Take three deep breaths.',
                'intervention_type': 'breathing',
                'education_info': 'Deep breathing helps calm the nervous system.',
                'personal_loop': null,
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'I feel anxious');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Your Loop Pattern'), findsNothing);
      });

      testWidgets('displays cycle length in correct format (X.X hours)',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'Work',
                'emotion_sublabel': 'Anxious',
                'confidence': 0.8,
                'reasoning': 'Work stress detected.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Breathing',
                'intervention_task': 'Breathe deeply.',
                'intervention_type': 'breathing',
                'education_info': 'Breathing activates parasympathetic system.',
                'personal_loop': {
                  'most_common_entry': 'Stress',
                  'cycle_length_hours': 2.75,
                  'where_in_cycle': null,
                },
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Stressed at work');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('2.8 hours'), findsOneWidget);
      });

      testWidgets('conditionally displays Position in Cycle when available',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'General',
                'emotion_sublabel': 'Stressed',
                'confidence': 0.7,
                'reasoning': 'General stress.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Breathing',
                'intervention_task': 'Breathe.',
                'intervention_type': 'breathing',
                'education_info': 'Breathe to calm.',
                'personal_loop': {
                  'most_common_entry': 'Stress',
                  'cycle_length_hours': 5.0,
                  'where_in_cycle': 'peak_arousal_phase',
                },
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Stressed');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Position in Cycle'), findsOneWidget);
        expect(find.text('peak_arousal_phase'), findsOneWidget);
      });
    });

    group('Effectiveness Track Record Card', () {
      testWidgets('renders when intervention_effectiveness data is available',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 50,
                'trend': 'improving',
                'streak': 2,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'Work',
                'emotion_sublabel': 'Anxious',
                'confidence': 0.8,
                'reasoning': 'Work stress.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Breathing',
                'intervention_task': 'Breathe deeply.',
                'intervention_type': 'breathing',
                'education_info': 'Breathing helps.',
                'personal_loop': null,
                'intervention_effectiveness': {
                  '5-Minute Sprint': {
                    'helped': 8,
                    'neutral': 1,
                    'didn_help': 1,
                    'total': 10,
                    'percentage': 80,
                  },
                  'Breathing': {
                    'helped': 2,
                    'neutral': 1,
                    'didn_help': 2,
                    'total': 5,
                    'percentage': 40,
                  },
                },
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Work stress');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Effectiveness Track Record'), findsOneWidget);
        expect(find.text('5-Minute Sprint'), findsOneWidget);
        expect(find.text('Breathing'), findsWidgets);  // Found in both title and effectiveness card
        expect(find.text('80%'), findsOneWidget);
        expect(find.text('40%'), findsOneWidget);
      });

      testWidgets('shows correct outcome breakdown format',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'General',
                'emotion_sublabel': 'Stressed',
                'confidence': 0.7,
                'reasoning': 'Stress.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Grounding',
                'intervention_task': 'Ground yourself.',
                'intervention_type': 'grounding',
                'education_info': 'Grounding technique.',
                'personal_loop': null,
                'intervention_effectiveness': {
                  '5-Minute Sprint': {
                    'helped': 8,
                    'neutral': 1,
                    'didn_help': 1,
                    'total': 10,
                    'percentage': 80,
                  },
                },
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Stressed');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data?.contains('8 helped') == true &&
                widget.data?.contains('1 neutral') == true &&
                widget.data?.contains("didn't help") == true &&
                widget.data?.contains('n=10') == true,
          ),
          findsOneWidget,
        );
      });

      testWidgets('percentage badge shows 80% when percentage is 80',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Anxiety',
                'sublabel': 'General',
                'emotion_sublabel': 'Anxious',
                'confidence': 0.75,
                'reasoning': 'Anxiety.',
                'risk_level': 'low',
                'loop_detected': false,
                'intervention_title': 'Breathing',
                'intervention_task': 'Breathe.',
                'intervention_type': 'breathing',
                'education_info': 'Breathing.',
                'personal_loop': null,
                'intervention_effectiveness': {
                  'Meditation': {
                    'helped': 9,
                    'neutral': 0,
                    'didn_help': 1,
                    'total': 10,
                    'percentage': 90,
                  },
                },
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Anxious');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('90%'), findsOneWidget);
      });

      testWidgets('progress bar renders for tracked interventions',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'General',
                'emotion_sublabel': 'Stressed',
                'confidence': 0.7,
                'reasoning': 'Stress.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Walking',
                'intervention_task': 'Walk.',
                'intervention_type': 'movement',
                'education_info': 'Walking.',
                'personal_loop': null,
                'intervention_effectiveness': {
                  'Walking': {
                    'helped': 7,
                    'neutral': 2,
                    'didn_help': 1,
                    'total': 10,
                    'percentage': 70,
                  },
                },
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Stressed');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(LinearProgressIndicator), findsWidgets);
      });

      testWidgets('does not render when intervention_effectiveness is null',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Calm',
                'sublabel': 'General',
                'emotion_sublabel': 'Peaceful',
                'confidence': 0.8,
                'reasoning': 'Calm state.',
                'risk_level': 'low',
                'loop_detected': false,
                'intervention_title': 'Meditation',
                'intervention_task': 'Meditate.',
                'intervention_type': 'reflection',
                'education_info': 'Meditation.',
                'personal_loop': null,
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Calm');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Effectiveness Track Record'), findsNothing);
      });

      testWidgets('does not render when intervention_effectiveness is empty',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Joy',
                'sublabel': 'General',
                'emotion_sublabel': 'Happy',
                'confidence': 0.9,
                'reasoning': 'Happy state.',
                'risk_level': 'low',
                'loop_detected': false,
                'intervention_title': 'Celebrate',
                'intervention_task': 'Celebrate.',
                'intervention_type': 'reflection',
                'education_info': 'Celebration.',
                'personal_loop': null,
                'intervention_effectiveness': {},
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Happy');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Effectiveness Track Record'), findsNothing);
      });
    });

    group('Education Text Tests', () {
      testWidgets('displays personalized education_info when available',
          (WidgetTester tester) async {
        const String educationText =
            'Deep breathing activates the parasympathetic nervous system, which signals your body that it is safe to relax.';

        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'General',
                'emotion_sublabel': 'Stressed',
                'confidence': 0.7,
                'reasoning': 'Stress detected.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Breathing',
                'intervention_task': 'Take three slow breaths.',
                'intervention_type': 'breathing',
                'education_info': educationText,
                'personal_loop': null,
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Stressed');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Why this works (neuroscience)'), findsOneWidget);

        // Expand the ExpansionTile to reveal the education_info text
        await tester.tap(find.text('Why this works (neuroscience)'));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text(educationText), findsOneWidget);
      });

      testWidgets('handles null education_info gracefully',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Neutral',
                'sublabel': 'General',
                'emotion_sublabel': 'Neutral',
                'confidence': 0.5,
                'reasoning': 'Neutral state.',
                'risk_level': 'low',
                'loop_detected': false,
                'intervention_title': 'Observe',
                'intervention_task': 'Just observe.',
                'intervention_type': 'reflection',
                'education_info': null,
                'personal_loop': null,
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Neutral');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Why this works (neuroscience)'), findsNothing);
      });
    });

    group('Data Parsing & Null Safety Tests', () {
      testWidgets('handles null personal_loop gracefully',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Anxiety',
                'sublabel': 'General',
                'emotion_sublabel': 'Anxious',
                'confidence': 0.6,
                'reasoning': 'Anxiety.',
                'risk_level': 'low',
                'loop_detected': false,
                'intervention_title': 'Grounding',
                'intervention_task': 'Ground yourself.',
                'intervention_type': 'grounding',
                'education_info': 'Grounding technique.',
                'personal_loop': null,
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Anxious');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets(
          'handles partial data - personal_loop available but no effectiveness',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'Work',
                'emotion_sublabel': 'Anxious',
                'confidence': 0.75,
                'reasoning': 'Work stress.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Breathing',
                'intervention_task': 'Breathe deeply.',
                'intervention_type': 'breathing',
                'education_info': 'Breathing activates parasympathetic system.',
                'personal_loop': {
                  'most_common_entry': 'Stress',
                  'cycle_length_hours': 3.5,
                  'where_in_cycle': null,
                },
                'intervention_effectiveness': null,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Work stress');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Your Loop Pattern'), findsOneWidget);
        expect(find.text('Effectiveness Track Record'), findsNothing);
      });

      testWidgets(
          'handles partial data - effectiveness available but no personal_loop',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 0,
                'trend': 'unknown',
                'streak': 0,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'General',
                'emotion_sublabel': 'Stressed',
                'confidence': 0.6,
                'reasoning': 'Stress.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Walking',
                'intervention_task': 'Take a walk.',
                'intervention_type': 'movement',
                'education_info': 'Walking helps.',
                'personal_loop': null,
                'intervention_effectiveness': {
                  'Walking': {
                    'helped': 7,
                    'neutral': 2,
                    'didn_help': 1,
                    'total': 10,
                    'percentage': 70,
                  },
                },
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Stressed');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Your Loop Pattern'), findsNothing);
        expect(find.text('Effectiveness Track Record'), findsOneWidget);
      });

      testWidgets(
          'handles both personal_loop and effectiveness data available',
          (WidgetTester tester) async {
        ApiClient.clientOverride = MockClient((request) async {
          if (request.url.path.endsWith('/insight')) {
            return http.Response(
              jsonEncode({
                'message': "Let's break some loops today.",
                'success_rate': 50,
                'trend': 'improving',
                'streak': 2,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/analyze')) {
            return http.Response(
              jsonEncode({
                'detected_node': 'Stress',
                'sublabel': 'Work',
                'emotion_sublabel': 'Anxious',
                'confidence': 0.8,
                'reasoning': 'Work pressure.',
                'risk_level': 'medium',
                'loop_detected': true,
                'intervention_title': 'Breathing',
                'intervention_task': 'Breathe deeply.',
                'intervention_type': 'breathing',
                'education_info': 'Breathing calms the nervous system.',
                'personal_loop': {
                  'most_common_entry': 'Stress',
                  'cycle_length_hours': 4.5,
                  'where_in_cycle': 'procrastination_phase',
                },
                'intervention_effectiveness': {
                  'Breathing': {
                    'helped': 6,
                    'neutral': 2,
                    'didn_help': 2,
                    'total': 10,
                    'percentage': 60,
                  },
                },
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: JournalScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(find.byType(TextField), 'Work stress');
        await tester.ensureVisible(find.text('Analyze State'));
        await tester.tap(find.text('Analyze State'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Your Loop Pattern'), findsOneWidget);
        expect(find.text('Effectiveness Track Record'), findsOneWidget);
      });
    });
  });
}
