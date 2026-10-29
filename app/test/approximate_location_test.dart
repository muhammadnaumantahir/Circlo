import 'package:circlo/features/location/approximate_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snaps coordinates to a stable coarse grid', () {
    const lat = 31.5204;
    const lng = 74.3587;
    final first = approximateCoordinatesFor(lat, lng);
    final second = approximateCoordinatesFor(lat + 0.0001, lng - 0.0001);

    expect(first.lat / kApproximateGridDegrees,
        closeTo((first.lat / kApproximateGridDegrees).roundToDouble(), 1e-9));
    expect(first.lng / kApproximateGridDegrees,
        closeTo((first.lng / kApproximateGridDegrees).roundToDouble(), 1e-9));
    expect(second.lat, first.lat);
    expect(second.lng, first.lng);
    expect(first.lat, isNot(lat));
    expect(first.lng, isNot(lng));
  });

  test('keeps snapped points within valid coordinate ranges near the edges', () {
    final northEast = approximateCoordinatesFor(89.999, 179.999);
    final southWest = approximateCoordinatesFor(-89.999, -179.999);

    expect(northEast.lat, inInclusiveRange(-90, 90));
    expect(northEast.lng, inInclusiveRange(-180, 180));
    expect(southWest.lat, inInclusiveRange(-90, 90));
    expect(southWest.lng, inInclusiveRange(-180, 180));
  });

  test('rejects non-finite and out-of-range input coordinates', () {
    expect(() => approximateCoordinatesFor(double.nan, 0), throwsArgumentError);
    expect(() => approximateCoordinatesFor(0, double.infinity), throwsArgumentError);
    expect(() => approximateCoordinatesFor(91, 0), throwsArgumentError);
    expect(() => approximateCoordinatesFor(0, -181), throwsArgumentError);
  });

  test('documents a coarse accuracy floor', () {
    expect(kApproximateAccuracyFloorM, greaterThanOrEqualTo(1700));
  });
}
