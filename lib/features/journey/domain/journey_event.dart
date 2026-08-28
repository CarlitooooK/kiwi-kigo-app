import 'package:equatable/equatable.dart';

/// Types of events in the Visitor Journey.
enum JourneyEventType {
  visitCreated,
  visitorArrived,
  identityValidated,
  evidenceProcessed,
  trustEvaluated,
  accessRequested,
  hostNotified,
  hostApproved,
  hostRejected,
  autoAuthorized,
  checkedIn,
  checkedOut,
  escalated,
}

/// Extension to get the string value for storage.
extension JourneyEventTypeExt on JourneyEventType {
  String get value {
    switch (this) {
      case JourneyEventType.visitCreated:
        return 'VISIT_CREATED';
      case JourneyEventType.visitorArrived:
        return 'VISITOR_ARRIVED';
      case JourneyEventType.identityValidated:
        return 'IDENTITY_VALIDATED';
      case JourneyEventType.evidenceProcessed:
        return 'EVIDENCE_PROCESSED';
      case JourneyEventType.trustEvaluated:
        return 'TRUST_EVALUATED';
      case JourneyEventType.accessRequested:
        return 'ACCESS_REQUESTED';
      case JourneyEventType.hostNotified:
        return 'HOST_NOTIFIED';
      case JourneyEventType.hostApproved:
        return 'HOST_APPROVED';
      case JourneyEventType.hostRejected:
        return 'HOST_REJECTED';
      case JourneyEventType.autoAuthorized:
        return 'AUTO_AUTHORIZED';
      case JourneyEventType.checkedIn:
        return 'CHECKED_IN';
      case JourneyEventType.checkedOut:
        return 'CHECKED_OUT';
      case JourneyEventType.escalated:
        return 'ESCALATED';
    }
  }

  String get displayLabel {
    switch (this) {
      case JourneyEventType.visitCreated:
        return 'Visita creada';
      case JourneyEventType.visitorArrived:
        return 'Visitante llegó';
      case JourneyEventType.identityValidated:
        return 'Identidad validada';
      case JourneyEventType.evidenceProcessed:
        return 'Evidencia procesada';
      case JourneyEventType.trustEvaluated:
        return 'Evaluación completada';
      case JourneyEventType.accessRequested:
        return 'Acceso solicitado';
      case JourneyEventType.hostNotified:
        return 'Anfitrión notificado';
      case JourneyEventType.hostApproved:
        return 'Autorizado por anfitrión';
      case JourneyEventType.hostRejected:
        return 'Rechazado por anfitrión';
      case JourneyEventType.autoAuthorized:
        return 'Autorizado automáticamente';
      case JourneyEventType.checkedIn:
        return 'Check-in';
      case JourneyEventType.checkedOut:
        return 'Check-out';
      case JourneyEventType.escalated:
        return 'Escalado';
    }
  }
}

/// A single event in the Visitor Journey timeline.
class JourneyEvent extends Equatable {
  final String id;
  final String visitId;
  final JourneyEventType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const JourneyEvent({
    required this.id,
    required this.visitId,
    required this.type,
    this.payload = const {},
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, visitId, type, createdAt];
}
