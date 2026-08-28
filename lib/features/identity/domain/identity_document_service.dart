/// Abstract interface for identity document processing.
/// 
/// MVP may use a simple implementation that just validates
/// an image was captured. Future: OCR, AI validation.
abstract class IdentityDocumentService {
  /// Processes an identity document image.
  /// Returns extracted data and quality metrics.
  Future<IdentityResult> processDocument({
    required String imagePath,
    required String documentType, // ID_FRONT, ID_BACK
  });
}

/// Result of identity document processing.
class IdentityResult {
  final bool isValid;
  final double confidence; // 0.0 - 1.0
  final Map<String, String> extractedData; // name, id_number, etc.
  final String? errorMessage;

  const IdentityResult({
    required this.isValid,
    required this.confidence,
    this.extractedData = const {},
    this.errorMessage,
  });

  factory IdentityResult.success({
    required double confidence,
    Map<String, String> extractedData = const {},
  }) {
    return IdentityResult(
      isValid: true,
      confidence: confidence,
      extractedData: extractedData,
    );
  }

  factory IdentityResult.failure(String error) {
    return IdentityResult(
      isValid: false,
      confidence: 0,
      errorMessage: error,
    );
  }
}
