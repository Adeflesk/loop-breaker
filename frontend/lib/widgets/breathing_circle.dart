import 'package:flutter/material.dart';

class BreathingCircle extends StatefulWidget {
  const BreathingCircle({super.key});

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF5B9B96);
    const Color accentWarm = Color(0xFFD89E6F);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140 + (80 * _scaleAnimation.value),
              height: 140 + (80 * _scaleAnimation.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryTeal.withOpacity(0.08),
                border: Border.all(
                  color: primaryTeal.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryTeal.withOpacity(_opacityAnimation.value),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _scaleAnimation.value > 0.5 ? 'Inhale' : 'Exhale',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: primaryTeal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Follow the circle. Breathe naturally.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      },
    );
  }
}

