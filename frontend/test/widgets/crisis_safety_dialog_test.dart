import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/crisis_safety_dialog.dart';

void main() {
  group('CrisisSafetyDialog', () {
    final testHotlines = [
      {
        'name': '988 Suicide & Crisis Lifeline',
        'phone': '988',
        'url': 'https://988lifeline.org',
        'available': '24/7',
      },
      {
        'name': 'Crisis Text Line',
        'text': 'Text HOME to 741741',
        'url': 'https://www.crisistextline.org',
        'available': '24/7',
      },
    ];

    testWidgets('renders dialog with correct title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: testHotlines,
                        onContinue: () {},
                        onCancel: () {},
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);
    });

    testWidgets('displays all hotline cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: testHotlines,
                        onContinue: () {},
                        onCancel: () {},
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('988 Suicide & Crisis Lifeline'), findsOneWidget);
      expect(find.text('Crisis Text Line'), findsOneWidget);
      // Verify exactly 2 hotline cards are displayed
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('displays emergency warning message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: testHotlines,
                        onContinue: () {},
                        onCancel: () {},
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('If you are in immediate danger, call 911.'), findsOneWidget);
    });

    testWidgets('calls onContinue when continue button pressed', (WidgetTester tester) async {
      bool continueCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: testHotlines,
                        onContinue: () {
                          continueCalled = true;
                        },
                        onCancel: () {},
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(continueCalled, isFalse);
      await tester.tap(find.text("I'm Safe, Continue"));
      await tester.pumpAndSettle();

      expect(continueCalled, isTrue);
    });

    testWidgets('calls onCancel when cancel button pressed', (WidgetTester tester) async {
      bool cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: testHotlines,
                        onContinue: () {},
                        onCancel: () {
                          cancelCalled = true;
                        },
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });

    testWidgets('displays hotline phone numbers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: testHotlines,
                        onContinue: () {},
                        onCancel: () {},
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Call: 988'), findsOneWidget);
    });

    testWidgets('displays availability information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: testHotlines,
                        onContinue: () {},
                        onCancel: () {},
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('24/7'), findsWidgets);
    });

    testWidgets('renders with empty hotlines list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: [],
                        onContinue: () {},
                        onCancel: () {},
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);
      expect(find.text('If you are in immediate danger, call 911.'), findsOneWidget);
    });

    testWidgets('dialog has proper semantic structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CrisisSafetyDialog(
                        hotlines: testHotlines,
                        onContinue: () {},
                        onCancel: () {},
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify AlertDialog is rendered
      expect(find.byType(AlertDialog), findsOneWidget);

      // Verify buttons are present
      expect(find.byType(TextButton), findsOneWidget); // Cancel button
      expect(find.byType(ElevatedButton), findsWidgets); // Continue button
    });
  });
}
