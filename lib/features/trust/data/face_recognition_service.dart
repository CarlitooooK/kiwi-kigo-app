import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'face_embedder.dart';
import 'face_enrollment_repository.dart';
import 'trust_providers.dart';

/// Outcome of a face recognition attempt at the kiosk.
class FaceMatch {
  final FaceEnrollment enrollment;
  final double similarity;
  FaceMatch(this.enrollment, this.similarity);

  bool get isRecurrent => enrollment.isRecurrent;
  Map<String, dynamic>? get visitor => enrollment.visitor;
}

/// Recognizes a face captured at the kiosk against enrolled faces (1:N, but
/// only for CONVENIENCE — autofill or recurrent fast-entry, never as the sole
/// access credential for a stranger).
///
/// Matching is on-device cosine similarity over MobileFaceNet embeddings.
class FaceRecognitionService {
  final FaceEmbedder _embedder;
  final FaceEnrollmentRepository _repo;

  FaceRecognitionService(this._embedder, this._repo);

  /// Similarity threshold for a confident 1:N match. MobileFaceNet same-person
  /// is typically > 0.6; we use 0.62 to reduce false positives.
  static const double _threshold = 0.62;

  /// Captures nothing — takes an already-captured [selfiePath], embeds it, and
  /// returns the best enrolled match above threshold, or null.
  Future<FaceMatch?> recognize(String selfiePath) async {
    final probe = await _embedder.embedFromFile(selfiePath);
    if (probe == null) return null;

    final enrolled = await _repo.getAll();
    FaceMatch? best;
    for (final e in enrolled) {
      if (e.embedding.isEmpty) continue;
      final sim = _embedder.cosineSimilarity(probe, e.embedding);
      if (sim >= _threshold && (best == null || sim > best.similarity)) {
        best = FaceMatch(e, sim);
      }
    }
    return best;
  }
}

final faceRecognitionServiceProvider = Provider<FaceRecognitionService>((ref) {
  return FaceRecognitionService(
    ref.watch(faceEmbedderProvider),
    ref.watch(faceEnrollmentRepositoryProvider),
  );
});
