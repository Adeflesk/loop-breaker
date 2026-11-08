import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/environment_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiClient.clientOverride = null;
  });

  testWidgets('EnvironmentScreen selects loop, checks items, and saves audit',
      (tester) async {
    Map<String, dynamic>? savedPayload;

    ApiClient.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/environment-audit') &&
          request.method == 'POST') {
        savedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'status': 'saved'}), 200);
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: EnvironmentScreen(initialLoop: 'Stress'),
      ),
    );
    await tester.pump();

    expect(find.text('Environment Audit'), findsOneWidget);
    await tester.tap(
      find.text('Put phone in another room during focus blocks'),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'Charge phone in the kitchen after 9:30 PM',
    );
    await tester.pump();

    await tester.tap(find.text('Save Environment Audit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(savedPayload, isNotNull);
    expect(savedPayload!['target_loop'], 'Stress');
    expect(
      savedPayload!['checked_items'],
      contains('Put phone in another room during focus blocks'),
    );
    expect(
      savedPayload!['custom_friction_step'],
      'Charge phone in the kitchen after 9:30 PM',
    );
  });
}
