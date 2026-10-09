import 'package:flutter_test/flutter_test.dart';
import 'package:gdc_customer_app/core/utils/name_validator.dart';

void main() {
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

    test('Rejects entirely lowercase names', () {
      expect(isValidRealName('john doe'), isFalse);
      expect(isValidRealName('maria clara'), isFalse);
    });

    test('Rejects names with invalid capitalization or weird gamer tags', () {
      expect(isValidRealName('CaT uwu'), isFalse);
      expect(isValidRealName('John dOE'), isFalse);
      expect(isValidRealName('jOhn Doe'), isFalse);
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
