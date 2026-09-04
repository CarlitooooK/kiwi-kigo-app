import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kiosk (lock task) control for the F10.
///
/// Pins the app so a visitor cannot leave it. On a device-owner F10 this fully
/// locks the device to the app; otherwise Android uses standard screen pinning.
/// No-op on non-Android platforms and degrades safely if unsupported.
class KioskService {
  static const MethodChannel _channel = MethodChannel('kigo.welcome/kiosk');

  const KioskService();

  Future<bool> start() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on PlatformException catch (e) {
      debugPrint('KioskService.start error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> stop() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('stop') ?? false;
    } on PlatformException catch (e) {
      debugPrint('KioskService.stop error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

final kioskServiceProvider = Provider<KioskService>((ref) {
  return const KioskService();
});
