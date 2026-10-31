import 'dart:async';
import 'platform_bridge.dart';
import '../models/distance_event.dart';

class BluetoothService extends PlatformBridge {
  BluetoothService(): super('bluetooth');
  final telemetry = BluetoothTelemetry();

  StreamSubscription<dynamic> listenTelemetry(
      void Function(Map<dynamic, dynamic> event, BluetoothTelemetry status) onEvent,
      {void Function(Object error)? onError}) {
    return events.listen((dynamic raw) {
      if (raw is! Map) return;
      telemetry.update(raw);
      onEvent(raw, telemetry);
    }, onError: onError);
  }

  Future<List<dynamic>> bonded() async => await call<List<dynamic>>('bonded') ?? [];
  Future<void> connect(String address) async { await call('connect', {'address': address}); }
  Future<void> send(String line) async { await call('send', {'line': line}); }
  Future<void> alert() async { await call('alert'); }
  Future<void> haptic(String command) async { await call('haptic', {'command': command}); }
  Future<void> disconnect() async { await call('disconnect'); }
}

class BluetoothTelemetry {
  bool connected = false;
  bool reconnecting = false;
  double? batteryPercent;
  double? distanceCm;
  DateTime? lastDistanceAt;

  bool get receivingUltrasonic {
    final received = lastDistanceAt;
    if (received == null) return false;
    final age = DateTime.now().difference(received).inMilliseconds;
    return age >= 0 && age <= 1500;
  }

  void update(Map<dynamic, dynamic> event) {
    if (event['type'] == 'state') {
      connected = event['connected'] == true;
      reconnecting = !connected && event['reconnecting'] == true;
    }
    if (event['type'] != 'rx' || event['line'] is! String) return;
    final parsed = Protocol.parse(event['line'] as String);
    if (parsed?.key == 'DIST') {
      distanceCm = parsed!.value;
      lastDistanceAt = DateTime.now();
    } else if (parsed?.key == 'BATT') {
      batteryPercent = parsed!.value;
    }
  }
}
