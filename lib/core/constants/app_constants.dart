/// Application-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Kigo Welcome';
  static const String appVersion = '0.1.0';

  // Visitor types
  static const String typeVisitor = 'VISITOR';
  static const String typeClient = 'CLIENT';
  static const String typeProvider = 'PROVIDER';
  static const String typeMaintenance = 'MAINTENANCE';
  static const String typeDelivery = 'DELIVERY';
  static const String typeInterview = 'INTERVIEW';
  static const String typeOther = 'OTHER';

  static const List<String> visitorTypes = [
    typeVisitor,
    typeClient,
    typeProvider,
    typeMaintenance,
    typeDelivery,
    typeInterview,
    typeOther,
  ];

  // Visit sources
  static const String sourceKigoApp = 'KIGO_APP';
  static const String sourceKiosk = 'KIOSK';
  static const String sourceManual = 'MANUAL';

  // Visit statuses
  static const String statusPending = 'PENDING';
  static const String statusPreAuthorized = 'PRE_AUTHORIZED';
  static const String statusInProgress = 'IN_PROGRESS';
  static const String statusCheckedIn = 'CHECKED_IN';
  static const String statusActive = 'ACTIVE';
  static const String statusCompleted = 'COMPLETED';
  static const String statusRejected = 'REJECTED';
  static const String statusCancelled = 'CANCELLED';

  // Access decisions
  static const String decisionGranted = 'GRANTED';
  static const String decisionDenied = 'DENIED';
  static const String decisionRequiresHost = 'REQUIRES_HOST';
  static const String decisionManualReview = 'MANUAL_REVIEW';

  // Roles
  static const String roleAdmin = 'ADMIN';
  static const String roleHost = 'HOST';
  static const String roleReception = 'RECEPTION';

  // Trust score thresholds (configurable per org)
  static const double defaultTrustThreshold = 70.0;

  // Timeouts
  static const Duration hostResponseTimeout = Duration(minutes: 5);
}
