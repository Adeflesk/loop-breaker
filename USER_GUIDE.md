# How to Use LoopBreaker

**LoopBreaker** is a personal behavioral loop-breaking app built around one idea: instead of simply tracking moods, it helps you **notice a repeating pattern in the moment, interrupt it with a targeted circuit breaker, and learn what actually works for you over time**.

The app is organized into four bottom tabs aligned with three core activities:

1. **Interrupt** (`Journal` tab) — Log what you're feeling right now and break an active loop.
2. **Understand** (`History` tab) — Review your interruption success rate, loop patterns, weekly trends, and past journal entries.
3. **Grow** (`Exercises` & `Learn` tabs) — Challenge unhelpful thoughts with CBT Thought Records, redesign environment friction, and learn the neuroscience behind each state.

---

## 1. Getting Started

### Opening & Unlocking the App
- **On your phone:** Open your deployed Cloud Run URL in Safari or Chrome and use **Add to Home Screen** to launch it like a native app.
- **Passcode Lock:** When `APP_PASSCODE` is configured on the server, you'll see the **LoopBreaker** lock screen (`Enter your private passcode to unlock your journal.`).
  - *Security note:* After 5 incorrect passcode attempts within 60 seconds, `/auth/verify` temporarily rate-limits further guesses (`HTTP 429`) for up to a minute.

### First-Time Setup (1 Minute)
From the **Journal** tab (`LoopBreaker` header):
1. **Values & Identity** (top-right medal icon): Add your core values and an identity statement. Once saved, LoopBreaker weaves values nudges into your AI Insight card and celebrates broken loops with your identity statement.
2. **Streak Goal** (tap the **Streak Bar**): Pick a daily streak target that feels realistic so you build consistency without burnout.

---

## 2. Tab 1 — `Journal` (Interrupting a Loop in the Moment)

Use this screen whenever you notice tension, procrastination, overwhelm, or a craving to avoid something.

### Step-by-Step Loop Interruption
1. **Check your top Insight & Streak cards (optional):**
   - **AI Insight** summarizes your current nervous-system state (*Sympathetic Activation* vs. *Parasympathetic Recovery*), overall trend, **Values Nudge**, **Peak Loop Window**, **Early Pre-Loop Signal**, and an **Audit Environment Friction** shortcut when relevant.
2. **Write what is happening:**
   - Type freely in **Describe your current state...** (even 1–2 honest sentences works) and tap **Analyze State**.
   - You'll see **Detected: \<State> (\<Sublabel>)**, a **Low / High Risk** badge, and the **AI Observation** explaining why.
3. **Crisis Safety Protection:**
   - If your entry contains acute crisis or self-harm language, LoopBreaker immediately opens the **Crisis Safety Dialog** with 24/7 crisis hotlines and emergency resources before anything else.
4. **Physiological Check-in (HALT) — High-Risk Loops Only:**
   - When a high-risk behavioral loop is detected, LoopBreaker asks you to check basic physical needs first: **Hydration (Water)**, **Fuel (Food)**, **Rest (Sleep)**, and **Movement (Zone 1-2)**.
   - Tap **I've Checked These** (or **Skip**) to move on to your intervention.
5. **Follow Your Circuit Breaker:**
   - The **Intervention Dialog** gives you a concrete task tailored to your state and sublabel (plus guided **Mindful Self-Compassion** steps for Shame, or interactive breathing where appropriate).
   - **Personal Loop Context & Effectiveness:** When you have prior entries, the dialog also shows where this state sits in your personal loop cycle and how well interventions have worked for you.
   - **Why this works (neuroscience):** Expand this section for a 3-depth explanation (`Introduce` → `Reinforce` → `Deepen` as you see an intervention more often).
6. **Tell LoopBreaker Whether It Worked:**
   - Tap **This isn't helping** to cycle through alternative approaches in the dialog.
   - Tap **I feel better** when the intervention helped break the loop, or **Didn't help** if it didn't.
   - *Why this matters:* LoopBreaker ranks interventions adaptively once interventions accumulate 3+ rated outcomes (`get_intervention_effectiveness`), automatically promoting what works best for you to the primary slot on future `/analyze` calls.

