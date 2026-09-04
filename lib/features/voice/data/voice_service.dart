import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// On-device voice I/O for the guided registration.
///
/// Wraps `speech_to_text` (STT) and `flutter_tts` (TTS). Everything runs on the
/// device's own recognition/synthesis engines — no network, no API keys, $0.
/// Spanish (es-MX) by default. Degrades gracefully: if the device has no STT
/// engine or the mic permission is denied, [isAvailable] is false and the UI
/// falls back to touch input.
class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _initialized = false;

  /// Preferred Spanish locale. Used for TTS. For STT we resolve the *actual*
  /// locale the device supports at runtime (see [_sttLocale]) because forcing an
  /// unsupported id (e.g. es-MX on a device set to es-US) makes the recognizer
  /// return `error_language_not_supported` on every listen.
  static const String _locale = 'es-MX';

  /// Locale id passed to the STT engine. Null lets the engine use its default.
  /// Resolved in [init] from the device's supported locales.
  String? _sttLocale;

  bool _ttsReady = false;

  /// Last STT error message reported by the engine (for diagnostics).
  String? lastSttError;

  bool get isAvailable => _sttReady;
  bool get isListening => _stt.isListening;

  /// Whether a working text-to-speech engine is available. When false, the flow
  /// still works: prompts are shown on screen (and STT still listens), we just
  /// don't speak them aloud.
  bool get canSpeak => _ttsReady;

  /// Diagnostics: the STT locale resolved for this device (null = engine default).
  String? get debugLocale => _sttLocale;

  /// Diagnostics: all locale ids the STT engine reports.
  Future<List<String>> debugLocales() async {
    try {
      final locales = await _stt.locales();
      return locales.map((l) => l.localeId).toList();
    } catch (e) {
      return ['<error: $e>'];
    }
  }

  /// Initializes STT + TTS. Safe to call multiple times. Returns whether STT
  /// (the harder requirement) is usable on this device.
  Future<bool> init() async {
    if (_initialized) return _sttReady;
    _initialized = true;

    try {
      _sttReady = await _stt.initialize(
        onError: (e) {
          lastSttError = e.errorMsg;
          debugPrint('VoiceService STT error: ${e.errorMsg}');
        },
        onStatus: (s) => debugPrint('VoiceService STT status: $s'),
      );
      if (_sttReady) {
        _sttLocale = await _resolveSpanishLocale();
        debugPrint('VoiceService: STT locale -> ${_sttLocale ?? "(engine default)"}');
      }
    } catch (e) {
      debugPrint('VoiceService: STT init failed: $e');
      _sttReady = false;
    }

    // Probe TTS: some devices (like the F10) ship without a working TTS engine.
    // Detect it so we never block waiting for a speech that will never play.
    try {
      final engines = await _tts.getEngines;
      if (engines != null && (engines as List).isNotEmpty) {
        await _tts.setLanguage(_locale);
        await _tts.setSpeechRate(0.48); // calm, kiosk-friendly pace
        await _tts.setPitch(1.0);
        await _tts.awaitSpeakCompletion(true);
        _ttsReady = true;
      } else {
        _ttsReady = false;
        debugPrint('VoiceService: no TTS engine available — text-only mode');
      }
    } catch (e) {
      debugPrint('VoiceService: TTS init failed: $e — text-only mode');
      _ttsReady = false;
    }

    return _sttReady;
  }

  /// Picks the best Spanish locale the device's recognizer actually supports.
  /// Order of preference: the system's own Spanish (matches how the recognizer
  /// downloaded its language pack) → es-MX → es-ES → es-US → any es-* → null.
  /// Returning null lets the engine fall back to its own default rather than
  /// forcing an unsupported id (which yields `error_language_not_supported`).
  Future<String?> _resolveSpanishLocale() async {
    try {
      final locales = await _stt.locales();
      if (locales.isEmpty) return null;
      final ids = locales.map((l) => l.localeId.replaceAll('_', '-')).toList();

      bool has(String id) => ids.any((x) => x.toLowerCase() == id.toLowerCase());
      for (final pref in const ['es-US', 'es-MX', 'es-ES', 'es-419']) {
        if (has(pref)) return pref;
      }
      // Any Spanish variant the device has.
      final anyEs = ids.firstWhere(
        (x) => x.toLowerCase().startsWith('es'),
        orElse: () => '',
      );
      return anyEs.isEmpty ? null : anyEs;
    } catch (e) {
      debugPrint('VoiceService: locale resolve failed: $e');
      return null;
    }
  }

  /// Speaks [text]. Completes when playback finishes, or immediately if TTS is
  /// unavailable. Always guarded by a timeout so a misbehaving/absent engine
  /// can never hang the conversation (the F10 has no TTS engine).
  Future<void> speak(String text) async {
    if (!_ttsReady) return; // text-only mode: prompt is shown on screen
    try {
      await _tts.stop();
      await _tts.speak(text).timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              debugPrint('VoiceService: speak timed out');
              return;
            },
          );
    } catch (e) {
      debugPrint('VoiceService: speak failed: $e');
    }
  }

  /// Listens for a single utterance and returns the recognized text (or null).
  /// Retries once automatically if the engine returns nothing (a common
  /// `error_no_match` when the mic opens a hair before the user starts).
  Future<String?> listenOnce({
    Duration maxDuration = const Duration(seconds: 15),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    if (!_sttReady) return null;

    // Small gap so the mic doesn't open while TTS audio is still trailing off
    // and the user has a beat to start speaking.
    await Future.delayed(const Duration(milliseconds: 300));

    var result = await _singleListen(maxDuration, pauseFor);
    if (result != null && result.isNotEmpty) return result;

    // One automatic retry — "a veces no escucha" is usually a too-early cutoff.
    await Future.delayed(const Duration(milliseconds: 250));
    result = await _singleListen(maxDuration, pauseFor);
    return result;
  }

  Future<String?> _singleListen(Duration maxDuration, Duration pauseFor) async {
    final completer = Completer<String?>();
    String lastWords = '';
    Timer? poll;
    Timer? hard;

    void finish() {
      if (!completer.isCompleted) {
        poll?.cancel();
        hard?.cancel();
        completer.complete(lastWords.trim().isEmpty ? null : lastWords.trim());
      }
    }

    try {
      await _stt.listen(
        onResult: (r) {
          if (r.recognizedWords.isNotEmpty) lastWords = r.recognizedWords;
          if (r.finalResult) finish();
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          localeId: _sttLocale,
          listenFor: maxDuration,
          pauseFor: pauseFor,
        ),
      );
    } catch (e) {
      debugPrint('VoiceService: listen failed: $e');
      finish();
    }

    // Return whatever was captured once the engine stops (covers no_match /
    // speech_timeout without hanging).
    poll = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (completer.isCompleted) {
        t.cancel();
        return;
      }
      if (!_stt.isListening) finish();
    });

    hard = Timer(maxDuration + const Duration(seconds: 2), () async {
      try {
        await _stt.stop();
      } catch (_) {}
      finish();
    });

    return completer.future;
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
      await _tts.stop();
    } catch (_) {}
  }

  void dispose() {
    _stt.cancel();
    _tts.stop();
  }
}

/// Shared voice service.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});
