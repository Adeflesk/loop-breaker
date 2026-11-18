import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'journal_history_screen.dart';

/// Combines the behavioral Journey Dashboard and chronological My Journal
/// entries under a single History tab to keep top-level navigation focused.
class HistoryHubScreen extends StatelessWidget {
  const HistoryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export Journey',
              onPressed: () => showJourneyExportDialog(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'My Journal'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            HistoryScreen(showAppBar: false),
            JournalHistoryScreen(showAppBar: false),
          ],
        ),
      ),
    );
  }
}
