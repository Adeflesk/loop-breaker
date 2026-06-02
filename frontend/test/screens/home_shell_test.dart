import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/home_shell.dart';
import 'package:frontend/screens/library_screen.dart';
import 'package:frontend/services/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  void setupMocks() {
    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/insight')) {
        return http.Response(
          jsonEncode({'message': 'Hi', 'weekly_activity': [], 'streak': 0}),
          200,
        );
      }
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path.endsWith('/weekly-summary')) {
        return http.Response(jsonEncode({}), 200);
      }
      if (request.url.path.endsWith('/stats')) {
        return http.Response(jsonEncode({}), 200);
      }
      if (request.url.path.contains('loop-path')) {
        return http.Response(jsonEncode({'path': [], 'analysis': {}}), 200);
      }
      return http.Response('', 404);
    });
  }

  testWidgets('HomeShell has exactly 5 NavigationDestination items', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });

  testWidgets('5th tab is labelled Learn', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    expect(find.text('Learn'), findsOneWidget);
  });

  testWidgets('tapping Learn tab shows LibraryScreen', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Rewire Library'), findsOneWidget);
  });

  testWidgets('Learn tab has menu_book icon', (tester) async {
    setupMocks();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });
}
