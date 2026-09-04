import 'dart:math';

/// Demo-only simulated data.
///
/// For FEPRO we no longer ask the visitor for company, email or destination
/// area. Company is always "Kigo" and the area is picked at random so the
/// badge / WhatsApp / host mini-app still look complete. Email is dropped
/// entirely (never asked, stored or shown).
class SimulatedData {
  SimulatedData._();

  /// The company is always Kigo (per product decision).
  static const String company = 'Kigo';

  static const List<String> _areas = [
    'Piso 3 · Sala Norte',
    'Piso 5 · Innovación',
    'Piso 2 · Recepción Ejecutiva',
    'Piso 4 · Sala Pacífico',
    'Piso 6 · Terraza',
    'Piso 1 · Auditorio',
    'Piso 7 · Dirección',
  ];

  static final Random _rng = Random();

  /// A random destination area for the visit (demo simulation).
  static String randomArea() => _areas[_rng.nextInt(_areas.length)];
}
