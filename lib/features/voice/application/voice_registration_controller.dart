import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../data/voice_parser.dart';
import '../data/voice_service.dart';
import 'voice_registration_state.dart';

/// Drives the on-device, voice-guided registration conversation.
///
/// Flow: greeting → purpose → name → phone → host → detail → confirm.
/// Each step speaks a prompt, listens once, parses the answer locally, and
/// re-asks on failure. Touch input remains available in the UI at all times as
/// the mandatory fallback (PRD: voice is an enhancement, not a requirement).
class VoiceRegistrationController extends StateNotifier<VoiceRegistrationState> {
  final VoiceService _voice;

  VoiceRegistrationController(this._voice)
      : super(const VoiceRegistrationState());

  int _retries = 0;
  static const _maxRetries = 2;

  /// Starts the conversation. Falls back to touch if voice is unavailable.
  Future<void> start() async {
    final ok = await _voice.init();
    if (!ok) {
      state = state.copyWith(
        step: VoiceStep.fallback,
        prompt: 'La voz no está disponible. Puedes registrarte con la pantalla.',
      );
      return;
    }
    await _goToPurpose(greet: true);
  }

  // --- Steps ---

  Future<void> _goToPurpose({bool greet = false}) async {
    _retries = 0;
    const q = 'Bienvenido a Kigo. ¿Cuál es el motivo de tu visita? '
        'Por ejemplo: cliente, proveedor, entrevista o entrega.';
    state = state.copyWith(step: VoiceStep.askPurpose, prompt: q, clearHeard: true);
    await _say(q);
    await _capturePurpose();
  }

  Future<void> _capturePurpose() async {
    final heard = await _hear();
    if (heard == null) return _retry(_capturePurpose, 'No te escuché.');
    final type = VoiceParser.visitorType(heard);
    if (type == null) {
      return _retry(_capturePurpose,
          'No identifiqué el motivo. Di cliente, proveedor, entrevista, mantenimiento o entrega.');
    }
    state = state.copyWith(visitorType: type, heardText: heard);
    if (!mounted) return;
    await _goToName();
  }

  Future<void> _goToName() async {
    _retries = 0;
    const q = '¿Cuál es tu nombre completo?';
    state = state.copyWith(step: VoiceStep.askName, prompt: q, clearHeard: true);
    await _say(q);
    await _captureName();
  }

  Future<void> _captureName() async {
    final heard = await _hear();
    if (heard == null || heard.trim().isEmpty) {
      return _retry(_captureName, 'No escuché tu nombre.');
    }
    final clean = VoiceParser.cleanName(heard);
    final split = VoiceParser.splitName(clean);
    if (split.first.isEmpty) {
      return _retry(_captureName, 'No entendí tu nombre, ¿me lo repites?');
    }
    state = state.copyWith(
      firstName: split.first,
      lastName: split.last,
      heardText: heard,
    );
    await _goToPhone();
  }

  Future<void> _goToPhone() async {
    _retries = 0;
    const q = '¿Cuál es tu número de celular? Dilo dígito por dígito.';
    state = state.copyWith(step: VoiceStep.askPhone, prompt: q, clearHeard: true);
    await _say(q);
    await _capturePhone();
  }

  Future<void> _capturePhone() async {
    final heard = await _hear();
    if (heard == null || heard.trim().isEmpty) {
      return _retry(_capturePhone, 'No escuché tu número.');
    }
    final phone = VoiceParser.phone(heard);
    if (phone == null) {
      return _retry(_capturePhone,
          'No entendí tu número. Dime los diez dígitos de tu celular, uno por uno.');
    }
    state = state.copyWith(phone: phone, heardText: heard);
    if (!mounted) return;
    await _goToHost();
  }

  Future<void> _goToHost() async {
    _retries = 0;
    const q = '¿A quién visitas?';
    state = state.copyWith(step: VoiceStep.askHost, prompt: q, clearHeard: true);
    await _say(q);
    await _captureHost();
  }

  Future<void> _captureHost() async {
    final heard = await _hear();
    if (heard == null || heard.trim().isEmpty) {
      return _retry(_captureHost, 'No escuché a quién visitas.');
    }
    state = state.copyWith(hostName: VoiceParser.cleanName(heard), heardText: heard);
    await _goToDetail();
  }

  Future<void> _goToDetail() async {
    _retries = 0;
    final isProviderLike = state.visitorType == AppConstants.typeProvider ||
        state.visitorType == AppConstants.typeMaintenance ||
        state.visitorType == AppConstants.typeDelivery;
    final q = isProviderLike
        ? '¿De qué empresa vienes?'
        : '¿Cuál es el asunto de tu visita?';
    state = state.copyWith(step: VoiceStep.askDetail, prompt: q, clearHeard: true);
    await _say(q);
    await _captureDetail();
  }

