import 'package:flutter/services.dart';

/// Centralized input formatters so every form field across the kiosk restricts
/// characters consistently. Uses allow-lists (deny everything not matched) so
/// special characters, emoji and control chars never reach the data layer.
class KioskInputFormatters {
  KioskInputFormatters._();

  /// People / company / host names: letters (incl. Spanish accents and ñ) and
  /// spaces only. No digits, no punctuation, no hyphen or apostrophe, no symbols.
  static final List<TextInputFormatter> name = [
    FilteringTextInputFormatter.allow(
      RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ ]'),
    ),
    LengthLimitingTextInputFormatter(50),
  ];

  /// Phone numbers: digits only, max 15 (E.164 upper bound).
  static final List<TextInputFormatter> phone = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(15),
  ];

  /// Email: letters, digits and the few symbols valid in an address. No spaces.
  static final List<TextInputFormatter> email = [
    FilteringTextInputFormatter.allow(
      RegExp(r'[a-zA-Z0-9@._\-+]'),
    ),
    LengthLimitingTextInputFormatter(80),
  ];

  /// Free text (purpose / meeting subject / details): letters, digits and
  /// spaces only. No special characters or punctuation.
  static final List<TextInputFormatter> freeText = [
    FilteringTextInputFormatter.allow(
      RegExp(r'[a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ ]'),
    ),
    LengthLimitingTextInputFormatter(120),
  ];
}
