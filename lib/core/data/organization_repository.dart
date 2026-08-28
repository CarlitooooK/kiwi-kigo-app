import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_provider.dart';

/// Repository for organization data.
class OrganizationRepository {
  final SupabaseClient _client;

  OrganizationRepository(this._client);

  /// Fetches organization by ID.
  Future<Map<String, dynamic>?> getById(String id) async {
    final response = await _client
        .from('organizations')
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  /// Fetches the demo organization.
  Future<Map<String, dynamic>?> getDemo() async {
    return getById('a0000000-0000-0000-0000-000000000001');
  }
}

/// Provider for OrganizationRepository.
final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(ref.watch(supabaseProvider));
});
