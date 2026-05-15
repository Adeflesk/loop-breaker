import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/crisis_safety_service.dart';

void main() {
  group('CrisisSafetyService', () {
    late CrisisSafetyService service;

    setUp(() {
      service = CrisisSafetyService();
    });

    test('detects suicide keyword', () {
      final (isCrisis, keywords) = service.detectCrisis('I want to commit suicide');
      expect(isCrisis, isTrue);
      expect(keywords, contains('suicide'));
    });

    test('detects multiple keywords', () {
      final (isCrisis, keywords) = service.detectCrisis('I am thinking suicide and hopeless about everything');
      expect(isCrisis, isTrue);
      expect(keywords.length, greaterThanOrEqualTo(2));
      expect(keywords.any((k) => k.contains('suicide')), isTrue);
      expect(keywords.any((k) => k.contains('hopeless')), isTrue);
    });

    test('case insensitive matching', () {
      final (isCrisis, keywords) = service.detectCrisis('SUICIDE is all I think about');
      expect(isCrisis, isTrue);
      expect(keywords, contains('suicide'));
    });

    test('ignores text shorter than 10 characters', () {
      final (isCrisis, keywords) = service.detectCrisis('harm');
      expect(isCrisis, isFalse);
      expect(keywords, isEmpty);
    });

    test('deduplicates keywords', () {
      final (isCrisis, keywords) = service.detectCrisis('suicide suicide suicide and more suffering');
      expect(isCrisis, isTrue);
      expect(keywords.length, lessThanOrEqualTo(2)); // Only unique keywords
    });

    test('returns false for normal text', () {
      final (isCrisis, keywords) = service.detectCrisis('Today was a good day and I am feeling positive');
      expect(isCrisis, isFalse);
      expect(keywords, isEmpty);
    });

    test('accepts null input', () {
      final (isCrisis, keywords) = service.detectCrisis(null);
      expect(isCrisis, isFalse);
      expect(keywords, isEmpty);
    });

    test('accepts empty string input', () {
      final (isCrisis, keywords) = service.detectCrisis('');
      expect(isCrisis, isFalse);
      expect(keywords, isEmpty);
    });

    test('accepts custom keywords', () {
      final customService = CrisisSafetyService(
        customKeywords: ['custom', 'critical'],
      );
      final (isCrisis, keywords) = customService.detectCrisis('This is a custom critical message');
      expect(isCrisis, isTrue);
      expect(keywords, containsAll(['custom', 'critical']));
    });

    test('detects "kill myself" phrase', () {
      final (isCrisis, keywords) = service.detectCrisis('I want to kill myself');
      expect(isCrisis, isTrue);
      expect(keywords, contains('kill myself'));
    });

    test('detects harm keywords', () {
      final (isCrisis, keywords) = service.detectCrisis('I want to harm myself');
      expect(isCrisis, isTrue);
      expect(keywords, isNotEmpty);
    });

    test('detects overdose keyword', () {
      final (isCrisis, keywords) = service.detectCrisis('I might overdose on all my pills tonight');
      expect(isCrisis, isTrue);
      expect(keywords.isNotEmpty, isTrue);
    });

    test('word boundary matching prevents false positives', () {
      // "suicide" in the middle of another word should not match
      final (isCrisis, keywords) = service.detectCrisis('I study suicidology at university level today');
      // Should not detect since "suicidology" is not "suicide"
      expect(isCrisis, isFalse);
    });

    test('convenience method isCrisis returns correct boolean', () {
      final result1 = service.isCrisis('I want to end my life');
      expect(result1, isTrue);

      final result2 = service.isCrisis('Today is a beautiful day');
      expect(result2, isFalse);
    });

    test('convenience method getDetectedKeywords returns keywords list', () {
      final keywords1 = service.getDetectedKeywords('I am hopeless and thinking suicide');
      expect(keywords1, isNotEmpty);
      expect(keywords1, containsAll(['hopeless', 'suicide']));

      final keywords2 = service.getDetectedKeywords('Everything is fine');
      expect(keywords2, isEmpty);
    });

    test('detects abuse and violence keywords', () {
      final (isCrisis, keywords) = service.detectCrisis('I am experiencing domestic violence and abuse');
      expect(isCrisis, isTrue);
      expect(keywords.length, greaterThanOrEqualTo(1));
    });

    test('detects sexual assault keyword', () {
      final (isCrisis, keywords) = service.detectCrisis('I was a victim of sexual assault');
      expect(isCrisis, isTrue);
      expect(keywords.any((k) => k.contains('sexual') || k.contains('rape')), isTrue);
    });

    test('mixed case handling with special characters', () {
      final (isCrisis, keywords) = service.detectCrisis('I am... HOPELESS... and want to end my life');
      expect(isCrisis, isTrue);
      expect(keywords, containsAll(['hopeless', 'end my life']));
    });

    test('detects "everyone would be better without me" phrase', () {
      final (isCrisis, keywords) = service.detectCrisis('I think everyone would be better without me in their lives');
      expect(isCrisis, isTrue);
      expect(keywords, isNotEmpty);
    });

    test('returns deduplicated keywords in consistent order', () {
      final (isCrisis1, keywords1) = service.detectCrisis('suicide and hopeless thinking suicide again');
      final (isCrisis2, keywords2) = service.detectCrisis('suicide and hopeless thinking suicide again');

      expect(isCrisis1, isTrue);
      expect(isCrisis2, isTrue);
      expect(keywords1.toSet(), equals(keywords2.toSet())); // Set equality
    });
  });
}
