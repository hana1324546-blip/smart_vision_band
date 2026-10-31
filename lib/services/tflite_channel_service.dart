import 'platform_bridge.dart';
class TfliteChannelService extends PlatformBridge {
  TfliteChannelService(): super('camera');
  Future<void> setConfidence(double confidence) async {
    await call('configure', {'confidence': confidence});
  }
}
