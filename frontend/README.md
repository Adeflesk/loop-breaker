# LoopBreaker — Flutter Frontend

Flutter application for the LoopBreaker behavioral engineering platform.

## Requirements

- Flutter 3.44+ (stable channel)
- Dart SDK (included with Flutter)
- A running LoopBreaker backend at `http://127.0.0.1:8000` (see `../backend/`)

## Setup

```bash
flutter pub get
flutter run
```

To point at a different backend:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.x:8000
```

## Project Structure

```
lib/
├── main.dart                  # App entry point and routing
├── config.dart                # Backend URL configuration
├── screens/
│   ├── home_shell.dart        # Bottom nav shell (5 tabs)
│   ├── journal_screen.dart    # Journal entry + intervention dialog
│   ├── history_screen.dart    # Entry history + weekly scorecard
│   ├── library_screen.dart    # 7-state expandable education
│   └── journal_history_screen.dart
├── widgets/
│   ├── breathing_circle.dart
│   ├── crisis_safety_dialog.dart
│   ├── expandable_history_entry.dart
│   ├── loop_path_chart.dart
│   ├── personalization_cards.dart
│   ├── risk_level_badge.dart
│   ├── streak_bar.dart
│   └── weekly_scorecard.dart
├── services/
│   ├── api_client.dart        # HTTP client (retry, cache, timeout)
│   ├── crisis_safety_service.dart
│   └── goal_service.dart
└── models/                    # Dart data classes
```

## Running Tests

```bash
flutter test
```

All tests use `MockClient` from `package:http/testing.dart` — no live backend required.

## Key Screens

**Journal screen** — Journal entry submission, intervention dialog with:
- "Show full guidance" step toggle (MSC 3-step protocol for Shame)
- "This isn't helping" alternative cycling (up to 2 alternatives from backend)
- Crisis dialog for safety-flagged entries

**History screen** — Entry list with expandable cards, weekly scorecard trend widget

**Library screen** — Expandable education cards for all 7 emotional states

**Daily check-in** — FAB-triggered physiological check-in (sleep, hydration, food, movement, stress)
