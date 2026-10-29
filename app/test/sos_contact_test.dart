import 'package:circlo/features/sos/sos_contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('call action opens the external dialer for the opted-in phone number', () {
    final uri = sosCallUri('+923001234567');

    expect(uri.scheme, 'tel');
    expect(uri.path, '+923001234567');
    expect(uri.query, isEmpty);
  });

  test('text action opens an unsent SMS draft with the reviewed message', () {
    const message = 'SOS: I need help. Please call me.';
    final uri = sosTextUri('+923001234567', message);

    expect(uri.scheme, 'sms');
    expect(uri.path, '+923001234567');
    expect(uri.queryParameters['body'], message);
  });

  test('SMS draft preserves punctuation and a map URL through URI encoding', () {
    const message = 'SOS: map https://www.google.com/maps/search/?api=1&query=31.520400,74.358700';
    final uri = sosTextUri('+923001234567', message);

    expect(Uri.parse(uri.toString()).queryParameters['body'], message);
  });
}
