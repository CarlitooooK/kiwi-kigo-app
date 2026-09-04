import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application environment configuration.
/// Reads values from .env file loaded at startup.
class EnvConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // --- Kigo Notifications API (host push) ---
  static String get notificationsApiKey =>
      dotenv.env['KIGO_NOTIFICATIONS_API_KEY'] ?? '';
  static String get notificationsBaseUrl =>
      dotenv.env['KIGO_NOTIFICATIONS_BASE_URL'] ??
      'https://api.kigo.pro/notifications';
  static String get notificationsSubtypeId =>
      dotenv.env['KIGO_NOTIFICATIONS_SUBTYPE_ID'] ?? '';

  /// Fixed test host (a real Kigo app user) used during the demo so the push
  /// actually lands on a device. 0 = not configured.
  static int get testHostLegacyUserId =>
      int.tryParse(dotenv.env['KIGO_TEST_HOST_LEGACY_USER_ID'] ?? '') ?? 0;

  static bool get notificationsConfigured =>
      notificationsApiKey.isNotEmpty && notificationsSubtypeId.isNotEmpty;

  // --- Kigo Verify — Face Enrollment ---
  static String get verifyApiKey => dotenv.env['KIGO_VERIFY_API_KEY'] ?? '';
  static String get verifyBaseUrl =>
      dotenv.env['KIGO_VERIFY_BASE_URL'] ?? 'https://verify-api.kigo.dev';

  /// Kill switch for Kigo Verify. When 'false' we skip creating remote
  /// enrollments (on-device enrollment still works) — useful during testing so
  /// we don't pollute the Verify project. Defaults to enabled.
  static bool get verifyEnabled =>
      (dotenv.env['KIGO_VERIFY_ENABLED'] ?? 'true').toLowerCase() != 'false';

  static bool get verifyConfigured => verifyApiKey.isNotEmpty && verifyEnabled;
}