  Future<void> _captureDetail() async {
    final heard = await _hear();
    // Detail is optional — accept empty and move on rather than blocking.
    if (heard != null && heard.trim().isNotEmpty) {
      state = state.copyWith(detail: VoiceParser.cleanText(heard), heardText: heard);
    }
    await _goToConfirm();
  }

  Future<void> _goToConfirm() async {
    final summary = _buildSummary();
    state = state.copyWith(
        step: VoiceStep.confirm, prompt: summary, clearHeard: true);
    await _say('$summary. ¿Es correcto?');
    await _captureConfirm();
  }

  Future<void> _captureConfirm() async {
    final heard = await _hear();
    final answer = heard == null ? null : VoiceParser.yesNo(heard);
    if (answer == true) {
      state = state.copyWith(step: VoiceStep.done, heardText: heard);
      await _say('Perfecto. Continuemos con tu identificación.');
    } else if (answer == false) {
      // Don't restart the whole conversation — hand off to the touch form with
      // everything we captured prefilled, so the visitor fixes only what's
      // wrong. The screen listens for VoiceStep.correct and navigates there.
      await _say('De acuerdo, revisa y corrige tus datos en la pantalla.');
      if (!mounted) return;
      state = state.copyWith(step: VoiceStep.correct, heardText: heard);
    } else {
      return _retry(_captureConfirm, 'Responde sí o no, por favor.');
    }
  }

  String _buildSummary() {
    final parts = <String>[];
    if (state.hasName) parts.add('Nombre ${state.fullName}');
    if ((state.phone ?? '').isNotEmpty) parts.add('celular ${_spacedDigits(state.phone!)}');
    if ((state.hostName ?? '').isNotEmpty) parts.add('visita a ${state.hostName}');
    if ((state.detail ?? '').isNotEmpty) parts.add(state.detail!);
    return 'Registré: ${parts.join(', ')}';
  }

  /// Reads a phone number digit-by-digit so TTS says "2 2 1…" not "two hundred".
  String _spacedDigits(String digits) => digits.split('').join(' ');

  // --- Manual overrides (touch fallback edits the fields) ---

  void setField({String? firstName, String? lastName, String? hostName, String? detail, String? visitorType}) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      hostName: hostName,
      detail: detail,
      visitorType: visitorType,
    );
  }

  /// Builds the flowData map consumed by the rest of the kiosk flow.
  Map<String, dynamic> toFlowData() => {
        'visitor_type': state.visitorType ?? AppConstants.typeVisitor,
        'first_name': state.firstName ?? '',
        'last_name': state.lastName ?? '',
        'host_name_manual': state.hostName ?? '',
        'detail': state.detail ?? '',
        'phone': state.phone ?? '',
        'source_voice': true,
      };

  // --- Voice helpers ---

  Future<void> _say(String text) async {
    if (!mounted) return;
    state = state.copyWith(speaking: true);
    if (_voice.canSpeak) {
      await _voice.speak(text);
    } else {
      // No TTS engine: give the visitor time to READ the prompt on screen
      // before we start listening. ~55ms per char, clamped 1.6–5s.
      final ms = (text.length * 55).clamp(1600, 5000);
      await Future.delayed(Duration(milliseconds: ms));
    }
    if (!mounted) return;
    state = state.copyWith(speaking: false);
  }

  Future<String?> _hear() async {
    if (!mounted) return null;
    state = state.copyWith(listening: true, clearHeard: true);
    final result = await _voice.listenOnce();
    if (!mounted) return null;
    state = state.copyWith(listening: false);
    return result;
  }

  Future<void> _retry(Future<void> Function() step, String message) async {
    if (!mounted) return;
    _retries++;
    if (_retries > _maxRetries) {
      state = state.copyWith(
        step: VoiceStep.fallback,
        prompt: 'Mejor completemos tu registro con la pantalla.',
      );
      await _say('Mejor completemos tu registro con la pantalla.');
      return;
    }
    await _say(message);
    if (!mounted) return;
    await step();
  }

  @override
  void dispose() {
    _voice.stop();
    super.dispose();
  }

  void cancel() {
    _voice.stop();
  }
}

final voiceRegistrationControllerProvider = StateNotifierProvider.autoDispose<
    VoiceRegistrationController, VoiceRegistrationState>((ref) {
  return VoiceRegistrationController(ref.watch(voiceServiceProvider));
});
