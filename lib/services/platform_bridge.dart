import 'package:flutter/services.dart';
import '../core/constants.dart';
class PlatformBridge {
  final String module;
  PlatformBridge(this.module);
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    try { return await MethodChannel('$channelPrefix/$module').invokeMethod<T>(method, args); }
    on PlatformException catch (e) { throw StateError('$module: ${e.message}'); }
    on MissingPluginException { throw StateError('$module unavailable on this platform'); }
  }
  Stream<dynamic> get events => EventChannel('$channelPrefix/$module/events').receiveBroadcastStream();
}
