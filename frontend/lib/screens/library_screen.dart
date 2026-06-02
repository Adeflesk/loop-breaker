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
