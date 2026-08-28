import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_provider.dart';

/// Repository for Visitor Journey events.
class JourneyRepository {
  final SupabaseClient _client;

  JourneyRepository(this._client);

  /// Logs a journey event.
  Future<void> logEvent({
    required String visitId,
    required String eventType,
    Map<String, dynamic> payload = const {},
  }) async {
    await _client.from('visitor_journey_events').insert({
      'visit_id': visitId,
      'event_type': eventType,
      'payload': payload,
    });
  }

  /// Gets all journey events for a visit, ordered by time.
  Future<List<Map<String, dynamic>>> getJourney(String visitId) async {
    final response = await _client
        .from('visitor_journey_events')
        .select()
        .eq('visit_id', visitId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }
}

/// Provider for JourneyRepository.
final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return JourneyRepository(ref.watch(supabaseProvider));
});
