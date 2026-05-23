import 'package:flutter/material.dart';

class RiskLevelBadge extends StatefulWidget {
  final String riskLevel;
  final bool showLabel;
  final bool compact;

  const RiskLevelBadge({
    required this.riskLevel,
    this.showLabel = true,
    this.compact = false,
    super.key,
  });

  @override
  State<RiskLevelBadge> createState() => _RiskLevelBadgeState();
}

class _RiskLevelBadgeState extends State<RiskLevelBadge> {
  bool _showExplanation = false;

  String _getExplanation(String level) {
    switch (level) {
      case 'High':
        return 'High stress or loop pattern detected. Priority: address physiological needs first (HALT), then use interventions.';
      case 'Medium':
        return 'Mild stress detected. Consider checking in with basic needs (water, rest, movement).';
      case 'Low':
      default:
        return 'Physiological state is stable. You\'re in a good place to make decisions.';
    }
  }

  Color _getColor(String level) {
    switch (level) {
      case 'High':
        return const Color(0xFFC16B4B);
      case 'Medium':
        return const Color(0xFFD89E6F);
      case 'Low':
      default:
        return const Color(0xFF5B9B96);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(widget.riskLevel);
    final explanation = _getExplanation(widget.riskLevel);

    return GestureDetector(
      onTap: () {
        setState(() => _showExplanation = !_showExplanation);
      },
      child: AnimatedCrossFade(
        firstChild: _buildBadge(color),
        secondChild: _buildExplanation(color, explanation),
        crossFadeState:
            _showExplanation ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildBadge(Color color) {
    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${widget.riskLevel} Risk',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.showLabel ? '${widget.riskLevel} Risk' : widget.riskLevel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildExplanation(Color color, String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.close,
            color: Colors.white,
            size: 14,
          ),
        ],
      ),
    );
  }
}
