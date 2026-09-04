import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/visit_repository.dart';
import '../../../core/services/f10_door_service.dart';
import '../../../core/services/f10_scanner_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../shared/widgets/camera_qr_scanner.dart';
import '../../../core/theme/kigo_theme.dart';

/// Visit Lookup Screen
///
/// UX ANALYSIS — Visit Lookup
/// User: Visitor who chose "Tengo visita programada"
/// Goal: Find their pre-registered visit quickly
/// Emotional state: Slightly anxious — hopes it works fast
///
/// Visual hierarchy:
/// 1. Input field (dominant — single focus)
/// 2. Search CTA
/// 3. Escape: "Registrar visita" link
///
/// Semantic CTA: Orange — intent lookup
/// Removals: Removed icon above title (unnecessary), simplified instruction
class VisitLookupScreen extends ConsumerStatefulWidget {
  const VisitLookupScreen({super.key});

  @override
  ConsumerState<VisitLookupScreen> createState() => _VisitLookupScreenState();
}

class _VisitLookupScreenState extends ConsumerState<VisitLookupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showManual = false; // manual lookup is the secondary option
  bool _isF10 = true; // hides the camera-scan button on the real F10
  F10DoorService? _door; // cached for safe LED-off in dispose

  @override
  void initState() {
    super.initState();
    _door = ref.read(f10DoorServiceProvider);
    // On non-F10 devices (e.g. a tablet used as an extra kiosk) there's no
    // hardware reader, so we offer a camera-based QR scan fallback.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final f10 = await ref.read(f10DoorServiceProvider).isAvailable();
      if (mounted) setState(() => _isF10 = f10);
    });
  }

  @override
  void dispose() {
    _door?.ledOff(); // don't leave the LED red after leaving the screen
    _controller.dispose();
    super.dispose();
  }

  /// Sets an error message AND lights the red LED as a physical cue that the
  /// lookup/scan failed. The LED turns off again on the next attempt or on exit.
  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    _door?.setLedColor(F10LedColor.red);
    ref.read(soundServiceProvider).playError();
  }

  /// Clears the error state and turns the LED off (a fresh attempt begins).
  void _clearError() {
    _errorMessage = null;
    _door?.ledOff();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _clearError();
    });

    try {
      // Phone-only lookup. Normalize to digits.
      final phone = _controller.text.replaceAll(RegExp(r'\D'), '');
      final visitRepo = ref.read(visitRepositoryProvider);

      final results = await visitRepo.findPreRegistered(
        phone: phone,
        organizationId: 'a0000000-0000-0000-0000-000000000001',
      );

      if (!mounted) return;

      if (results.isNotEmpty) {
        final visit = results.first;
        final blocked = _usageBlockMessage(visit);
        if (blocked != null) {
          _showError(blocked);
        } else {
          context.push('/visit-found', extra: visit);
        }
      } else {
        _showError(
            'No encontramos una visita con esos datos. Verifica e intenta de nuevo.');
      }
    } catch (_) {
      _showError('Sin conexión. Verifica tu red e intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handles a scan from the F10's keyboard-wedge scanner. The badge QR is
  /// `https://parkimovil.com/app?qr=WELCOME:<visitId>`, but we also accept a
  /// bare visitId or `WELCOME:<id>` for flexibility.
  Future<void> _onScan(String raw) async {
    if (_isLoading) return;
    final visitId = _extractVisitId(raw);
    if (visitId == null) {
      _showError('El código no es una invitación válida.');
      return;
    }
    setState(() {
      _isLoading = true;
      _clearError();
    });
    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final visit = await visitRepo.getVisitDetail(visitId);
      if (!mounted) return;
      if (visit == null || visit['visitors'] == null) {
        _showError('No encontramos la visita de ese código.');
        return;
      }
      final blocked = _usageBlockMessage(visit);
      if (blocked != null) {
        _showError(blocked);
        return;
      }
      context.push('/visit-found', extra: visit);
    } catch (_) {
      _showError('Sin conexión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Single-use + validity guard. A scheduled visit can only be used to enter
  /// while it is still PRE_AUTHORIZED/PENDING AND within its validity window
  /// (scheduled_start ≤ now ≤ scheduled_end). Returns a message to show, or
  /// null if usable.
  static String? _usageBlockMessage(Map<String, dynamic> visit) {
    final status = visit['status'] as String?;
    // State check first (burned QR).
    switch (status) {
      case 'ACTIVE':
      case 'CHECKED_IN':
      case 'IN_PROGRESS':
        return 'Esta visita ya está activa. El código solo puede usarse una vez.';
      case 'COMPLETED':
        return 'Esta visita ya fue completada. Solicita una nueva invitación.';
      case 'REJECTED':
        return 'Esta visita no fue autorizada.';
      case 'CANCELLED':
        return 'Esta invitación fue cancelada. Solicita una nueva.';
    }

    // Validity window check (against the device clock).
    final now = DateTime.now();
    final startStr = visit['scheduled_start'] as String?;
    final endStr = visit['scheduled_end'] as String?;
    if (startStr != null) {
      final start = DateTime.tryParse(startStr)?.toLocal();
      if (start != null && now.isBefore(start)) {
        return 'Esta invitación aún no es válida. Estará disponible a partir de '
            '${_fmt(start)}.';
      }
    }
    if (endStr != null) {
      final end = DateTime.tryParse(endStr)?.toLocal();
      if (end != null && now.isAfter(end)) {
        return 'Esta invitación expiró el ${_fmt(end)}. Solicita una nueva.';
      }
    }
    return null; // usable
  }

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final today = DateTime.now();
    final sameDay = d.year == today.year && d.month == today.month && d.day == today.day;
    final time = '${two(d.hour)}:${two(d.minute)}';
    return sameDay ? time : '${two(d.day)}/${two(d.month)} $time';
  }

  /// Opens the camera QR scanner (non-F10 devices). On a successful scan it
  /// closes the scanner and feeds the value into the same lookup as the F10.
  Future<void> _scanWithCamera() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CameraQrScanner(
          onScan: (code) {
            Navigator.of(context).pop();
            _onScan(code);
          },
        ),
      ),
    );
  }

  /// Extracts a visit UUID from a scanned payload. Accepts the real badge URL
  /// (`…?qr=WELCOME:<id>`), a `WELCOME:<id>` marker, or a bare UUID.
  static String? _extractVisitId(String raw) {
    final s = raw.trim();
    final marker = s.indexOf('WELCOME:');
    if (marker >= 0) {
      final after = s.substring(marker + 'WELCOME:'.length);
      final id = after.split(RegExp(r'[^0-9a-fA-F-]')).first;
      return _looksLikeUuid(id) ? id : null;
    }
    return _looksLikeUuid(s) ? s : null;
  }

  static bool _looksLikeUuid(String s) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(s);

  @override
  Widget build(BuildContext context) {
    return ScanKeyboardListener(
      onScan: _onScan,
      enabled: !_showManual, // manual typing → let the keyboard reach the field
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _BackButton(onTap: () => context.pop()),

                const SizedBox(height: 32),

                // Title
                const Text(
                  'Visita programada',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: KigoTheme.slate900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escanea el código QR de tu invitación\nen el lector del kiosco',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.slate500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // PRIMARY: scan affordance (the scanner is always listening).
                if (_isLoading)
                  const _ScanPanel(loading: true)
                else
                  const _ScanPanel(loading: false),

                // Error
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: KigoTheme.red500),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: KigoTheme.red500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // SECONDARY: manual lookup (collapsed by default).
                if (!_showManual)
                  TextButton.icon(
                    onPressed: () => setState(() => _showManual = true),
                    icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                    label: const Text('No tengo el QR, buscar con mis datos'),
                    style: TextButton.styleFrom(foregroundColor: KigoTheme.slate500),
                  )
                else
                  _ManualLookup(
                    controller: _controller,
                    formKey: _formKey,
                    isLoading: _isLoading,
                    onSearch: _search,
                  ),

                // Camera-scan fallback — only on non-F10 devices (e.g. tablet).
                if (!_isF10) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _scanWithCamera,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Escanear con la cámara'),
                    style: TextButton.styleFrom(foregroundColor: KigoTheme.kigo500),
                  ),
                ],

                const SizedBox(height: 8),

                // Escape to registration (new walk-in flow, not the legacy one)
                TextButton(
                  onPressed: () => context.push('/kiosk/purpose'),
                  child: const Text(
                    'No tengo visita programada',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: KigoTheme.kigo500,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Big scan affordance — the primary action. Pulses to invite the visitor to
/// present the QR at the F10's built-in reader (which types the code and the
/// [ScanKeyboardListener] picks it up).
class _ScanPanel extends StatefulWidget {
  final bool loading;
  const _ScanPanel({required this.loading});

  @override
  State<_ScanPanel> createState() => _ScanPanelState();
}

class _ScanPanelState extends State<_ScanPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final scale = 1.0 + (_c.value * 0.06);
          return Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: KigoTheme.kigo500.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: KigoTheme.kigo500.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: widget.loading ? 1.0 : scale,
                  child: widget.loading
                      ? const SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: KigoTheme.kigo500,
                          ),
                        )
                      : const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 88,
                          color: KigoTheme.kigo500,
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.loading ? 'Buscando tu visita…' : 'Acerca tu QR al lector',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KigoTheme.kigo500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Secondary manual lookup by phone/email.
class _ManualLookup extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onSearch;

  const _ManualLookup({
    required this.controller,
    required this.formKey,
    required this.isLoading,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onFieldSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              hintText: '10 dígitos',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.isEmpty) return 'Ingresa tu teléfono';
              if (digits.length < 10) {
                return 'Ingresa los 10 dígitos de tu teléfono';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isLoading ? null : KigoTheme.orangeGradient,
                color: isLoading ? KigoTheme.kigo500.withValues(alpha: 0.6) : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Buscar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: KigoTheme.umbral100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: KigoTheme.slate900,
          ),
        ),
      ),
    );
  }
}
