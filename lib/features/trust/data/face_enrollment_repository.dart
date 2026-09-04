import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';

/// A stored face enrollment (row of `face_enrollments`).
class FaceEnrollment {
  final String id;
  final String visitorId;
  final Float32List embedding;
  final bool isRecurrent;
  final Map<String, dynamic>? visitor; // joined visitors(*) when available

  FaceEnrollment({
    required this.id,
    required this.visitorId,
    required this.embedding,
    required this.isRecurrent,
    this.visitor,
  });

  static Float32List _toEmbedding(dynamic raw) {
    if (raw is List) {
      return Float32List.fromList(
        raw.map((e) => (e as num).toDouble()).toList().cast<double>(),
      );
    }
    return Float32List(0);
  }

  factory FaceEnrollment.fromRow(Map<String, dynamic> row) => FaceEnrollment(
        id: row['id'] as String,
        visitorId: row['visitor_id'] as String,
        embedding: _toEmbedding(row['embedding']),
        isRecurrent: row['is_recurrent'] == true,
        visitor: row['visitors'] as Map<String, dynamic>?,
      );
}

/// Persists and queries on-device face embeddings for recognition.
class FaceEnrollmentRepository {
  final SupabaseClient _client;
  FaceEnrollmentRepository(this._client);

  static const _org = 'a0000000-0000-0000-0000-000000000001';

  /// Saves (or replaces) the face embedding for a visitor. One enrollment per
  /// visitor: if one exists we update it with the fresh embedding.
  Future<void> enroll({
    required String visitorId,
    required Float32List embedding,
    String? photoPath,
    String? kigoEnrollmentId,
    String? kigoStatus,
  }) async {
    final existing = await _client
        .from('face_enrollments')
        .select('id')
        .eq('visitor_id', visitorId)
        .maybeSingle();

    final payload = <String, dynamic>{
      'visitor_id': visitorId,
      'organization_id': _org,
      'embedding': embedding.toList(),
    };
    if (photoPath != null) payload['photo_path'] = photoPath;
    if (kigoEnrollmentId != null) payload['kigo_enrollment_id'] = kigoEnrollmentId;
    if (kigoStatus != null) payload['kigo_status'] = kigoStatus;

    if (existing != null) {
      await _client
          .from('face_enrollments')
          .update(payload)
          .eq('id', existing['id']);
    } else {
      await _client.from('face_enrollments').insert(payload);
    }
  }

  /// All enrollments for the org, with the joined visitor (for autofill/greeting).
  Future<List<FaceEnrollment>> getAll() async {
    final rows = await _client
        .from('face_enrollments')
        .select('*, visitors(*)')
        .eq('organization_id', _org)
        .limit(500);
    return (rows as List)
        .map((r) => FaceEnrollment.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Marks a visitor as recurrent (only the HOST does this, after checkout).
  Future<void> markRecurrent(String visitorId, bool recurrent) async {
    await _client
        .from('face_enrollments')
        .update({'is_recurrent': recurrent})
        .eq('visitor_id', visitorId);
  }
}

final faceEnrollmentRepositoryProvider =
    Provider<FaceEnrollmentRepository>((ref) {
  return FaceEnrollmentRepository(ref.read(supabaseProvider));
});
