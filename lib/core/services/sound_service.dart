import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays short feedback cues (success / error) on the kiosk.
///
/// Sounds are bundled assets (WAV) reused from the Kigo bus POS app. Playback
/// is best-effort: any failure (no audio output, asset missing) is swallowed so
/// it never blocks or crashes the visitor flow.
class SoundService {
  // A dedicated low-latency player. `AudioPlayer` handles its own resources.
  final AudioPlayer _player = AudioPlayer(playerId: 'kigo_welcome_sfx');

  SoundService() {
    // Stop mode: release the source after playing so the next cue starts clean.
    _player.setReleaseMode(ReleaseMode.stop);
  }

  /// Success cue — plays when access is granted / the flow completes.
  Future<void> playSuccess() => _play('sounds/success.wav');

  /// Error cue — plays on denial / failure.
  Future<void> playError() => _play('sounds/error.wav');

  Future<void> _play(String asset) async {
    try {
      // AssetSource resolves under the app's `assets/` bundle root.
      await _player.stop();
      await _player.play(AssetSource(asset), volume: 1.0);
    } catch (e) {
      debugPrint('SoundService: failed to play $asset: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}

/// Shared sound service.
final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});
