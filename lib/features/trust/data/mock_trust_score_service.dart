import 'dart:math';
import '../domain/trust_score_service.dart';

/// Mock implementation of TrustScoreService for MVP.
///
/// Simulates a quality evaluation based on completeness of data.
/// Produces human-readable explanations for each factor.
/// Will be replaced by AiTrustScoreService when the model is ready.
class MockTrustScoreService implements TrustScoreService {
  @override
  Future<TrustEvaluation> evaluate({
    required String visitId,
    required Map<String, dynamic> evidenceData,
  }) async {
    // Simulate processing time
    await Future.delayed(const Duration(milliseconds: 1200));

    final factors = <String, double>{};
    final explanations = <String, String>{};
    double total = 0;
    int count = 0;

    // Factor: Identity document
    if (evidenceData['has_id_document'] == true) {
      factors['identity_document'] = 95.0;
      explanations['identity_document'] = 'Identificación capturada correctamente';
    } else {
      factors['identity_document'] = 20.0;
      explanations['identity_document'] =
          'No se proporcionó identificación. Esto reduce la calidad del registro.';
    }
    total += factors['identity_document']!;
    count++;

    // Factor: Photo quality
    if (evidenceData['has_photo'] == true) {
      final quality = 88.0 + Random().nextDouble() * 12;
      factors['photo_quality'] = quality;
      if (quality >= 95) {
        explanations['photo_quality'] = 'Fotografía con excelente calidad';
      } else if (quality >= 85) {
        explanations['photo_quality'] = 'Fotografía legible y con buena iluminación';
      } else {
        explanations['photo_quality'] =
            'La fotografía es aceptable pero podría tener mejor iluminación';
      }
    } else {
      factors['photo_quality'] = 15.0;
      explanations['photo_quality'] =
          'No se capturó fotografía. Considera tomarla para mejorar tu registro.';
    }
    total += factors['photo_quality']!;
    count++;

    // Factor: Data completeness
    final fieldsProvided = evidenceData['fields_completed'] as int? ?? 0;
    final fieldsRequired = evidenceData['fields_required'] as int? ?? 5;
    final completeness = (fieldsProvided / fieldsRequired).clamp(0.0, 1.0);
    factors['data_completeness'] = completeness * 100;
    if (completeness >= 0.8) {
      explanations['data_completeness'] = 'Información de registro completa';
    } else if (completeness >= 0.5) {
      explanations['data_completeness'] =
          'Algunos datos opcionales no fueron proporcionados';
    } else {
      explanations['data_completeness'] =
          'Faltan varios datos. Un registro más completo genera mayor confianza.';
    }
    total += factors['data_completeness']!;
    count++;

    // Factor: Consent
    if (evidenceData['consent_accepted'] == true) {
      factors['consent'] = 100.0;
      explanations['consent'] = 'Consentimiento de privacidad aceptado';
    } else {
      factors['consent'] = 0.0;
      explanations['consent'] = 'El consentimiento es requerido para continuar';
    }
    total += factors['consent']!;
    count++;

    final score = (total / count).clamp(0.0, 100.0);

    return TrustEvaluation(
      score: double.parse(score.toStringAsFixed(1)),
      factors: factors,
      explanations: explanations,
      engine: 'MOCK',
      evaluatedAt: DateTime.now(),
    );
  }
}
