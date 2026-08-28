import 'package:equatable/equatable.dart';

/// Result of a trust evaluation.
class TrustEvaluation extends Equatable {
  final double score; // 0-100
  final Map<String, double> factors;
  final Map<String, String> explanations; // Human-readable per factor
  final String engine; // MOCK, AI_V1, etc.
  final DateTime evaluatedAt;

  const TrustEvaluation({
    required this.score,
    required this.factors,
    this.explanations = const {},
    required this.engine,
    required this.evaluatedAt,
  });

  bool get isExcellent => score >= 85.0;
  bool get isAcceptable => score >= 70.0;
  bool get isLow => score < 70.0;

  /// Human-readable quality label.
  String get qualityLabel {
    if (isExcellent) return 'Registro excelente';
    if (isAcceptable) return 'Registro completo';
    return 'Registro con observaciones';
  }

  /// Human-readable explanation for the visitor.
  String get visitorMessage {
    if (isExcellent) {
      return 'Tu información fue verificada correctamente. '
          'La calidad de tu registro es excelente.';
    }
    if (isAcceptable) {
      return 'Tu información fue verificada. '
          'Todos los datos fueron procesados correctamente.';
    }
    // Low — find the weakest factor and explain
    final weakest = explanations.entries
        .where((e) => (factors[e.key] ?? 100) < 70)
        .map((e) => e.value)
        .toList();
    if (weakest.isNotEmpty) {
      return weakest.first;
    }
    return 'La calidad del registro podría mejorar. '
        'Puedes intentar de nuevo o continuar.';
  }

  @override
  List<Object?> get props => [score, factors, engine, evaluatedAt];
}

/// Abstract interface for the Trust Score evaluation engine.
///
/// The Trust Score represents Registration & Evidence Quality.
/// It does NOT represent danger, criminality, or moral reliability.
abstract class TrustScoreService {
  /// Evaluates the quality of evidence and registration process.
  Future<TrustEvaluation> evaluate({
    required String visitId,
    required Map<String, dynamic> evidenceData,
  });
}
