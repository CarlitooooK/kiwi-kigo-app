import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trust_score_service.dart';
import 'ai_trust_score_service.dart';
import 'face_embedder.dart';

/// Single shared MobileFaceNet embedder (loads the TFLite model once).
final faceEmbedderProvider = Provider<FaceEmbedder>((ref) {
  final embedder = FaceEmbedder();
  ref.onDispose(embedder.dispose);
  return embedder;
});

/// The active Trust Score engine. Now the real on-device AI (`AI_V1`).
/// Swappable for MockTrustScoreService without touching feature code.
final trustScoreServiceProvider = Provider<TrustScoreService>((ref) {
  return AiTrustScoreService(ref.watch(faceEmbedderProvider));
});
