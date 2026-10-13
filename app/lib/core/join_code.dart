import 'dart:math';

/// Unambiguous alphabet (no I, L, O, 0, 1). Must match firebase/firestore.rules.
const String kJoinCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int kJoinCodeLength = 10;

String generateJoinCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
    kJoinCodeLength,
    (_) => kJoinCodeAlphabet[r.nextInt(kJoinCodeAlphabet.length)],
  ).join();
}

/// Uppercases and removes spaces and dashes so people can type "abcde-fghjk".
String normalizeJoinCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

bool isValidJoinCode(String code) {
  if (code.length != kJoinCodeLength) return false;
  return code.split('').every(kJoinCodeAlphabet.contains);
}

/// Display form: ABCDE-FGHJK
String formatJoinCode(String code) => code.length == kJoinCodeLength
    ? '${code.substring(0, 5)}-${code.substring(5)}'
    : code;
