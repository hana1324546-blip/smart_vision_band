import 'platform_bridge.dart';
class AudioRouteService extends PlatformBridge {
  AudioRouteService(): super('audio');
  Future<bool> get earbudsActive async => await call<bool>('isBluetoothOutput') ?? false;
  Future<void> phoneVibrate() async { await call('vibrate'); }
}
