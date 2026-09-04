// Smoke test to run ON THE F10 device to verify hardware integrations.
//   flutter test integration_test/f10_smoke_test.dart -d <F10-id>
//
// Verifies, on real hardware:
//   1. The F10 door relay is reachable (PosUtil resolves) and clicks.
//   2. The MobileFaceNet TFLite model loads without OOM on the Snapdragon 625.
//
// This file is a dev/verification aid, not part of the app.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kiwi_kigo/core/services/f10_door_service.dart';
import 'package:kiwi_kigo/core/services/sound_service.dart';
import 'package:kiwi_kigo/features/trust/data/face_embedder.dart';
import 'package:kiwi_kigo/features/voice/data/voice_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('F10 door relay is available and opens (audible click)', () async {
    const service = F10DoorService();

    final available = await service.isAvailable();
    // On the F10 this must be true; on emulator it would be false.
    expect(available, isTrue,
        reason: 'PosUtil should resolve on the F10 device');

    final result = await service.openDoor(hold: const Duration(seconds: 1));
    expect(result.isOpened, isTrue,
        reason: 'setRelayPower(1) should return success (0) on the F10');
  });

  test('F10 status LED turns on and off (watch the device)', () async {
    const service = F10DoorService();
    // Brightness 200 is the calibrated sweet spot on the F10.
    final on = await service.setLed(true, brightness: 200);
    expect(on, isTrue, reason: 'setLedLight(200) should succeed on the F10');
    await Future.delayed(const Duration(seconds: 2));
    final off = await service.setLed(false);
    expect(off, isTrue, reason: 'setLedLight(0) should succeed on the F10');
  });

  test('F10 color LED red/green via controlLedBright (SAFE, watch device)', () async {
    const service = F10DoorService();
    // Official F10 manual: controlLedBright(type, progress). type 0=red 1=green.
    // Same safe call family as the white LED — NOT setColorLed (which crashes).
    // ignore: avoid_print
    print('>>> ROJO 2s');
    expect(await service.setLedColor(F10LedColor.red, brightness: 200), isTrue);
    await Future.delayed(const Duration(seconds: 2));
    await service.setLedColor(F10LedColor.red, brightness: 0);
    await Future.delayed(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('>>> VERDE 2s');
    expect(await service.setLedColor(F10LedColor.green, brightness: 200), isTrue);
    await Future.delayed(const Duration(seconds: 2));
    await service.ledOff();
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('Success sound plays on the F10 (listen)', () async {
    final sound = SoundService();
    // ignore: avoid_print
    print('>>> ESCUCHA el F10: sonido de éxito');
    await sound.playSuccess();
    await Future.delayed(const Duration(seconds: 3));
    sound.dispose();
    expect(true, isTrue); // audible check — no assert on playback internals
  });

  test('MobileFaceNet TFLite model loads on-device', () async {
    final embedder = FaceEmbedder();
    await embedder.ensureLoaded();
    expect(embedder.isReady, isTrue,
        reason: 'Interpreter.fromAsset should load mobilefacenet.tflite');
    embedder.dispose();
  });

  test('On-device speech-to-text initializes on the F10', () async {
    final voice = VoiceService();
    final ok = await voice.init();
    // The F10 has GoogleRecognitionService, so STT should initialize.
    expect(ok, isTrue,
        reason: 'speech_to_text should initialize on a device with a '
            'recognition service (verified: GoogleRecognitionService present)');
    voice.dispose();
  });

  test('Text-to-speech engine is available on the F10', () async {
    final voice = VoiceService();
    await voice.init();
    // After installing Google TTS, the assistant can speak aloud.
    expect(voice.canSpeak, isTrue,
        reason: 'A TTS engine (Google TTS) should be available so the '
            'assistant speaks the prompts');
    await voice.speak('Prueba de voz de Kigo Welcome');
    voice.dispose();
  });
}
