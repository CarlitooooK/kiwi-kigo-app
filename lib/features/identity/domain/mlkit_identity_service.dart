import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'identity_document_service.dart';

class MLKitIdentityService implements IdentityDocumentService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<IdentityResult> processDocument({
    required String imagePath,
    required String documentType,
  }) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final extractedData = _extractData(recognizedText.text);
      final score = _calculateScore(extractedData);

      return IdentityResult.success(
        confidence: score,
        extractedData: extractedData,
      );
    } catch (e) {
      return IdentityResult.failure('Error procesando el documento: $e');
    }
  }

  Map<String, String> _extractData(String text) {
    final Map<String, String> data = {};
    final String cleanText = text.toUpperCase();

    // 1. CURP (Improved Regex from ine_test)
    final curpRegex = RegExp(r'[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]{2}');
    
    // Attempt anchor-based search first
    if (cleanText.contains('CURP')) {
      final lines = cleanText.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('CURP')) {
          // Look at current, next, and 2nd next line
          for (int j = 0; j <= 2; j++) {
            if (i + j < lines.length) {
              final match = curpRegex.firstMatch(lines[i + j].trim());
              if (match != null) {
                data['curp'] = match.group(0)!;
                break;
              }
            }
          }
          if (data.containsKey('curp')) break;
        }
      }
    }
    
    // Global fallback
    if (!data.containsKey('curp')) {
      final curpMatch = curpRegex.firstMatch(cleanText);
      if (curpMatch != null) data['curp'] = curpMatch.group(0)!;
    }

    // 2. Elector Key (18 characters)
    final electorKeyRegex = RegExp(r'[A-Z]{6}\d{8}[A-Z]\d{3}');
    if (cleanText.contains('CLAVE')) {
      final lines = cleanText.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('CLAVE')) {
          for (int j = 0; j <= 2; j++) {
            if (i + j < lines.length) {
              final match = electorKeyRegex.firstMatch(lines[i + j].trim());
              if (match != null) {
                data['elector_key'] = match.group(0)!;
                break;
              }
            }
          }
          if (data.containsKey('elector_key')) break;
        }
      }
    }
    if (!data.containsKey('elector_key')) {
      final electorMatch = electorKeyRegex.firstMatch(cleanText);
      if (electorMatch != null) data['elector_key'] = electorMatch.group(0)!;
    }

    // 3. Birth Date (Look for DD/MM/YYYY or extract from CURP)
    final dateRegex = RegExp(r'(\d{2}[/\-]\d{2}[/\-]\d{4})');
    final dateMatch = dateRegex.firstMatch(cleanText);
    if (dateMatch != null) {
      data['birth_date'] = dateMatch.group(0)!;
    } else if (data.containsKey('curp')) {
      final curp = data['curp']!;
      if (curp.length >= 10) {
        final year = curp.substring(4, 6);
        final month = curp.substring(6, 8);
        final day = curp.substring(8, 10);
        final fullYear = int.parse(year) > 25 ? '19$year' : '20$year';
        data['birth_date'] = '$day/$month/$fullYear';
      }
    }

    // 4. Name extraction (Look for key labels and capture multiple lines)
    final lines = cleanText.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('NOMBRE')) {
        List<String> nameParts = [];
        // Capture up to 4 lines after the label
        for (int j = 1; j <= 4; j++) {
          if (i + j < lines.length) {
            final nextLine = lines[i + j].trim();
            // Stricter stop condition: any line starting with a label or containing ":"
            if (nextLine.isEmpty || 
                RegExp(r'DOMICILIO|FECHA|CURP|CLAVE|EDAD|SEXO', caseSensitive: false).hasMatch(nextLine) ||
                nextLine.contains(':')) {
              break;
            }
            if (nextLine.length > 2) {
              nameParts.add(nextLine);
            }
          }
        }
        if (nameParts.isNotEmpty) {
          data['name'] = nameParts.join(' ').replaceAll(RegExp(r'\s+'), ' ');
        }
        break;
      }
    }

    return data;
  }

  double _calculateScore(Map<String, String> data) {
    if (data.isEmpty) return 0.0;
    
    double score = 0.0;
    // CURP and Elector Key are most reliable/critical
    if (data.containsKey('curp')) score += 0.35;
    if (data.containsKey('elector_key')) score += 0.30;
    
    // Name is critical but sometimes partially captured
    if (data.containsKey('name')) {
      final words = data['name']!.split(' ').length;
      if (words >= 3) score += 0.20; // Full name
      else if (words >= 2) score += 0.15; // Partial
      else score += 0.10;
    }
    
    // Birth date
    if (data.containsKey('birth_date')) score += 0.15;

    return score.clamp(0.0, 1.0);
  }

  void dispose() {
    _textRecognizer.close();
  }
}
