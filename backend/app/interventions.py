INTERVENTIONS = {
    "Procrastination": {
        "Avoidance": {
            "title": "The 5-Minute Sprint",
            "task": "Pick the smallest sub-task and do it for exactly 5 minutes. You can stop after that.",
            "education": "Avoidance happens when a task feels threatening. The trick: make the barrier to entry so small your brain can't resist.",
            "type": "cognitive"
        },
        "Perfectionism": {
            "title": "Good Enough is Done",
            "task": "Set a 10-minute timer. Build the simplest possible version of what you're avoiding, then stop when the timer rings.",
            "education": "Perfectionism paralyzes because the standard is impossibly high. Done is better than perfect.",
            "type": "cognitive"
        },
        "Fear of Failure": {
            "title": "The Failure Frame",
            "task": "Write down: (1) What could go wrong? (2) How bad would it actually be? (3) Could you recover from it?",
            "education": "Fear of failure is often a catastrophic story. Reality-testing the worst case usually shows it's survivable.",
            "type": "cognitive"
        },
        None: {
            "title": "The 5-Minute Sprint",
            "task": "Pick the smallest sub-task and do it for exactly 5 minutes. You can stop after that.",
            "education": "Procrastination is often 'emotional regulation'—your brain is protecting you from a task that feels threatening or boring.",
            "type": "cognitive"
        }
    },
    "Anxiety": {
        "Hypervigilance": {
            "title": "Threat Assessment Protocol",
            "task": "Rate the actual threat level right now on a scale of 1-10. Then rate what your nervous system *thinks* the threat is. Usually they don't match.",
            "education": "Hypervigilance means your threat detector is stuck on 'high alert.' Fact-checking the threat resets the system.",
            "type": "cognitive"
        },
        "Panic": {
            "title": "5-4-3-2-1 Grounding",
            "task": "Name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, and 1 you can taste.",
            "education": "Panic floods you with false signals. Grounding forces your brain to switch from the 'threat network' to your senses.",
            "type": "grounding"
        },
        None: {
            "title": "5-4-3-2-1 Grounding",
            "task": "Name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, and 1 you can taste.",
            "education": "Grounding forces your brain to switch from the 'Default Mode Network' (worrying) to the 'Saliency Network' (physical reality).",
            "type": "grounding"
        }
    },
    "Stress": {
        "Burnout": {
            "title": "The Recovery Reset",
            "task": "For the next 10 minutes, do absolutely nothing productive. No phone, no planning—just rest.",
            "education": "Burnout is parasympathetic exhaustion. Your nervous system needs to downshift to recover, not push harder.",
            "type": "breathing"
        },
        None: {
            "title": "Physiological Sigh",
            "task": "Take a deep breath in, followed by a second short sharp inhale, then a long slow exhale.",
            "education": "This is the fastest biological way to offload carbon dioxide and lower your heart rate by activating the Vagus nerve.",
            "type": "breathing"
        }
    },
    "Shame": {
        "title": "Mindful Self-Compassion",
        "task": "Take a breath. Notice what you're feeling without judgment.",
        "education": "Shame thrives in secrecy. The MSC protocol — Mindfulness, Common Humanity, Self-Kindness — is the evidence-based antidote.",
        "type": "cognitive",
        "msc_steps": [
            {
                "step": 1,
                "name": "Mindfulness",
                "task": "Place a hand on your heart. Say: 'This is a moment of suffering. I notice this feeling without judgment.'",
                "education": "Mindfulness means acknowledging pain without over-identifying with it. It creates space between you and the feeling.",
            },
            {
                "step": 2,
                "name": "Common Humanity",
                "task": "Think of someone else who has felt exactly this way. Say: 'Suffering is part of being human. I am not alone in this.'",
                "education": "Shame says 'only I feel this.' Common humanity is the antidote — it reconnects you to the shared human experience.",
            },
            {
                "step": 3,
                "name": "Self-Kindness",
                "task": "Ask: 'What would I say to a dear friend who felt this way right now?' Say those exact words to yourself.",
                "education": "Self-kindness replaces harsh self-judgment with warmth. It doesn't mean self-pity — it means treating yourself as you'd treat someone you love.",
            },
        ],
    },
    "Overwhelm": {
        "Paralysis": {
            "title": "One Next Step",
            "task": "Don't look at the whole list. Pick ONE thing that takes 2 minutes or less. Do that. Then stop and reassess.",
            "education": "Paralysis happens when your brain sees the whole mountain and freezes. Single-step thinking unfreezes you.",
            "type": "cognitive"
        },
        None: {
            "title": "Brain Dump",
            "task": "Write down every single tiny thing on your mind for 2 minutes. Don't organize them, just dump them.",
            "education": "Overwhelm happens when working memory is full. Externalizing the list clears 'RAM' in your prefrontal cortex.",
            "type": "cognitive"
        }
    },
    "Numbness": {
        "title": "Temperature Shock",
        "task": "Hold an ice cube in your hand or splash very cold water on your face.",
        "education": "Numbness is a 'Freeze' response. Intense sensory input can help safely pull your nervous system back into the 'Window of Tolerance'.",
        "type": "grounding"
    },
    "Isolation": {
        "title": "The Low-Stakes Connection",
        "task": "Send a simple 'Thinking of you' or a meme to one person. No deep conversation required.",
        "education": "Isolation creates a feedback loop that says 'no one cares.' Small, low-friction interactions provide proof to the contrary.",
        "type": "other"
    }
}