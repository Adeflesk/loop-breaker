import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/passcode_lock_screen.dart';
import 'package:frontend/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
    ApiClient.passcode = null;
  });

  testWidgets('PasscodeLockScreen validates empty input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PasscodeLockScreen(onUnlocked: (_) {}),
      ),
    );

    expect(find.text('LoopBreaker'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);

    await tester.tap(find.text('Unlock'));
    await tester.pump();

    expect(find.text('Please enter your passcode.'), findsOneWidget);
  });

  testWidgets('PasscodeLockScreen shows error on wrong passcode', (tester) async {
    ApiClient.clientOverride = MockClient((request) async {
      return http.Response('{"detail": "Invalid passcode"}', 401);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PasscodeLockScreen(onUnlocked: (_) {}),
      ),
    );

    await tester.enterText(find.byType(TextField), 'wrong-code');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(
      find.text('Incorrect passcode. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('PasscodeLockScreen calls onUnlocked on valid passcode', (
    tester,
  ) async {
    String? unlockedCode;
    ApiClient.clientOverride = MockClient((request) async {
      expect(request.url.path, '/auth/verify');
      return http.Response('{"authenticated": true}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PasscodeLockScreen(
          onUnlocked: (code) => unlockedCode = code,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'secret-1234');
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(unlockedCode, 'secret-1234');
  });
}
