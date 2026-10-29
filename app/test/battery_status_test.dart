import 'package:circlo/features/location/battery_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('low battery threshold includes 20 percent, not 21 percent', () {
    expect(isLowBattery(0), isTrue);
    expect(isLowBattery(20), isTrue);
    expect(isLowBattery(21), isFalse);
    expect(isLowBattery(100), isFalse);
    expect(isLowBattery(null), isFalse);
    expect(isLowBattery(-1), isFalse);
    expect(isLowBattery(101), isFalse);
  });
}
