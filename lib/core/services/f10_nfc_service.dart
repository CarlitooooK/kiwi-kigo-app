import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridge to the F10's NFC reader (standard Android [NfcAdapter] on the native
/// side). Exposes a broadcast [Stream] of card UIDs (uppercase hex, no
/// separators — e.g. `04A1B2C3`) emitted whenever a card is tapped while the
/// app is in the foreground.
///
/// On non-F10 / non-Android devices the native side simply never emits, so the
/// stream stays silent and nothing breaks off-device.
class F10NfcService {
  static const EventChannel _events = EventChannel('kigo.welcome/f10_nfc');

  const F10NfcService();

  /// Card UIDs as they are tapped. Uppercase hex without separators.
  ///
  /// Resilient by design: if the native EventChannel isn't registered yet
  /// (e.g. running an older APK after a hot restart, or a device without the
  /// native code), the underlying `listen` throws MissingPluginException. We
  /// swallow it here so the Welcome screen keeps working — NFC just stays
  /// silent until a full rebuild installs the native handler.
  Stream<String> get cardStream {
    if (!_isAndroid) return const Stream<String>.empty();
    return _events
        .receiveBroadcastStream()
        .handleError((Object e) {
          debugPrint('F10NfcService: NFC channel unavailable ($e). '
              'Rebuild the APK (native changes need a full build, not hot reload).');
        }, test: (e) => e is MissingPluginException || e is PlatformException)
        .map((e) => (e as String?)?.toUpperCase() ?? '')
        .where((uid) => uid.isNotEmpty)
        .map((uid) {
          // Logged so you can discover a card's UID (paste it into the Welcome
          // screen's demo constant). Visible via `adb logcat` / flutter logs.
          debugPrint('F10NfcService: card UID = $uid');
          return uid;
        });
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

/// Provider for the F10 NFC service.
final f10NfcServiceProvider = Provider<F10NfcService>((ref) {
  return const F10NfcService();
});
