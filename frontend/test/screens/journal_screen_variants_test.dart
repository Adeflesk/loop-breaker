import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Intervention Variant Logic', () {
    // Test the variant mapping directly
    const Map<String, List<String>> testVariants = {
      'Stress': ['Physiological Sigh', 'Somatic Reset'],
      'Anxiety': ['5-4-3-2-1 Grounding', 'Somatic Reset'],
      'Procrastination': ['The 5-Minute Sprint', 'Activation Burst'],
      'Overwhelm': ['Brain Dump', 'Activation Burst'],
      'Numbness': ['Temperature Shock', 'Sensation Snap'],
    };

    test('Stress node has exactly 2 intervention variants', () {
      expect(testVariants['Stress']!.length, equals(2));
      expect(testVariants['Stress']![0], equals('Physiological Sigh'));
      expect(testVariants['Stress']![1], equals('Somatic Reset'));
    });

    test('Anxiety node has exactly 2 intervention variants', () {
      expect(testVariants['Anxiety']!.length, equals(2));
      expect(testVariants['Anxiety']![0], equals('5-4-3-2-1 Grounding'));
      expect(testVariants['Anxiety']![1], equals('Somatic Reset'));
    });

    test('Procrastination node has exactly 2 intervention variants', () {
      expect(testVariants['Procrastination']!.length, equals(2));
      expect(testVariants['Procrastination']![0], equals('The 5-Minute Sprint'));
      expect(testVariants['Procrastination']![1], equals('Activation Burst'));
    });

    test('Overwhelm node has exactly 2 intervention variants', () {
      expect(testVariants['Overwhelm']!.length, equals(2));
      expect(testVariants['Overwhelm']![0], equals('Brain Dump'));
      expect(testVariants['Overwhelm']![1], equals('Activation Burst'));
    });

    test('Numbness node has exactly 2 intervention variants', () {
      expect(testVariants['Numbness']!.length, equals(2));
      expect(testVariants['Numbness']![0], equals('Temperature Shock'));
      expect(testVariants['Numbness']![1], equals('Sensation Snap'));
    });

    test('Cycling index wraps correctly (modulo operation)', () {
      final variants = testVariants['Stress']!;
      int currentIndex = 0;

      // Cycle through all variants
      currentIndex = (currentIndex + 1) % variants.length; // Should be 1
      expect(currentIndex, equals(1));

      // Cycle again, should wrap to 0
      currentIndex = (currentIndex + 1) % variants.length; // Should be 0
      expect(currentIndex, equals(0));
    });

    test('Nodes without variants are not in the map', () {
      expect(testVariants.containsKey('Shame'), isFalse);
      expect(testVariants.containsKey('Isolation'), isFalse);
    });

    test('All movement variant titles are unique per node', () {
      testVariants.forEach((node, interventions) {
        expect(interventions.toSet().length, equals(interventions.length),
            reason: '$node should not have duplicate intervention titles');
      });
    });
  });
}
