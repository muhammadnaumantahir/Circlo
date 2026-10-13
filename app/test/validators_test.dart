import 'package:circlo/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 13);

  group('validateEmail', () {
    test('rejects empty and malformed', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('abc'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
    });
    test('accepts valid, trimming spaces', () {
      expect(validateEmail(' a@b.co '), isNull);
    });
  });

  group('validatePassword', () {
    test('requires 8+ characters', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('1234567'), isNotNull);
      expect(validatePassword('12345678'), isNull);
    });
  });

  group('names', () {
    test('display name 1..50', () {
      expect(validateDisplayName('  '), isNotNull);
      expect(validateDisplayName('A' * 51), isNotNull);
      expect(validateDisplayName('Ali'), isNull);
    });
    test('circle name 1..40', () {
      expect(validateCircleName(''), isNotNull);
      expect(validateCircleName('A' * 41), isNotNull);
      expect(validateCircleName('Family'), isNull);
    });
  });

  group('validatePhone', () {
    test('optional, international format when given', () {
      expect(validatePhone(''), isNull);
      expect(validatePhone(null), isNull);
      expect(validatePhone('+923001234567'), isNull);
      expect(validatePhone('03001234567'), isNotNull);
      expect(validatePhone('+0123'), isNotNull);
    });
  });

  group('birth year / minimum age', () {
    test('rejects empty, non-numeric, future and too old values', () {
      expect(validateBirthYear('', now: now), isNotNull);
      expect(validateBirthYear('abcd', now: now), isNotNull);
      expect(validateBirthYear('2030', now: now), isNotNull);
      expect(validateBirthYear('1800', now: now), isNotNull);
    });
    test('enforces the minimum age of 13', () {
      expect(validateBirthYear('2014', now: now), isNotNull); // 12
      expect(validateBirthYear('2013', now: now), isNull); // 13
      expect(validateBirthYear('1990', now: now), isNull);
      expect(isOldEnough(2013, now: now), isTrue);
      expect(isOldEnough(2014, now: now), isFalse);
    });
  });
}
