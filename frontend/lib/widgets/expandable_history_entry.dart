import 'package:flutter/material.dart';

class ExpandableHistoryEntry extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onExpanded;

  const ExpandableHistoryEntry({
    required this.item,
    this.onExpanded,
    super.key,
  });

  @override
  State<ExpandableHistoryEntry> createState() => _ExpandableHistoryEntryState();
}

class _ExpandableHistoryEntryState extends State<ExpandableHistoryEntry>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _heightFactor;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightFactor = _expandController.drive(
      Tween<double>(begin: 0.0, end: 1.0).chain(
        CurveTween(curve: Curves.easeInOut),
      ),
    );
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
        widget.onExpanded?.call();
      } else {
        _expandController.reverse();
      }
    });
  }

  String _formatTimestamp(dynamic time) {
    if (time == null) return 'Unknown';
    final timeString = time.toString();
    if (timeString.length >= 16) {
      return timeString.substring(0, 16).replaceFirst(' ', '\n');
    }
    return timeString;
  }

  @override
  Widget build(BuildContext context) {
    final bool success = widget.item['was_successful'] == true;
    final String state = widget.item['state']?.toString() ?? 'Unknown';
    final String intervention = widget.item['intervention']?.toString() ?? '';
    final double confidence =
        (widget.item['confidence'] as num?)?.toDouble() ?? 0.0;
    final String timeStr = _formatTimestamp(widget.item['time']);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0 || details.primaryVelocity! < 0) {
          _toggle();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE0D5CC),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main entry card (always visible)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: success
                      ? const Color(0xFF5B9B96).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    success ? Icons.check_circle : Icons.circle_outlined,
                    color: success
                        ? const Color(0xFF5B9B96)
                        : Colors.grey[400],
                    size: 22,
                  ),
                ),
              ),
              title: Text(
                state,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                intervention.isNotEmpty
                    ? 'Intervention: $intervention'
                    : 'Healthy State',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr.split('\n').first,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RotatedBox(
                    quarterTurns: _isExpanded ? 3 : 1,
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                ],
              ),
              onTap: _toggle,
            ),
            // Expanded details (animated)
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _heightFactor.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 12),
                        _buildDetailRow(
                          label: 'Confidence',
                          value: '${(confidence * 100).toStringAsFixed(0)}%',
                          icon: Icons.percent,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          label: 'Full Time',
                          value: timeStr.replaceFirst('\n', ' '),
                          icon: Icons.schedule,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          label: 'Status',
                          value: success ? 'Loop Broken' : 'No Intervention',
                          icon: success
                              ? Icons.check_circle
                              : Icons.info_outline,
                          valueColor:
                              success ? Colors.green : Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF5B9B96)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: valueColor ?? Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
