import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the Supabase client instance.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
