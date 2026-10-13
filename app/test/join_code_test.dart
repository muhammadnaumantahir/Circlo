import 'dart:math';

import 'package:circlo/core/join_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated codes are valid, 10 chars, unambiguous alphabet', () {
    final r = Random(42);
    for (var i = 0; i < 500; i++) {
      final c = generateJoinCode(r);
      expect(c.length, kJoinCodeLength);
      expect(isValidJoinCode(c), isTrue);
      expect(c.contains(RegExp('[ILO01]')), isFalse);
    }
  });

  test('codes are not constant', () {
    final r = Random(1);
    final codes = {for (var i = 0; i < 100; i++) generateJoinCode(r)};
    expect(codes.length, greaterThan(95));
  });

  test('normalize strips spaces/dashes and uppercases', () {
    expect(normalizeJoinCode('abcde-fghjk'), 'ABCDEFGHJK');
    expect(normalizeJoinCode(' abcde fghjk '), 'ABCDEFGHJK');
  });

  test('validity rejects wrong length and ambiguous characters', () {
    expect(isValidJoinCode('ABCDEFGHJ'), isFalse);
    expect(isValidJoinCode('ABCDEFGHJKM'), isFalse);
    expect(isValidJoinCode('ABCDEFGHJ0'), isFalse);
    expect(isValidJoinCode('ABCDEFGHJK'), isTrue);
  });

  test('format groups the code for display', () {
    expect(formatJoinCode('ABCDEFGHJK'), 'ABCDE-FGHJK');
    expect(formatJoinCode('short'), 'short');
  });
}
