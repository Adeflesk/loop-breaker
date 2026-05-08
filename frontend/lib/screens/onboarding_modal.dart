import 'package:flutter/material.dart';

class OnboardingModal extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingModal({required this.onComplete, super.key});

  @override
  State<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends State<OnboardingModal> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to LoopBreaker',
      subtitle: 'Break behavioral loops and rewire your patterns',
      icon: Icons.lightbulb_outline,
      description:
          'LoopBreaker helps you recognize and interrupt stress loops in real-time using proven behavioral science techniques.',
      color: const Color(0xFF5B9B96),
    ),
    OnboardingPage(
      title: 'Understand Your State',
      subtitle: 'AI recognizes your emotional patterns',
      icon: Icons.psychology,
      description:
          'Describe how you\'re feeling, and our AI analyzes your emotional state across the 8-node Rewire loop: from Stress to Shame and back.',
      color: const Color(0xFFD89E6F),
    ),
    OnboardingPage(
      title: 'Get Interventions',
      subtitle: 'Personalized circuit breakers for your state',
      icon: Icons.flash_on,
      description:
          'Receive targeted interventions based on your emotional state. Try breathing techniques, grounding exercises, or cognitive reframes.',
      color: const Color(0xFF8B7355),
    ),
    OnboardingPage(
      title: 'Track Your Progress',
      subtitle: 'See your resilience grow over time',
      icon: Icons.trending_up,
      description:
          'Your journey dashboard shows recovery trends, success rates, and breakthrough streaks. Celebrate your progress breaking loops.',
      color: const Color(0xFFC16B4B),
    ),
    OnboardingPage(
      title: 'Ready to Begin?',
      subtitle: 'Start journaling your emotional state',
      icon: Icons.edit_note,
      description:
          'The first step is awareness. Journal how you\'re feeling right now, and LoopBreaker will guide you toward recovery.',
      color: const Color(0xFF5B9B96),
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _skipOnboarding() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Skip button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton(
                onPressed: _skipOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          ),
          // Page view
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return OnboardingPageView(page: _pages[index]);
              },
            ),
          ),
          // Progress indicators
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentPage
                        ? const Color(0xFF5B9B96)
                        : Colors.grey[300],
                  ),
                ),
              ),
            ),
          ),
          // Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _nextPage,
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final String description;
  final Color color;
  final bool isLast;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.description,
    required this.color,
    this.isLast = false,
  });
}

class OnboardingPageView extends StatelessWidget {
  final OnboardingPage page;

  const OnboardingPageView({required this.page, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            page.color.withOpacity(0.05),
            page.color.withOpacity(0.02),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: page.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                page.icon,
                size: 50,
                color: page.color,
              ),
            ),
            const SizedBox(height: 32),
            // Title
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle
            Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: page.color,
              ),
            ),
            const SizedBox(height: 24),
            // Description
            Text(
              page.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
