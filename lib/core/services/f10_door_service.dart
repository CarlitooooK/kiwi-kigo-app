import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridge to the Telpo F10 access-control hardware (door relay).
///
/// Talks to the native side (`MainActivity.kt`) over a [MethodChannel].
/// On non-F10 devices (emulator, dev laptop, other phones) the native side
/// reports the hardware as unavailable and every call resolves to a safe
/// no-op result, so the visitor flow never crashes off-device.
///
/// The Trust Score / Access Policy decides WHETHER to grant access; this
/// service only performs the physical action once access is granted.
class F10DoorService {
  static const MethodChannel _channel = MethodChannel('kigo.welcome/f10_door');

  const F10DoorService();

  /// Whether the F10 door hardware (PosUtil) is present on this device.
  /// Always false on non-Android platforms.
  Future<bool> isAvailable() async {
    if (!_isAndroid) return false;
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } on PlatformException catch (e) {
      debugPrint('F10DoorService.isAvailable error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the door relay. If [hold] is provided, the relay closes again
  /// automatically after that duration (visitor walks through, relay resets).
  ///
  /// Returns a [DoorResult] describing the outcome so the UI can show an
  /// honest state (opened / hardware unavailable / error) instead of lying.
  Future<DoorResult> openDoor({Duration? hold}) async {
    if (!_isAndroid) {
      return const DoorResult.unavailable();
    }
    try {
      final ok = await _channel.invokeMethod<bool>('openDoor', {
        'holdMs': hold?.inMilliseconds ?? 0,
      });
      return (ok ?? false)
          ? const DoorResult.opened()
          : const DoorResult.error('El relé no respondió');
    } on PlatformException catch (e) {
      // RELAY_ERROR from native — hardware present but call failed.
      debugPrint('F10DoorService.openDoor error: ${e.code} ${e.message}');
      return DoorResult.error(e.message ?? 'Error del relé');
    } on MissingPluginException {
      return const DoorResult.unavailable();
    }
  }

  /// Closes the door relay explicitly.
  Future<void> closeDoor() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('closeDoor');
    } on PlatformException catch (e) {
      debugPrint('F10DoorService.closeDoor error: ${e.message}');
    } on MissingPluginException {
      // no-op off-device
    }
  }

  /// Turns the F10 status LED on/off (nice visual feedback on success).
  /// [brightness] (0–255) sets the intensity when on; 200 is the sweet spot
  /// on the F10. No-op off-device. Returns whether the call succeeded.
  Future<bool> setLed(bool on, {int brightness = 200}) async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setLed', {
        'on': on,
        'brightness': brightness,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('F10DoorService.setLed error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Sets a color LED using PosUtil.controlLedBright(type, progress) — the
  /// official F10 API. [color]: red/green/blue/white. [brightness] 0 turns off.
  /// Safe (same call family as the white LED; NOT the crashing setColorLed).
  Future<bool> setLedColor(F10LedColor color, {int brightness = 200}) async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setLedColor', {
        'type': color.type,
        'progress': brightness,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('F10DoorService.setLedColor error: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Turns off all color LEDs (progress 0 on each channel).
  Future<void> ledOff() async {
    for (final c in F10LedColor.values) {
      await setLedColor(c, brightness: 0);
    }
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

/// F10 color LED channels (per the F10 SDK manual: controlLedBright type).
enum F10LedColor {
  red(0),
  green(1),
  blue(2),
  white(3);

  final int type;
  const F10LedColor(this.type);
}

/// Outcome of a door-open attempt.
@immutable
class DoorResult {
  final DoorStatus status;
  final String? message;

  const DoorResult._(this.status, [this.message]);

  const DoorResult.opened() : this._(DoorStatus.opened);
  const DoorResult.unavailable() : this._(DoorStatus.unavailable);
  const DoorResult.error(String message) : this._(DoorStatus.error, message);

  bool get isOpened => status == DoorStatus.opened;
  bool get isUnavailable => status == DoorStatus.unavailable;
  bool get isError => status == DoorStatus.error;
}

enum DoorStatus { opened, unavailable, error }

/// Provider for the F10 door service.
final f10DoorServiceProvider = Provider<F10DoorService>((ref) {
  return const F10DoorService();
});

/// Whether the F10 door hardware is available on this device (async, cached).
final f10DoorAvailableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(f10DoorServiceProvider).isAvailable();
});
