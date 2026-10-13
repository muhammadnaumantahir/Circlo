/// Minimum age to use Circlo. Open question Q2b - keep in sync with firebase/firestore.rules.
const int kMinimumAge = 13;

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _phoneRegex = RegExp(r'^\+[1-9][0-9]{6,14}$');

String? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Enter your email address';
  if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter a password';
  if (v.length < 8) return 'Use at least 8 characters';
  return null;
}

String? validateDisplayName(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Enter your name';
  if (v.length > 50) return 'Use 50 characters or fewer';
  return null;
}

String? validateCircleName(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Enter a circle name';
  if (v.length > 40) return 'Use 40 characters or fewer';
  return null;
}

/// Phone is optional; when given it must be in international format, e.g. +923001234567.
String? validatePhone(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return null;
  if (!_phoneRegex.hasMatch(v)) {
    return 'Use international format, e.g. +923001234567';
  }
  return null;
}

bool isOldEnough(int birthYear, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  return year - birthYear >= kMinimumAge;
}

String? validateBirthYear(String? value, {DateTime? now}) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Enter your birth year';
  final year = int.tryParse(v);
  final current = (now ?? DateTime.now()).year;
  if (year == null || year < 1900 || year > current) {
    return 'Enter a valid birth year';
  }
  if (!isOldEnough(year, now: now)) {
    return 'Circlo is for people aged $kMinimumAge and over';
  }
  return null;
}
