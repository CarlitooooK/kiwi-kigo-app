import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';

/// Provides list of available hosts for a given organization.
/// Used in the new visitor registration form for host selection.
final hostsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, organizationId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('profiles')
        .select('id, full_name, email, role')
        .eq('organization_id', organizationId)
        .inFilter('role', ['HOST', 'ADMIN', 'RECEPTION'])
        .order('full_name');
    return List<Map<String, dynamic>>.from(response);
  },
);
