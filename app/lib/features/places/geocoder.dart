import 'dart:convert';

import 'package:http/http.dart' as http;

/// Free place search. The default is OpenStreetMap Nominatim, whose usage policy allows
/// light use only: at most 1 request per second, no autocomplete (search on submit), identify the
/// app, show attribution (ADR-0004). Set GEOCODER_URL to another provider before a public release.
const String kGeocoderUrl = String.fromEnvironment(
  'GEOCODER_URL',
  defaultValue: 'https://nominatim.openstreetmap.org/search',
);

class GeocodeResult {
  const GeocodeResult({required this.label, required this.lat, required this.lng});
  final String label;
  final double lat;
  final double lng;
}

List<GeocodeResult> parseGeocodeResponse(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const [];
  final out = <GeocodeResult>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final lat = double.tryParse('${item['lat']}');
    final lng = double.tryParse('${item['lon']}');
    final label = '${item['display_name'] ?? ''}'.trim();
    if (lat == null || lng == null || label.isEmpty) continue;
    out.add(GeocodeResult(label: label, lat: lat, lng: lng));
  }
  return out;
}

class GeocodeException implements Exception {
  const GeocodeException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlaceSearchService {
  PlaceSearchService({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, List<GeocodeResult>> _cache = {};
  DateTime? _lastRequest;
  static const Duration _minGap = Duration(milliseconds: 1100);

  Future<List<GeocodeResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final cached = _cache[q.toLowerCase()];
    if (cached != null) return cached;

    final last = _lastRequest;
    if (last != null) {
      final wait = _minGap - _clock().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequest = _clock();

    try {
      final uri = Uri.parse(kGeocoderUrl).replace(
        queryParameters: {'q': q, 'format': 'jsonv2', 'limit': '5'},
      );
      final res = await _client.get(uri, headers: const {
        'User-Agent': 'Circlo/0.1 (https://github.com/muhammadnaumantahir/Circlo)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw const GeocodeException('Search is unavailable right now. Tap the map to drop a pin instead.');
      }
      final results = parseGeocodeResponse(res.body);
      _cache[q.toLowerCase()] = results;
      return results;
    } on GeocodeException {
      rethrow;
    } catch (_) {
      throw const GeocodeException('Could not search. Check your connection, or tap the map to drop a pin.');
    }
  }
}
