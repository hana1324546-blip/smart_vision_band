import 'package:flutter_test/flutter_test.dart';
import 'package:smart_vision_band/services/bluetooth_service.dart';

void main() {
  test('tracks reconnecting, battery, and fresh ultrasonic readings', () {
    final telemetry = BluetoothTelemetry();
    telemetry.update({'type': 'state', 'connected': false, 'reconnecting': true});
    expect(telemetry.reconnecting, isTrue);

    telemetry.update({'type': 'rx', 'line': 'DIST:42'});
    expect(telemetry.distanceCm, 42);
    expect(telemetry.receivingUltrasonic, isTrue);

    telemetry.update({'type': 'rx', 'line': 'BATT:76'});
    expect(telemetry.batteryPercent, 76);
    telemetry.lastDistanceAt = DateTime.now().subtract(const Duration(seconds: 2));
    expect(telemetry.receivingUltrasonic, isFalse);
  });
}