### Daily Tools on the `Journal` Tab
- **Daily Check-In (teal heart button, bottom right):** Log today's **Sleep hours**, **Hydration (1–5)**, **Food Quality (1–5)**, **Movement minutes**, and **Stress level (1–5)**. This powers missing-need insights and physiological correlations.
- **3-Minute Daily Practice (meditation icon, top right):** A proactive 3-step daily ritual that builds your **Practice Streak**, separate from reactive loop logging.

---

## 3. Tab 2 — `History` (Understanding Patterns & Effectiveness)

The **History** tab combines analytics and your journal log under two sub-tabs, with an **Export Journey** button (share icon, top right) to copy your progress bundle as JSON.

### `Dashboard` Sub-Tab
- **Summary Row:** Displays **Entries**, **Loops Broken**, and **Avg Focus**.
- **Interruption Success Rate Card:** Shows the percentage of attempted interventions that broke a loop (`broken / attempted`), counts of **broken** vs. **didn't help**, and your single **Most effective** intervention (e.g., `Most effective: Box Breathing (2/2)`).
- **Weekly Scorecard & Comparison:** Compares this week's activity and practice days against last week.
- **Weekly Pattern Narrative:** AI-generated coaching reflection highlighting recurring themes and what shifted this week.
- **Loop Path Chart:** Visualizes transitions between behavioral states over the last 30 days.
- **Expandable Recent Entries & Reset:** Tap entries to inspect details, or scroll down to **Reset Journey Data** (requires confirmation) if you ever want a clean slate.

### `My Journal` Sub-Tab
- Lists your saved journal entries chronologically with risk badges and raw text.
- Expand any entry to record or update an outcome later (**Helped**, **Neutral**, or **Didn't Help**) if you didn't rate it right away—helping feed both **Interruption Success Rate** and adaptive intervention ranking.

---

## 4. Tab 3 — `Exercises` (CBT Thought Records & Environment Audit)

Use **Exercises** when you want structured reflection after a triggering event rather than an acute in-the-moment reset.

### Creating a Thought Record (4-Step Wizard)
Tap to start a new **Thought Record** and work through the 4 steps:
1. **Step 1 — Situation:** What triggered the thought?
2. **Step 2 — Automatic Thought:** What anxious, self-critical, or avoidant thought popped up?
3. **Step 3 — Evidence:** List both **What supports this thought?** and **What challenges this thought?**
4. **Step 4 — Balanced Thought:** Synthesize a grounded, realistic alternative perspective (and optionally link it to a behavioral loop node).

### Environment Audit
Tap the **Environment Audit** icon in the top bar (or the **Audit Environment Friction** chip on your AI Insight card) to select a target loop (such as `Procrastination`), check off friction-adding steps, and save a custom environment rule that makes unwanted loops harder to start.

---

## 5. Tab 4 — `Learn` (Rewire Library)

Open **Learn** (`Rewire Library`) anytime you want to understand *why* a loop feels the way it does without being in the middle of one:
- **Rewire Your Loop — The 8-Node Cycle:** Tap the banner at the top for an interactive bottom-sheet walkthrough of how loops escalate across the 8 nodes.
- **7 State Education Cards:** Expand **Stress**, **Anxiety**, **Procrastination**, **Shame**, **Overwhelm**, **Restlessness**, or **Numbness**, each broken into three progressive layers:
  - *Getting Started* (what is happening in plain language)
  - *Going Deeper* (why the loop repeats)
  - *Advanced Neuroscience* (the underlying brain/nervous-system mechanism)

---

## 6. Recommended Weekly Rhythm

| Cadence | What to Do | Time |
| :--- | :--- | :--- |
| **Morning or Afternoon** | Tap the heart **Daily Check-In** button (or complete **3-Minute Daily Practice**). | ~1–3 min |
| **In the Moment** | Open `Journal` → describe what's happening → **Analyze State** → try the circuit breaker → tap **I feel better** or **Didn't help**. | ~2 min |
| **Evening (Optional)** | Review unrated items in `History` → `My Journal` and update outcomes; run a **Thought Record** in `Exercises` for sticky worries. | ~3–5 min |
| **Once a Week** | Open `History` → `Dashboard` to check your **Interruption Success Rate**, **Loop Path Chart**, and **Weekly Pattern Narrative**, then adjust your **Environment Audit** if one trigger keeps repeating. | ~5 min |
