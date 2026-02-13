## Frontend Architecture (Flutter)

The Flutter app is responsible for collecting user input, showing real-time feedback about risk level, surfacing interventions, and visualizing historical data.

### File Layout

- `lib/main.dart`
  - Entry point (`main()`).
  - `LoopBreakerApp` widget that configures theming and sets the home screen.
- `lib/screens/journal_screen.dart`
  - `JournalScreen` and its state.
  - Handles text input, calls the backend to analyze entries, and shows interventions.
  - Displays granular status (`detected_node` + sublabel).
  - Intercepts high-risk loop events with a physiological needs check-in (HALT/needs modal) before the intervention dialog.
- `lib/screens/history_screen.dart`
  - `HistoryScreen` dashboard that shows stats, confidence trend chart, and recent logs.
  - Provides a “Reset Journey Data” action.
- `lib/widgets/breathing_circle.dart`
  - `BreathingCircle` widget that drives the guided breathing animation in the intervention dialog.
- `lib/services/api_client.dart` (optional but recommended)
  - Thin HTTP wrapper for backend calls (analyze, history, feedback, reset).

### Backend Interaction

- **Analyze state**
  - `JournalScreen` invokes `POST /analyze` with `{ "user_text": "<journal text>" }`.
  - Uses the response fields:
    - `detected_node`
    - `sublabel` (or `emotion_sublabel` fallback)
    - `risk_level`
    - `loop_detected`
    - `intervention_title`
    - `intervention_task`
  - Updates status card text in the format `Detected: <node> (<sublabel>)`.

- **High-risk physiological intercept**
  - If `loop_detected == true` and `risk_level == "High"`, frontend shows a pre-intervention needs checklist:
    - Hydration (Water)
    - Fuel (Food)
    - Rest (Sleep)
    - Movement (Zone 1-2)
  - After `Skip` or confirmation, frontend proceeds to the standard AI intervention dialog.

- **Insight card state indicator**
  - The top insight card renders a brain-state line based on current `risk_level`:
    - `High` → `State: Sympathetic Activation`
    - otherwise → `State: Parasympathetic Recovery`

- **Feedback on interventions**
  - When user taps a feedback button, frontend invokes `POST /feedback` with `{ "success": true|false }`.

- **History**
  - `HistoryScreen` calls `GET /history` to get a list of recent entries with:
    - `time`, `state`, `intervention`, `confidence`, `was_successful`.

- **Reset journey**
  - `HistoryScreen` calls `DELETE /reset` after confirmation, then refreshes its data.

