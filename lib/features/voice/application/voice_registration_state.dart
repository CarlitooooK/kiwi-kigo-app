import 'package:flutter/foundation.dart';

/// The ordered steps of the voice-guided registration conversation.
enum VoiceStep {
  idle,
  greeting,
  askPurpose,
  askName,
  askPhone,
  askHost,
  askDetail, // purpose text / company, depending on visitor type
  confirm,
  submitting,
  done,
  correct, // visitor said the data is wrong → hand off to prefilled touch form
  fallback, // voice unavailable or failed → hand off to touch
}

/// Immutable state of the voice registration flow.
@immutable
class VoiceRegistrationState {
  final VoiceStep step;
  final bool listening;
  final bool speaking;

  /// The prompt currently shown/spoken to the visitor.
  final String prompt;

  /// The last thing the visitor said (for on-screen feedback).
  final String? heardText;

  /// Collected fields.
  final String? visitorType;
  final String? firstName;
  final String? lastName;
  final String? hostName;
  final String? detail; // purpose or company
  final String? phone;

  final String? errorMessage;

  const VoiceRegistrationState({
    this.step = VoiceStep.idle,
    this.listening = false,
    this.speaking = false,
    this.prompt = '',
    this.heardText,
    this.visitorType,
    this.firstName,
    this.lastName,
    this.hostName,
    this.detail,
    this.phone,
    this.errorMessage,
  });

  VoiceRegistrationState copyWith({
    VoiceStep? step,
    bool? listening,
    bool? speaking,
    String? prompt,
    String? heardText,
    String? visitorType,
    String? firstName,
    String? lastName,
    String? hostName,
    String? detail,
    String? phone,
    String? errorMessage,
    bool clearHeard = false,
    bool clearError = false,
  }) {    return VoiceRegistrationState(
      step: step ?? this.step,
      listening: listening ?? this.listening,
      speaking: speaking ?? this.speaking,
      prompt: prompt ?? this.prompt,
      heardText: clearHeard ? null : (heardText ?? this.heardText),
      visitorType: visitorType ?? this.visitorType,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      hostName: hostName ?? this.hostName,
      detail: detail ?? this.detail,
      phone: phone ?? this.phone,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get hasName => (firstName ?? '').isNotEmpty;

  /// Full name for confirmation read-back.
  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
}
