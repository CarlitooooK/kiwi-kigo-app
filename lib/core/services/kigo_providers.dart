// Abstract interfaces for Kigo ecosystem integration.
//
// These will initially be implemented with Supabase.
// When real Kigo APIs are available, swap implementations without
// touching any feature code.

/// Provides pre-registered visit information from Kigo ecosystem.
abstract class KigoVisitProvider {
  /// Finds a pre-registered visit by identifier (phone, email, or code).
  Future<Map<String, dynamic>?> findPreRegisteredVisit(String identifier);
}

/// Provides host-related operations.
abstract class KigoHostProvider {
  /// Notifies a host about a pending visitor.
  Future<void> notifyHost({
    required String hostId,
    required String visitId,
    required Map<String, dynamic> visitorInfo,
  });
}

/// Provides access control operations.
abstract class KigoAccessProvider {
  /// Signals that access has been granted for a visit.
  Future<void> grantAccess(String visitId);

  /// Signals that access has been denied for a visit.
  Future<void> denyAccess(String visitId, String reason);
}
