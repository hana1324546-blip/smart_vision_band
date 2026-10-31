import 'platform_bridge.dart';
class CameraChannelService extends PlatformBridge {
  CameraChannelService(): super('camera');
  Future<void> start() async { await call('start'); }
  Future<void> configure(double confidence) async { await call('configure', {'confidence': confidence}); }
  Future<void> setLanguage(String languageCode) async { await call('setLanguage', {'languageCode': languageCode}); }
  Future<void> requestSnapshot(int requestId) async { await call('snapshot', {'requestId': requestId}); }
  Future<void> stop() async { await call('stop'); }
}
