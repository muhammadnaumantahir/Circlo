import 'package:circlo/features/places/geocoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Nominatim-style results and skips malformed entries', () {
    const body = '[{"lat":"31.5204","lon":"74.3587","display_name":"Lahore, Punjab, Pakistan"},'
        '{"lat":"x","lon":"1","display_name":"bad"},'
        '{"lat":"1","lon":"2"},'
        '{"lat":"33.68","lon":"73.04","display_name":"Islamabad"}]';
    final r = parseGeocodeResponse(body);
    expect(r.length, 2);
    expect(r.first.label, 'Lahore, Punjab, Pakistan');
    expect(r.first.lat, closeTo(31.5204, 1e-9));
    expect(r.last.lng, closeTo(73.04, 1e-9));
  });

  test('non-list responses give no results', () {
    expect(parseGeocodeResponse('{"error":"x"}'), isEmpty);
    expect(parseGeocodeResponse('[]'), isEmpty);
  });

  test('queries shorter than 3 characters are not sent', () async {
    final s = PlaceSearchService();
    expect(await s.search('ab'), isEmpty);
  });
}
