import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_provider.dart';

/// Repository for visit operations.
class VisitRepository {
  final SupabaseClient _client;

  VisitRepository(this._client);

  /// Creates a new visitor record.
  Future<Map<String, dynamic>> createVisitor({
    required String firstName,
    required String lastName,
    required String organizationId,
    String? company,
    String? email,
    String? phone,
    String visitorType = 'VISITOR',
  }) async {
    final response = await _client.from('visitors').insert({
      'first_name': firstName,
      'last_name': lastName,
      'organization_id': organizationId,
      'company': company,
      'email': email,
      'phone': phone,
      'visitor_type': visitorType,
    }).select().single();
    return response;
  }

  /// Creates a new visit record.
  Future<Map<String, dynamic>> createVisit({
    required String visitorId,
    required String organizationId,
    String? hostId,
    String? purpose,
    String? area,
    String source = 'KIOSK',
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool isPreauthorized = false,
  }) async {
    final response = await _client.from('visits').insert({
      'visitor_id': visitorId,
      'organization_id': organizationId,
      'host_id': hostId,
      'purpose': purpose,
      'area': area,
      'source': source,
      'scheduled_start': scheduledStart?.toIso8601String(),
      'scheduled_end': scheduledEnd?.toIso8601String(),
      'is_preauthorized': isPreauthorized,
    }).select().single();
    return response;
  }

  /// Finds pre-registered visits for a visitor by email or phone.
  Future<List<Map<String, dynamic>>> findPreRegistered({
    String? email,
    String? phone,
    required String organizationId,
  }) async {
    var query = _client
        .from('visits')
        .select('*, visitors!inner(*)')
        .eq('organization_id', organizationId)
        .inFilter('status', ['PENDING', 'PRE_AUTHORIZED']);

    if (email != null) {
      query = query.eq('visitors.email', email);
    } else if (phone != null) {
      query = query.eq('visitors.phone', phone);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  /// Gets visits for an organization (console).
  /// Uses separate queries to avoid join issues with null host_id.
  Future<List<Map<String, dynamic>>> getVisitsByOrganization(
    String organizationId, {
    String? statusFilter,
    int limit = 50,
  }) async {
    var query = _client
        .from('visits')
        .select('*, visitors(*)')
        .eq('organization_id', organizationId);

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Updates visit status.
  Future<void> updateVisitStatus(String visitId, String status) async {
    await _client.from('visits').update({'status': status}).eq('id', visitId);
  }

  /// Check-in: sets checked_in_at and status.
  Future<void> checkIn(String visitId) async {
    await _client.from('visits').update({
      'status': 'ACTIVE',
      'checked_in_at': DateTime.now().toIso8601String(),
    }).eq('id', visitId);
  }

  /// Check-out: sets checked_out_at and status.
  Future<void> checkOut(String visitId) async {
    await _client.from('visits').update({
      'status': 'COMPLETED',
      'checked_out_at': DateTime.now().toIso8601String(),
    }).eq('id', visitId);
  }

  /// Gets a single visit with all related data.
  Future<Map<String, dynamic>?> getVisitDetail(String visitId) async {
    final response = await _client
        .from('visits')
        .select('''
          *,
          visitors(*),
          visit_evidence(*),
          trust_evaluations(*),
          access_decisions(*),
          visitor_journey_events(*)
        ''')
        .eq('id', visitId)
        .maybeSingle();

    if (response == null) return null;

    // Fetch host separately to avoid null FK join issues
    final hostId = response['host_id'] as String?;
    if (hostId != null) {
      final host = await _client
          .from('profiles')
          .select('id, full_name, email, role')
          .eq('id', hostId)
          .maybeSingle();
      response['profiles'] = host;
    }

    return response;
  }
}

/// Provider for VisitRepository.
final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return VisitRepository(ref.watch(supabaseProvider));
});
