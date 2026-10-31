import 'package:flutter/services.dart';
import '../core/constants.dart';
import 'platform_bridge.dart';

class ForegroundService extends PlatformBridge {
  ForegroundService() : super('service') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stoppedByNotification') onExternalStop?.call();
    });
  }

  final MethodChannel _channel = MethodChannel('$channelPrefix/service');
  void Function()? onExternalStop;

  Future<void> start() async { await call('start'); }
  Future<void> stop() async { await call('stop'); }
}