import 'package:flutter/services.dart';

/// Android side: Termux RUN_COMMAND, foreground service and storage access.
class Native {
  static const _channel = MethodChannel('claude_go/native');

  static Future<bool> termuxInstalled() async =>
      (await _channel.invokeMethod<bool>('termuxInstalled')) ?? false;

  static Future<bool> hasTermuxPermission() async =>
      (await _channel.invokeMethod<bool>('hasTermuxPermission')) ?? false;

  static Future<bool> requestTermuxPermission() async =>
      (await _channel.invokeMethod<bool>('requestTermuxPermission')) ?? false;

  static Future<void> runTermux(
    String command, {
    bool background = true,
  }) =>
      _channel.invokeMethod('runTermux', {
        'command': command,
        'background': background,
      });

  static Future<void> startProtection() =>
      _channel.invokeMethod('startProtection');

  static Future<void> stopProtection() =>
      _channel.invokeMethod('stopProtection');

  static Future<bool> isIgnoringBatteryOptimizations() async =>
      (await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations')) ??
      false;

  static Future<void> requestIgnoreBatteryOptimizations() =>
      _channel.invokeMethod('requestIgnoreBatteryOptimizations');

  static Future<bool> isExternalStorageManager() async =>
      (await _channel.invokeMethod<bool>('isExternalStorageManager')) ?? false;

  static Future<void> requestExternalStorage() =>
      _channel.invokeMethod('requestExternalStorage');

  static Future<void> openUrl(String url) =>
      _channel.invokeMethod('openUrl', {'url': url});
}
