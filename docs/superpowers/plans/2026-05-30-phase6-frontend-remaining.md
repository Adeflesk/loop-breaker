# Phase 6 Frontend Remaining Items — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 4 remaining Phase 6 frontend items (API client additions, weekly scorecard widget, rewire library screen, daily check-in dialog) as a TDD Flutter-only pass with >90% coverage.

**Architecture:** Pure Flutter changes to 6 files — no backend modifications. New API methods follow the existing `_withRetry`/`clientOverride` pattern. New screens/widgets are self-contained and registered into the existing HomeShell navigation. All test files use `MockClient` and `WidgetTester` consistent with existing tests.

**Tech Stack:** Flutter/Dart, `package:http/testing.dart` (MockClient), `package:flutter_test`, existing `ApiClient.clientOverride` injection point.

**Working directory:** `/Users/adriancorsini/Development/loop-breaker/frontend`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/services/api_client.dart` | Modify | Add `getWeeklySummary`, `getHistoryDateRange`, `createDailyCheck` |
| `lib/widgets/weekly_scorecard.dart` | Create | Stateless 3-tile trend widget |
| `lib/screens/library_screen.dart` | Create | 7-state expandable education screen |
| `lib/screens/history_screen.dart` | Modify | Add weekly comparison section + 2 helper methods |
| `lib/screens/journal_screen.dart` | Modify | Add FAB + `_showDailyCheckIn()` dialog |
| `lib/screens/home_shell.dart` | Modify | Add 5th `NavigationDestination` for LibraryScreen |
| `test/services/api_client_phase6_test.dart` | Create | Unit tests for 3 new API methods |
| `test/widgets/weekly_scorecard_test.dart` | Create | Widget tests for WeeklyScorecard |
| `test/screens/library_screen_test.dart` | Create | Widget tests for LibraryScreen |
| `test/screens/history_screen_phase6_test.dart` | Create | Widget tests for scorecard section |
| `test/screens/journal_screen_daily_checkin_test.dart` | Create | Widget tests for FAB + dialog |
| `test/screens/home_shell_test.dart` | Create | Widget tests for 5th tab |

---

## Task 1: API Client — Three New Methods

**Files:**
- Modify: `lib/services/api_client.dart`
- Create: `test/services/api_client_phase6_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/api_client_phase6_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  group('ApiClient.getWeeklySummary', () {
    test('returns parsed map on 200', () async {
      ApiClient.clientOverride = MockClient((request) async {
        expect(request.url.path, endsWith('/weekly-summary'));
        expect(request.url.queryParameters['week_start'], '2026-05-26');
        return http.Response(
          jsonEncode({
            'week_start': '2026-05-26',
            'total_entries': 5,
            'days_with_entries': 4,
            'avg_confidence': 0.72,
            'intervention_success_rate': 80.0,
            'top_states': {'Stress': 3},
          }),
          200,
        );
      });

      final result = await ApiClient.getWeeklySummary('2026-05-26');
      expect(result['total_entries'], 5);
      expect(result['days_with_entries'], 4);
      expect(result['intervention_success_rate'], 80.0);
    });

    test('returns empty map on network error', () async {
      ApiClient.clientOverride = MockClient((_) async {
        throw Exception('Network error');
      });

      final result = await ApiClient.getWeeklySummary('2026-05-26');
      expect(result, isEmpty);
    });

    test('returns empty map on non-200 status', () async {
      ApiClient.clientOverride = MockClient((_) async {
        return http.Response('Internal Server Error', 500);
      });

      final result = await ApiClient.getWeeklySummary('2026-05-26');
      expect(result, isEmpty);
    });
  });

  group('ApiClient.getHistoryDateRange', () {
    test('returns list on 200', () async {
      ApiClient.clientOverride = MockClient((request) async {
        expect(request.url.path, endsWith('/history'));
        expect(request.url.queryParameters['start_date'], '2026-05-01');
        expect(request.url.queryParameters['end_date'], '2026-05-31');
        expect(request.url.queryParameters['limit'], '500');
        return http.Response(
          jsonEncode([
            {'state': 'Stress', 'confidence': 0.5},
            {'state': 'Anxiety', 'confidence': 0.7},
          ]),
          200,
        );
      });

      final result = await ApiClient.getHistoryDateRange('2026-05-01', '2026-05-31');
      expect(result.length, 2);
      expect(result[0]['state'], 'Stress');
    });

    test('returns empty list on network error', () async {
      ApiClient.clientOverride = MockClient((_) async {
        throw Exception('Network error');
      });

      final result = await ApiClient.getHistoryDateRange('2026-05-01', '2026-05-31');
      expect(result, isEmpty);
    });

    test('returns empty list on non-200 status', () async {
      ApiClient.clientOverride = MockClient((_) async {
        return http.Response('Not Found', 404);
      });

      final result = await ApiClient.getHistoryDateRange('2026-05-01', '2026-05-31');
      expect(result, isEmpty);
    });
  });

  group('ApiClient.createDailyCheck', () {
    test('completes without throwing on 201', () async {
      ApiClient.clientOverride = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/daily-check'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sleep_hours'], 7.5);
        expect(body['hydration_rating'], 3);
        expect(body['food_quality'], 4);
        expect(body['movement_minutes'], 30);
        expect(body['stress_level'], 2);
        return http.Response(jsonEncode({'status': 'recorded'}), 201);
      });

      await expectLater(
        ApiClient.createDailyCheck({
          'sleep_hours': 7.5,
          'hydration_rating': 3,
          'food_quality': 4,
          'movement_minutes': 30,
          'stress_level': 2,
        }),
        completes,
      );
    });

    test('throws on non-201 response', () async {
      ApiClient.clientOverride = MockClient((_) async {
        return http.Response('Service Unavailable', 503);
      });

      await expectLater(
        ApiClient.createDailyCheck({
          'sleep_hours': 7.0,
          'hydration_rating': 3,
          'food_quality': 3,
          'movement_minutes': 20,
          'stress_level': 3,
        }),
        throwsException,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/services/api_client_phase6_test.dart
```

Expected: FAIL — `getWeeklySummary`, `getHistoryDateRange`, `createDailyCheck` not found.

- [ ] **Step 3: Add the three methods to `api_client.dart`**

Insert the following three methods at the end of the `ApiClient` class, before the final `}`, after `recordJournalOutcome`:

```dart
  static Future<Map<String, dynamic>> getWeeklySummary(String weekStart) async {
    try {
      return await _withRetry(
        () async {
          final response = await _httpClient.get(
            _uri('/weekly-summary?week_start=$weekStart'),
          );
          if (response.statusCode == 200) {
            return jsonDecode(response.body) as Map<String, dynamic>;
          }
          throw Exception('Weekly summary failed with status ${response.statusCode}');
        },
        timeoutSeconds: _defaultQuickTimeoutSeconds,
      );
    } catch (e) {
      debugPrint('Weekly summary fetch error: $e');
    }
    return {};
  }

  static Future<List<dynamic>> getHistoryDateRange(
    String start,
    String end,
  ) async {
    try {
      return await _withRetry(
        () async {
          final response = await _httpClient.get(
            _uri('/history?start_date=$start&end_date=$end&limit=500'),
          );
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is List) return decoded;
          }
          throw Exception('History date range failed with status ${response.statusCode}');
        },
        timeoutSeconds: _historyTimeoutSeconds,
      );
    } catch (e) {
      debugPrint('History date range fetch error: $e');
    }
    return [];
  }

  static Future<void> createDailyCheck(Map<String, dynamic> data) async {
    return _withRetry(() async {
      final response = await _httpClient.post(
        _uri('/daily-check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode != 201) {
        throw Exception('Daily check failed with status ${response.statusCode}');
      }
    });
  }
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/services/api_client_phase6_test.dart -v
```

Expected: All 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/services/api_client.dart frontend/test/services/api_client_phase6_test.dart
git commit -m "feat: add getWeeklySummary, getHistoryDateRange, createDailyCheck to ApiClient"
```

---

## Task 2: Weekly Scorecard Widget

**Files:**
- Create: `lib/widgets/weekly_scorecard.dart`
- Create: `test/widgets/weekly_scorecard_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/widgets/weekly_scorecard_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/weekly_scorecard.dart';

void main() {
  Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  testWidgets('shows all three stat labels', (tester) async {
    await tester.pumpWidget(_wrap(
      const WeeklyScorecard(currentWeek: {}, previousWeek: {}),
    ));

    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Success Rate'), findsOneWidget);
    expect(find.text('Active Days'), findsOneWidget);
  });

  testWidgets('shows up arrow when current > previous', (tester) async {
    await tester.pumpWidget(_wrap(
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
    await tester.pumpWidget(_wrap(
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
    await tester.pumpWidget(_wrap(
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
    await tester.pumpWidget(_wrap(
      const WeeklyScorecard(
        currentWeek: {'total_entries': 5, 'intervention_success_rate': 75.0, 'days_with_entries': 4},
        previousWeek: {},
      ),
    ));

    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('renders with empty maps without error', (tester) async {
    await tester.pumpWidget(_wrap(
      const WeeklyScorecard(currentWeek: {}, previousWeek: {}),
    ));

    expect(find.text('0'), findsWidgets);
    expect(find.text('0%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/widgets/weekly_scorecard_test.dart
```

Expected: FAIL — `weekly_scorecard.dart` not found.

- [ ] **Step 3: Create `lib/widgets/weekly_scorecard.dart`**

```dart
import 'package:flutter/material.dart';

class WeeklyScorecard extends StatelessWidget {
  final Map<String, dynamic> currentWeek;
  final Map<String, dynamic> previousWeek;

  const WeeklyScorecard({
    super.key,
    required this.currentWeek,
    required this.previousWeek,
  });

  Widget _statTile(String label, String field, {bool isPercent = false}) {
    final current = (currentWeek[field] as num?)?.toDouble() ?? 0.0;
    final previous = (previousWeek[field] as num?)?.toDouble() ?? 0.0;

    final IconData icon;
    final Color color;
    if (current > previous) {
      icon = Icons.arrow_upward;
      color = Colors.green;
    } else if (current < previous) {
      icon = Icons.arrow_downward;
      color = Colors.red;
    } else {
      icon = Icons.arrow_forward;
      color = Colors.grey;
    }

    final String display = isPercent
        ? '${current.toStringAsFixed(0)}%'
        : current.toInt().toString();

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            display,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B9B96),
            ),
          ),
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _statTile('Entries', 'total_entries'),
          _statTile('Success Rate', 'intervention_success_rate', isPercent: true),
          _statTile('Active Days', 'days_with_entries'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/widgets/weekly_scorecard_test.dart -v
```

Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/widgets/weekly_scorecard.dart frontend/test/widgets/weekly_scorecard_test.dart
git commit -m "feat: add WeeklyScorecard widget with trend arrows"
```

---

## Task 3: Library Screen (Rewire Education)

**Files:**
- Create: `lib/screens/library_screen.dart`
- Create: `test/screens/library_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/screens/library_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/library_screen.dart';

void main() {
  Widget _wrap() => const MaterialApp(home: LibraryScreen());

  testWidgets('shows all 7 emotional state tiles', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('Anxiety'), findsOneWidget);
    expect(find.text('Procrastination'), findsOneWidget);
    expect(find.text('Shame'), findsOneWidget);
    expect(find.text('Overwhelm'), findsOneWidget);
    expect(find.text('Restlessness'), findsOneWidget);
    expect(find.text('Numbness'), findsOneWidget);
  });

  testWidgets('collapsed tiles show "3 depth levels" subtitle', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('3 depth levels'), findsNWidgets(7));
  });

  testWidgets('expanding Stress tile reveals all three section labels', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();

    expect(find.text('Getting Started'), findsOneWidget);
    expect(find.text('Going Deeper'), findsOneWidget);
    expect(find.text('Advanced Understanding'), findsOneWidget);
  });

  testWidgets('expanding Anxiety tile reveals education sections', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Anxiety'));
    await tester.pumpAndSettle();

    expect(find.text('Getting Started'), findsOneWidget);
    expect(find.text('Going Deeper'), findsOneWidget);
    expect(find.text('Advanced Understanding'), findsOneWidget);
  });

  testWidgets('multiple tiles can be expanded simultaneously', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anxiety'));
    await tester.pumpAndSettle();

    expect(find.text('Getting Started'), findsNWidgets(2));
  });

  testWidgets('screen title is Rewire Library', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Rewire Library'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/library_screen_test.dart
```

Expected: FAIL — `library_screen.dart` not found.

- [ ] **Step 3: Create `lib/screens/library_screen.dart`**

```dart
import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  static const _tealColor = Color(0xFF5B9B96);
  static const _indigoColor = Color(0xFF7B8BC4);
  static const _purpleColor = Color(0xFF9B6B96);

  static const List<Map<String, dynamic>> _states = [
    {
      'name': 'Stress',
      'getting_started':
          "Stress triggers your sympathetic nervous system (fight-or-flight). A physiological sigh deactivates it—it's the fastest biological way to lower your heart rate.",
      'going_deeper':
          "Repeated stress keeps your nervous system in a heightened state. CO2 is the fastest biological reset signal. This breath technique targets elevated CO2 directly, signaling your brain that threat has passed.",
      'advanced':
          "Your vagus nerve controls parasympathetic activation. The extended exhale in a physiological sigh increases vagal tone—the strength of your parasympathetic response. Repeated practice rewires your baseline threshold for stress activation, making you less reactive overall.",
    },
    {
      'name': 'Anxiety',
      'getting_started':
          "Anxiety activates your threat network, disconnecting you from the present. Grounding brings you back to sensory reality.",
      'going_deeper':
          "Your nervous system lives in the past (trauma memories) or future (what-ifs). Sensory data is always in the present—it's the only truth your body knows.",
      'advanced':
          "The Default Mode Network processes abstract threat; the Saliency Network processes concrete sensory input. Grounding shifts dominance from DMN to Saliency, providing bottom-up evidence of safety. Repeated practice strengthens this neural pathway.",
    },
    {
      'name': 'Procrastination',
      'getting_started':
          "Procrastination is often 'emotional regulation'—your brain is protecting you from a task that feels threatening or boring. It's not laziness; it's your nervous system in freeze mode.",
      'going_deeper':
          "The procrastination loop reinforces itself: avoidance provides relief (short-term), which strengthens the avoidance response. Breaking the cycle requires shrinking the task until it feels safe.",
      'advanced':
          "Procrastination reflects an interoceptive accuracy problem—you can't trust your emotional prediction. The 5-minute window provides instant evidence that the task is safer than your brain predicted, recalibrating future threat assessments.",
    },
    {
      'name': 'Shame',
      'getting_started':
          "Shame thrives in secrecy and isolation. Shame says 'I am bad.' It's the most painful emotion because it attacks your identity, not just your behavior.",
      'going_deeper':
          "The Mindful Self-Compassion protocol—Mindfulness, Common Humanity, Self-Kindness—interrupts the shame spiral. Each component targets a different neural pathway of self-criticism.",
      'advanced':
          "Shame activates your dorsomedial prefrontal cortex (self-referential processing) and suppresses your insula (interoceptive awareness). MSC re-engages your insula (feeling), reconnecting you to your body as evidence that you're still human, still worthy.",
    },
    {
      'name': 'Overwhelm',
      'getting_started':
          "Overwhelm happens when working memory is full. Your brain is juggling too many things at once, and nothing gets attention.",
      'going_deeper':
          "Externalizing to paper frees up your working memory—you don't have to keep things in mind anymore. Your brain can finally think again.",
      'advanced':
          "Working memory (prefrontal cortex) has a 7±2 item capacity. Beyond that, your anterior cingulate (cognitive control) overheats. Writing bypasses working memory entirely, routing to long-term storage (hippocampus). This frees your DLPFC to actually plan.",
    },
    {
      'name': 'Restlessness',
      'getting_started':
          "Restlessness is trapped activation—your nervous system is revved up but has nowhere to go. Movement burns off excess sympathetic energy.",
      'going_deeper':
          "Restlessness escalates when unaddressed; your system gets more agitated. Vigorous movement gives your arousal a purpose, depleting the drive to fidget.",
      'advanced':
          "Restlessness reflects elevated norepinephrine (arousal). Intense aerobic exercise depletes catecholamine stores and triggers endorphin release, resetting your arousal set point. The physical exertion provides proof to your amygdala that the threat has been 'handled.'",
    },
    {
      'name': 'Numbness',
      'getting_started':
          "Numbness is a 'Freeze' response—your nervous system has shut down to protect you. You feel disconnected from your body and emotions.",
      'going_deeper':
          "Numbness keeps you safe from pain but also disconnects you from aliveness. Intense sensory input—like cold—can shock your system back into engagement.",
      'advanced':
          "Numbness reflects dorsal vagal shutdown (dissociation). The cold water activates your anterior insula (visceral sensation) and triggers a gasp reflex, forcing your vagus nerve to re-engage parasympathetic tone. You regain interoceptive awareness—you can feel again.",
    },
  ];

  Widget _educationSection(String label, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rewire Library')),
      body: ListView(
        children: _states.map((state) {
          return ExpansionTile(
            title: Text(
              state['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: const Text(
              '3 depth levels',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _educationSection('Getting Started', state['getting_started'] as String, _tealColor),
              _educationSection('Going Deeper', state['going_deeper'] as String, _indigoColor),
              _educationSection('Advanced Understanding', state['advanced'] as String, _purpleColor),
            ],
          );
        }).toList(),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/library_screen_test.dart -v
```

Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/screens/library_screen.dart frontend/test/screens/library_screen_test.dart
git commit -m "feat: add LibraryScreen with 7-state expandable education cards"
```

---

## Task 4: History Screen — Weekly Comparison Section

**Files:**
- Modify: `lib/screens/history_screen.dart`
- Create: `test/screens/history_screen_phase6_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/screens/history_screen_phase6_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/widgets/weekly_scorecard.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  Map<String, dynamic> _weeklyResponse(int entries) => {
        'week_start': '2026-05-26',
        'total_entries': entries,
        'days_with_entries': entries,
        'avg_confidence': 0.7,
        'intervention_success_rate': 70.0,
        'top_states': {},
      };

  http.Response _jsonResponse(Object body, [int code = 200]) =>
      http.Response(jsonEncode(body), code);

  testWidgets('shows "Weekly Comparison" label when weekly summary returns data',
      (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) {
        return _jsonResponse([
          {'state': 'Stress', 'was_successful': true, 'confidence': 0.6, 'intervention': 'X', 'time': '2026-05-29T10:00:00'},
        ]);
      }
      if (request.url.path.endsWith('/weekly-summary')) {
        return _jsonResponse(_weeklyResponse(3));
      }
      if (request.url.path.endsWith('/stats')) return _jsonResponse({'Stress': 1.0});
      if (request.url.path.contains('loop-path')) return _jsonResponse({'path': [], 'analysis': {}});
      if (request.url.path.endsWith('/insight')) return _jsonResponse({'message': 'Hi', 'weekly_activity': [], 'streak': 0});
      return _jsonResponse({}, 404);
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Comparison'), findsOneWidget);
  });

  testWidgets('shows WeeklyScorecard widget when data is available', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) {
        return _jsonResponse([
          {'state': 'Stress', 'was_successful': true, 'confidence': 0.6, 'intervention': 'X', 'time': '2026-05-29T10:00:00'},
        ]);
      }
      if (request.url.path.endsWith('/weekly-summary')) {
        return _jsonResponse(_weeklyResponse(5));
      }
      if (request.url.path.endsWith('/stats')) return _jsonResponse({'Stress': 1.0});
      if (request.url.path.contains('loop-path')) return _jsonResponse({'path': [], 'analysis': {}});
      if (request.url.path.endsWith('/insight')) return _jsonResponse({'message': 'Hi', 'weekly_activity': [], 'streak': 0});
      return _jsonResponse({}, 404);
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(WeeklyScorecard), findsAtLeastNWidgets(1));
  });

  testWidgets('does not show Weekly Comparison when summary returns empty',
      (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/history')) {
        return _jsonResponse([
          {'state': 'Stress', 'was_successful': true, 'confidence': 0.6, 'intervention': 'X', 'time': '2026-05-29T10:00:00'},
        ]);
      }
      if (request.url.path.endsWith('/weekly-summary')) return _jsonResponse({});
      if (request.url.path.endsWith('/stats')) return _jsonResponse({'Stress': 1.0});
      if (request.url.path.contains('loop-path')) return _jsonResponse({'path': [], 'analysis': {}});
      if (request.url.path.endsWith('/insight')) return _jsonResponse({'message': 'Hi', 'weekly_activity': [], 'streak': 0});
      return _jsonResponse({}, 404);
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Comparison'), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/history_screen_phase6_test.dart
```

Expected: FAIL — `Weekly Comparison` text not found, no `WeeklyScorecard`.

- [ ] **Step 3: Modify `lib/screens/history_screen.dart`**

Add the following imports at the top of the file (after existing imports):

```dart
import '../widgets/weekly_scorecard.dart';
```

Add the two helper methods to `_HistoryScreenState` (insert before `_buildStatCard`):

```dart
  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _fetchCurrentWeekSummary() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = _formatDate(DateTime(monday.year, monday.month, monday.day));
    return ApiClient.getWeeklySummary(weekStart);
  }

  Future<Map<String, dynamic>> _fetchPreviousWeekSummary() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final prevMonday = monday.subtract(const Duration(days: 7));
    final weekStart = _formatDate(DateTime(prevMonday.year, prevMonday.month, prevMonday.day));
    return ApiClient.getWeeklySummary(weekStart);
  }
```

In the `build` method's `SingleChildScrollView > Column > children` list, insert the following block immediately after the existing `// Weekly Scorecard` `FutureBuilder` section (after the closing `),` of that FutureBuilder, before the `Padding` for `'Emotional Composition'`):

```dart
              // Weekly Comparison
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Future.wait([
                  _fetchCurrentWeekSummary(),
                  _fetchPreviousWeekSummary(),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final current = snapshot.data![0];
                  final previous = snapshot.data![1];
                  if (current.isEmpty && previous.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Comparison',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        WeeklyScorecard(
                          currentWeek: current,
                          previousWeek: previous,
                        ),
                      ],
                    ),
                  );
                },
              ),
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/history_screen_phase6_test.dart -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/screens/history_screen.dart frontend/test/screens/history_screen_phase6_test.dart
git commit -m "feat: add weekly comparison scorecard section to HistoryScreen"
```

---

## Task 5: Journal Screen — Daily Check-In FAB

**Files:**
- Modify: `lib/screens/journal_screen.dart`
- Create: `test/screens/journal_screen_daily_checkin_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/screens/journal_screen_daily_checkin_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/journal_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  Widget _wrap() => const MaterialApp(home: JournalScreen());

  void _setupDefaultMocks({int dailyCheckStatus = 201}) {
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
      if (request.url.path.endsWith('/daily-check')) {
        return http.Response(jsonEncode({'status': 'recorded'}), dailyCheckStatus);
      }
      return http.Response('Not Found', 404);
    });
  }

  testWidgets('shows Daily Check-In FAB with heart icon', (tester) async {
    _setupDefaultMocks();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('FAB has tooltip "Daily Check-In"', (tester) async {
    _setupDefaultMocks();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    expect(fab.tooltip, 'Daily Check-In');
  });

  testWidgets('tapping FAB opens daily check-in dialog', (tester) async {
    _setupDefaultMocks();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Daily Check-In'), findsAtLeastNWidgets(1));
  });

  testWidgets('dialog shows all 5 input labels', (tester) async {
    _setupDefaultMocks();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Sleep (hours)'), findsOneWidget);
    expect(find.text('Hydration'), findsOneWidget);
    expect(find.text('Food Quality'), findsOneWidget);
    expect(find.text('Movement (minutes)'), findsOneWidget);
    expect(find.text('Stress Level'), findsOneWidget);
  });

  testWidgets('dialog shows Skip and Save Check-In buttons', (tester) async {
    _setupDefaultMocks();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Save Check-In'), findsOneWidget);
  });

  testWidgets('Skip button dismisses dialog without API call', (tester) async {
    bool apiCalled = false;
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/insight')) {
        return http.Response(jsonEncode({'message': 'Hi', 'weekly_activity': [], 'streak': 0}), 200);
      }
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path.endsWith('/daily-check')) {
        apiCalled = true;
        return http.Response(jsonEncode({'status': 'recorded'}), 201);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Check-In'), findsNothing);
    expect(apiCalled, isFalse);
  });

  testWidgets('Save Check-In calls API and shows success snackbar on 201',
      (tester) async {
    _setupDefaultMocks(dailyCheckStatus: 201);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Check-In'));
    await tester.pumpAndSettle();

    expect(find.text('Check-in saved!'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/journal_screen_daily_checkin_test.dart
```

Expected: FAIL — no FAB, no daily check-in dialog.

- [ ] **Step 3: Add FAB and `_showDailyCheckIn` to `lib/screens/journal_screen.dart`**

In the `build` method of `_JournalScreenState`, find the `return Scaffold(` line and add `floatingActionButton:` between `appBar:` and `body:`:

```dart
      floatingActionButton: FloatingActionButton(
        onPressed: _showDailyCheckIn,
        tooltip: 'Daily Check-In',
        backgroundColor: const Color(0xFF5B9B96),
        foregroundColor: Colors.white,
        child: const Icon(Icons.favorite),
      ),
```

Add the `_showDailyCheckIn` method to `_JournalScreenState` (insert before `_showGoalPicker`):

```dart
  Future<void> _showDailyCheckIn() async {
    double sleepHours = 7.0;
    int hydration = 3;
    int foodQuality = 3;
    double movementMinutes = 30.0;
    int stressLevel = 3;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget _ratingButtons(
              int value,
              ValueChanged<int> onChanged, {
              bool isStress = false,
            }) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final selected = (i + 1) == value;
                  final color = isStress ? Colors.red : const Color(0xFF5B9B96);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => onChanged(i + 1),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? color : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Daily Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sleep (hours)', style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: sleepHours,
                      min: 0,
                      max: 12,
                      divisions: 24,
                      label: sleepHours.toStringAsFixed(1),
                      onChanged: (v) => setDialogState(() => sleepHours = v),
                    ),
                    const SizedBox(height: 12),
                    const Text('Hydration', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _ratingButtons(hydration, (v) => setDialogState(() => hydration = v)),
                    const SizedBox(height: 12),
                    const Text('Food Quality', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _ratingButtons(foodQuality, (v) => setDialogState(() => foodQuality = v)),
                    const SizedBox(height: 12),
                    const Text('Movement (minutes)', style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: movementMinutes,
                      min: 0,
                      max: 180,
                      divisions: 18,
                      label: movementMinutes.toInt().toString(),
                      onChanged: (v) => setDialogState(() => movementMinutes = v),
                    ),
                    const SizedBox(height: 12),
                    const Text('Stress Level', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _ratingButtons(
                      stressLevel,
                      (v) => setDialogState(() => stressLevel = v),
                      isStress: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await ApiClient.createDailyCheck({
                        'sleep_hours': sleepHours,
                        'hydration_rating': hydration,
                        'food_quality': foodQuality,
                        'movement_minutes': movementMinutes.toInt(),
                        'stress_level': stressLevel,
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Check-in saved!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to save check-in. Please try again.')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B9B96),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Check-In'),
                ),
              ],
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/journal_screen_daily_checkin_test.dart -v
```

Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/screens/journal_screen.dart frontend/test/screens/journal_screen_daily_checkin_test.dart
git commit -m "feat: add daily check-in FAB and dialog to JournalScreen"
```

---

## Task 6: HomeShell — 5th Navigation Tab + Final Coverage Gate

**Files:**
- Modify: `lib/screens/home_shell.dart`
- Create: `test/screens/home_shell_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/screens/home_shell_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/home_shell.dart';
import 'package:frontend/screens/library_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  void _setupMocks() {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/insight')) {
        return http.Response(jsonEncode({'message': 'Hi', 'weekly_activity': [], 'streak': 0}), 200);
      }
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path.endsWith('/weekly-summary')) {
        return http.Response(jsonEncode({}), 200);
      }
      if (request.url.path.endsWith('/stats')) {
        return http.Response(jsonEncode({}), 200);
      }
      if (request.url.path.contains('loop-path')) {
        return http.Response(jsonEncode({'path': [], 'analysis': {}}), 200);
      }
      return http.Response('', 404);
    });
  }

  testWidgets('HomeShell has exactly 5 NavigationDestination items', (tester) async {
    _setupMocks();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });

  testWidgets('5th tab is labelled Learn', (tester) async {
    _setupMocks();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    expect(find.text('Learn'), findsOneWidget);
  });

  testWidgets('tapping Learn tab shows LibraryScreen', (tester) async {
    _setupMocks();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Rewire Library'), findsOneWidget);
  });

  testWidgets('Learn tab has menu_book icon', (tester) async {
    _setupMocks();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/home_shell_test.dart
```

Expected: FAIL — only 4 `NavigationDestination` items found, no 'Learn' text.

- [ ] **Step 3: Modify `lib/screens/home_shell.dart`**

Replace the entire file content with:

```dart
import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'journal_history_screen.dart';
import 'journal_screen.dart';
import 'library_screen.dart';
import 'thought_records_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const JournalScreen(),
    const HistoryScreen(),
    const ThoughtRecordsTab(),
    const JournalHistoryScreen(),
    const LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Exercises',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'My Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Learn',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/home_shell_test.dart -v
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Run full test suite and check coverage**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test --coverage
```

Then check coverage percentage with:

```bash
awk '/^DA:/{split($0,a,":");split(a[2],b,",");if(b[1]>0){total++;if(b[2]>0)hit++}} END{printf "Line coverage: %.1f%% (%d/%d lines)\n",hit/total*100,hit,total}' coverage/lcov.info
```

Expected: All tests pass, coverage ≥ 90%.

If coverage is below 90%, identify uncovered lines:
```bash
grep -A1 "^SF:" coverage/lcov.info | grep "^SF:" | sed 's/SF://' | while read f; do
  covered=$(grep -A999 "^SF:$f" coverage/lcov.info | grep "^DA:" | awk -F',' '$2>0{c++} END{print c+0}')
  total=$(grep -A999 "^SF:$f" coverage/lcov.info | grep "^DA:" | awk 'END{print NR}')
  if [ "$total" -gt "0" ]; then
    pct=$(echo "scale=0; $covered*100/$total" | bc)
    if [ "$pct" -lt "90" ]; then
      echo "$f: ${pct}% ($covered/$total)"
    fi
  fi
done
```

Add targeted tests for any file below 90% before proceeding.

- [ ] **Step 6: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/screens/home_shell.dart frontend/test/screens/home_shell_test.dart
git commit -m "feat: add Learn (LibraryScreen) as 5th nav tab in HomeShell"
```

---

## Self-Review Checklist

Checking this plan against the spec:

- [x] `getWeeklySummary(String weekStart)` — Task 1 ✓
- [x] `getHistoryDateRange(String start, String end)` — Task 1 ✓
- [x] `createDailyCheck(Map<String,dynamic> data)` — Task 1 ✓
- [x] `getWeeklySummary`/`getHistoryDateRange` swallow errors — Task 1 implementation ✓
- [x] `createDailyCheck` throws on non-201 — Task 1 implementation ✓
- [x] `WeeklyScorecard` stateless widget with 3 tiles + trend arrows — Task 2 ✓
- [x] Trend: ↑ green / ↓ red / → grey — Task 2 ✓
- [x] `_fetchCurrentWeekSummary` and `_fetchPreviousWeekSummary` helpers — Task 4 ✓
- [x] Inserted below existing `_buildWeeklyScorecard` — Task 4 ✓
- [x] `"Weekly Comparison"` label — Task 4 ✓
- [x] `LibraryScreen` with 7 states, `ExpansionTile` — Task 3 ✓
- [x] 3 education levels with correct labels and colours — Task 3 ✓
- [x] Education content hardcoded from `interventions.py` — Task 3 ✓
- [x] All 7 states: Stress, Anxiety, Procrastination, Shame, Overwhelm, Restlessness, Numbness — Task 3 ✓
- [x] HomeShell 5th tab `'Learn'`, `Icons.menu_book_outlined` — Task 6 ✓
- [x] `FloatingActionButton` with `Icons.favorite`, teal, tooltip `'Daily Check-In'` — Task 5 ✓
- [x] Dialog: Sleep slider 0–12h/0.5h, Hydration 1–5, Food 1–5, Movement 0–180m/10m, Stress 1–5 — Task 5 ✓
- [x] Skip dismisses, Save calls API, snackbars — Task 5 ✓
- [x] `StatefulBuilder` manages dialog state — Task 5 ✓
- [x] `getHistoryDateRange` available for future use (not integrated into History list) — not needed (spec says deferred) ✓

**Note on coverage:** Flutter widget tests are called a "stretch goal" in the spec, but the user requires >90% coverage. Task 6 Step 5 includes the full coverage gate check and instructions for adding tests if any file is below threshold.

**Note on parallelism:** This is a purely frontend implementation — no backend tasks. Only one git worktree is needed. If the orchestrator wants to use `superpowers:subagent-driven-development`, each task runs as a fresh subagent sequentially (tasks have data dependencies: Task 4 imports Task 2's widget; Task 6 imports Task 3's screen).
