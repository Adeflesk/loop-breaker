import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


class CrisisSafetyDialog extends StatelessWidget {
  final List<Map<String, String>> hotlines;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const CrisisSafetyDialog({
    super.key,
    required this.hotlines,
    required this.onContinue,
    required this.onCancel,
  });

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        "We're Concerned About Your Safety",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF44336), // Red
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              "You've written something that concerns us. Please reach out for support:",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            // Hotline cards
            ...hotlines.map((hotline) => _buildHotlineCard(context, hotline)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hotlines.isNotEmpty
                    ? hotlines[0]['emergency'] ?? "If you are in immediate danger, call 911."
                    : "If you are in immediate danger, call 911.",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: const Text(
            "I'm Safe, Continue",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildHotlineCard(BuildContext context, Map<String, String> hotline) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hotline['name'] ?? 'Crisis Resource',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            if (hotline['phone'] != null)
              Text(
                "Call: ${hotline['phone']}",
                style: const TextStyle(fontSize: 13),
              ),
            if (hotline['text'] != null)
              Text(
                "Text: ${hotline['text']}",
                style: const TextStyle(fontSize: 13),
              ),
            if (hotline['available'] != null)
              Text(
                hotline['available']!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            if (hotline['url'] != null)
              ElevatedButton.icon(
                onPressed: () => _launchUrl(hotline['url']!),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text("Open Link"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
