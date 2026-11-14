import 'package:flutter_test/flutter_test.dart';
import 'package:gdc_customer_app/core/utils/name_validator.dart';

void main() {
  group('capitalizeName Tests', () {
    test('Capitalizes uncapitalized or mixed-case names correctly', () {
      expect(capitalizeName('john doe'), 'John Doe');
      expect(capitalizeName('juan dela cruz'), 'Juan Dela Cruz');
      expect(capitalizeName('JUAN DELA CRUZ'), 'Juan Dela Cruz');
      expect(capitalizeName('mARia cLAra'), 'Maria Clara');
      expect(capitalizeName('mary-jane watson'), 'Mary-Jane Watson');
      expect(capitalizeName("o'connor smith"), "O'Connor Smith");
    });

    test('Handles null and empty string', () {
      expect(capitalizeName(null), '');
      expect(capitalizeName(''), '');
      expect(capitalizeName('   '), '');
    });
  });

  group('isValidRealName Sanitization Tests', () {
    test('Rejects null or empty string', () {
      expect(isValidRealName(null), isFalse);
      expect(isValidRealName(''), isFalse);
      expect(isValidRealName('   '), isFalse);
    });

    test('Rejects single words', () {
      expect(isValidRealName('John'), isFalse);
      expect(isValidRealName('Cat'), isFalse);
      expect(isValidRealName('Batman'), isFalse);
    });

    test('Rejects names with emojis, numbers, or special characters', () {
      expect(isValidRealName('John Doe 😃'), isFalse);
      expect(isValidRealName('John123 Doe'), isFalse);
      expect(isValidRealName('xX_Gamer_Xx'), isFalse);
      expect(isValidRealName('John@Doe'), isFalse);
    });

    test('Accepts uncapitalized names and automatically considers them valid', () {
      expect(isValidRealName('john doe'), isTrue);
      expect(isValidRealName('maria clara'), isTrue);
      expect(isValidRealName('juan dela cruz'), isTrue);
      expect(isValidRealName('John dOE'), isTrue);
      expect(isValidRealName('jOhn Doe'), isTrue);
    });

    test('Accepts valid standard human real names', () {
      expect(isValidRealName('John Doe'), isTrue);
      expect(isValidRealName('Juan Dela Cruz'), isTrue);
      expect(isValidRealName('Maria Clara'), isTrue);
      expect(isValidRealName('Mary-Jane Watson'), isTrue);
      expect(isValidRealName("O'Connor Smith"), isTrue);
      expect(isValidRealName('Dr. Jose Rizal'), isTrue);
    });
  });
}
