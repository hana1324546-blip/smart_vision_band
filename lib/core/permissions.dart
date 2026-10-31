import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
Future<void> requestRequiredPermissions() async {
  if (!Platform.isAndroid) throw UnsupportedError('Android only');
  // permission_handler handles permissions not applicable to the OS version.
  await [Permission.bluetoothConnect, Permission.bluetoothScan,
    Permission.notification, Permission.microphone,
    Permission.locationWhenInUse].request();
  // USB grants are separate: UVCAndroid must request per-device permission.
}
