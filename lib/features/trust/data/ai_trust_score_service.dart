import 'package:flutter/foundation.dart';

import '../domain/trust_score_service.dart';
import 'face_embedder.dart';

/// Real on-device AI Trust Score (engine `AI_V1`).
///
/// The Trust Score measures **registration & evidence quality**, never danger.
/// It combines four signals into a 0–100 quality score and, crucially, uses a
/// real face-recognition model (MobileFaceNet embeddings, cosine similarity)
/// for the ID↔selfie match instead of the old landmark-ratio heuristic.
///
/// Expected [evidenceData] keys:
///   id_image_path      String?  — captured ID photo
///   selfie_path        String?  — captured selfie
///   ocr_score          double   — 0..1 OCR legibility (from MLKitIdentityService)
///   name_match_score   double   — 0..1 form-name vs OCR-name (StringSimilarity)
///   liveness_score     double   — 0..1 liveness (FaceVerificationService)
///   id_attempts        int
///   selfie_attempts    int
///
/// Weights: OCR .20 · name .30 · liveness .20 · face-match .30 (same blend the
/// MVP used, but face-match is now a genuine embedding similarity).
class AiTrustScoreService implements TrustScoreService {
  final FaceEmbedder _embedder;

  AiTrustScoreService(this._embedder);

  static const double _wOcr = 0.20;
  static const double _wName = 0.30;
  static const double _wLiveness = 0.20;
  static const double _wFace = 0.30;

  @override
  Future<TrustEvaluation> evaluate({
    required String visitId,
    required Map<String, dynamic> evidenceData,
  }) async {
    final idPath = evidenceData['id_image_path'] as String?;
    final selfiePath = evidenceData['selfie_path'] as String?;

    final ocrScore =
        (evidenceData['ocr_score'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0;
    final nameMatch =
        (evidenceData['name_match_score'] as num?)?.toDouble().clamp(0.0, 1.0) ??
            0.0;
    final liveness =
        (evidenceData['liveness_score'] as num?)?.toDouble().clamp(0.0, 1.0) ??
            0.0;

    // --- Real face verification via embeddings (the AI core) ---
    final faceResult = await _computeFaceMatch(idPath, selfiePath);
    final faceMatch = faceResult.similarity01;

    // --- Weighted aggregate ---
    double score =
        (ocrScore * _wOcr + nameMatch * _wName + liveness * _wLiveness +
                faceMatch * _wFace) *
            100;

    // Retry penalty: -5 per extra attempt beyond the 2nd (discourages
    // brute-forcing a better score).
    final idAttempts = (evidenceData['id_attempts'] as int?) ?? 1;
    final selfieAttempts = (evidenceData['selfie_attempts'] as int?) ?? 1;
    if (idAttempts > 2) score -= (idAttempts - 2) * 5.0;
    if (selfieAttempts > 2) score -= (selfieAttempts - 2) * 5.0;

    // Hard floors: unusable core evidence caps the score low.
    if (faceResult.evaluated && faceMatch < 0.15) score *= 0.4;
    if (ocrScore < 0.1) score *= 0.5;

    final finalScore = score.clamp(0.0, 100.0);

    final factors = <String, double>{
      'ocr': ocrScore,
      'name_match': nameMatch,
      'liveness': liveness,
      'face_match': faceMatch,
      'id_attempts': idAttempts.toDouble(),
      'selfie_attempts': selfieAttempts.toDouble(),
    };

    final explanations = <String, String>{
      'ocr': ocrScore >= 0.7
          ? 'Identificación legible'
          : 'La identificación fue difícil de leer',
      'name_match': nameMatch >= 0.7
          ? 'El nombre coincide con la identificación'
          : 'El nombre no coincidió del todo con la identificación',
      'liveness': liveness >= 0.7
          ? 'Prueba de vida superada'
          : 'La prueba de vida fue débil',
      'face_match': _faceExplanation(faceResult),
    };

    return TrustEvaluation(
      score: double.parse(finalScore.toStringAsFixed(1)),
      factors: factors,
      explanations: explanations,
      engine: 'AI_V1',
      evaluatedAt: DateTime.now(),
    );
  }

  Future<_FaceMatch> _computeFaceMatch(String? idPath, String? selfiePath) async {
    if (idPath == null || selfiePath == null) {
      return const _FaceMatch(similarity: 0, evaluated: false);
    }
    try {
      await _embedder.ensureLoaded();
      if (!_embedder.isReady) {
        return const _FaceMatch(similarity: 0, evaluated: false);
      }
      final idEmb = await _embedder.embedFromFile(idPath);
      final selfieEmb = await _embedder.embedFromFile(selfiePath);
      if (idEmb == null || selfieEmb == null) {
        return const _FaceMatch(similarity: 0, evaluated: true, noFace: true);
      }
      final cos = _embedder.cosineSimilarity(idEmb, selfieEmb);
      return _FaceMatch(similarity: cos, evaluated: true);
    } catch (e) {
      debugPrint('AiTrustScoreService: face match error: $e');
      return const _FaceMatch(similarity: 0, evaluated: false);
    }
  }

  String _faceExplanation(_FaceMatch r) {
    if (!r.evaluated) return 'No se pudo comparar el rostro con la identificación';
    if (r.noFace) return 'No se detectó un rostro claro para comparar';
    if (r.similarity01 >= 0.65) return 'El rostro coincide con la identificación';
    if (r.similarity01 >= 0.4) return 'Coincidencia parcial del rostro';
    return 'El rostro no coincidió con la identificación';
  }
}

/// Result of the embedding comparison.
@immutable
class _FaceMatch {
  /// Raw cosine similarity in [-1, 1].
  final double similarity;
  final bool evaluated;
  final bool noFace;

  const _FaceMatch({
    required this.similarity,
    required this.evaluated,
    this.noFace = false,
  });

  /// Cosine clamped to [0, 1] for blending into the aggregate score.
  /// Same-person cosine is typically 0.6–0.85; different people 0.0–0.3.
  /// Clamping (rather than remapping (cos+1)/2) preserves that separation so
  /// impostor pairs don't get inflated toward the middle.
  ///
  /// Noise floor: a tiny positive cosine (e.g. 0.05 between two faceless/noise
  /// images) is NOT a real match — it just reflects embedding noise. We report
  /// anything below [_noiseFloor] as exactly 0 so a photo with no face shows a
  /// clean 0% "coincidencia con ID" instead of a phantom 5%.
  static const double _noiseFloor = 0.15;
  double get similarity01 {
    final c = similarity.clamp(0.0, 1.0);
    return c < _noiseFloor ? 0.0 : c;
  }
}
