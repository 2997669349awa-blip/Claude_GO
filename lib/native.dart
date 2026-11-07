import 'package:flutter/services.dart';

/// Android side: embedded runtime, foreground service and storage access.
class Native {
  static const _channel = MethodChannel('claude_go/native');

  static Future<Map<String, dynamic>> runtimeStatus() async {
    final value = await _channel.invokeMethod<Map>('runtimeStatus');
    return (value ?? const {}).cast<String, dynamic>();
  }

  static Future<void> installRuntime() =>
      _channel.invokeMethod('installRuntime');

  static Future<void> installClaudeCode() =>
      _channel.invokeMethod('installClaudeCode');

  static Future<void> startBridge(String token) =>
      _channel.invokeMethod('startBridge', {'token': token});

  static Future<void> stopBridge() => _channel.invokeMethod('stopBridge');

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
