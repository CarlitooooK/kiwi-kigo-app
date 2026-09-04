import '../../../core/constants/app_constants.dart';

/// Lightweight, offline intent parsing for the Spanish voice flow.
///
/// No LLM, no network: keyword/synonym matching tuned for the corporate
/// visitor kiosk. Good enough to fill the form; the touch fallback covers
/// anything it misses.
class VoiceParser {
  VoiceParser._();

  /// Maps a spoken phrase to a visitor type, or null if unclear.
  static String? visitorType(String input) {
    final t = _normalize(input);
    // Order matters: check more specific terms first.
    if (_containsAny(t, ['cliente', 'reunion', 'reunión', 'comercial', 'junta'])) {
      return AppConstants.typeClient;
    }
    if (_containsAny(t, ['proveedor', 'servicio', 'soporte', 'instalacion', 'instalación'])) {
      return AppConstants.typeProvider;
    }
    if (_containsAny(t, ['entrevista', 'vacante', 'reclutamiento', 'trabajo', 'empleo'])) {
      return AppConstants.typeInterview;
    }
    if (_containsAny(t, ['mantenimiento', 'reparacion', 'reparación', 'tecnico', 'técnico', 'arreglar'])) {
      return AppConstants.typeMaintenance;
    }
    if (_containsAny(t, ['entrega', 'paquete', 'paqueteria', 'paquetería', 'envio', 'envío', 'mensajeria', 'mensajería'])) {
      return AppConstants.typeDelivery;
    }
    if (_containsAny(t, ['visita', 'personal', 'amigo', 'familiar', 'conocido'])) {
      return AppConstants.typeVisitor;
    }
    return null;
  }

  /// Yes / no / unclear.
  ///
  /// Negatives are checked FIRST and matching is by whole word, because several
  /// negative words contain a positive as a substring (e.g. "incorrecto"
  /// contains "correcto"). A naive substring/positive-first check would read
  /// "incorrecto" as "correcto" → yes.
  static bool? yesNo(String input) {
    final t = _normalize(input);
    const negatives = [
      'no', 'incorrecto', 'incorrecta', 'negativo', 'corregir', 'cambiar',
      'mal', 'equivocado', 'equivocada', 'nel', 'nop',
    ];
    if (_containsWord(t, negatives)) return false;

    const positives = [
      'si', 'sí', 'correcto', 'correcta', 'exacto', 'exacta', 'claro',
      'afirmativo', 'confirmo', 'asi', 'así', 'ok', 'okay',
    ];
    if (_containsWord(t, positives)) return true;
    // Phrases that only make sense as a whole.
    if (t.contains('asi es') || t.contains('así es') ||
        t.contains('esta bien') || t.contains('está bien')) {
      return true;
    }
    return null;
  }

  /// Cleans a spoken name: strips filler like "me llamo", "soy", "mi nombre es",
  /// title-cases the rest.
  static String cleanName(String input) {
    var t = input.trim();
    final lower = t.toLowerCase();
    const prefixes = [
      'me llamo ',
      'mi nombre es ',
      'mi nombre completo es ',
      'soy ',
      'yo soy ',
      'el nombre es ',
    ];
    for (final p in prefixes) {
      if (lower.startsWith(p)) {
        t = t.substring(p.length);
        break;
      }
    }
    return _titleCase(t.trim());
  }

  /// Splits a full name into (firstName, lastName). Heuristic for Mexican
  /// names: first token is the given name, the rest are surnames. With 3+
  /// tokens, the first two are treated as compound given name.
  static ({String first, String last}) splitName(String fullName) {
    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return (first: '', last: '');
    if (parts.length == 1) return (first: parts[0], last: '');
    if (parts.length == 2) return (first: parts[0], last: parts[1]);
    if (parts.length == 3) {
      return (first: parts[0], last: '${parts[1]} ${parts[2]}');
    }
    // 4+ : two given names, the rest surnames.
    return (
      first: '${parts[0]} ${parts[1]}',
      last: parts.sublist(2).join(' '),
    );
  }

  /// Generic free-text answer cleanup (purpose, company, host…).
  static String cleanText(String input) => _titleCaseSentence(input.trim());

  /// Extracts a phone number from a spoken/typed answer. Handles digits said
  /// as words ("dos dos uno...") and as numerals, plus common fillers. Returns
  /// the digit string, or null if it doesn't look like a valid phone.
  static String? phone(String input) {
    var t = _normalize(input);

    // Spanish number words → digit. Order longest-first not needed since we
    // replace whole tokens.
    const words = {
      'cero': '0', 'uno': '1', 'una': '1', 'dos': '2', 'tres': '3',
      'cuatro': '4', 'cinco': '5', 'seis': '6', 'siete': '7', 'ocho': '8',
      'nueve': '9',
    };
    final tokens = t.split(RegExp(r'\s+'));
    final buf = StringBuffer();
    for (final tok in tokens) {
      if (words.containsKey(tok)) {
        buf.write(words[tok]);
      } else {
        // Keep any bare digits inside the token (e.g. "22" or "221-838").
        for (final ch in tok.split('')) {
          if (RegExp(r'\d').hasMatch(ch)) buf.write(ch);
        }
      }
    }
    final digits = buf.toString();
    if (digits.length < 10 || digits.length > 13) return null;
    // Keep the last 10 digits (drop a leading country code if dictated).
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  // --- helpers ---

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[.,;!?¿¡]'), '')
      .trim();

  static bool _containsAny(String haystack, List<String> needles) =>
      needles.any((n) => haystack.contains(n));

  /// Whole-word match: the needle must appear as its own token, not as a
  /// substring of a larger word ("correcto" must NOT match inside
  /// "incorrecto"). Multi-word needles fall back to substring.
  static bool _containsWord(String haystack, List<String> needles) {
    final tokens = haystack.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    for (final n in needles) {
      if (n.contains(' ')) {
        if (haystack.contains(n)) return true;
      } else if (tokens.contains(n)) {
        return true;
      }
    }
    return false;
  }

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  static String _titleCaseSentence(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
}
