import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/journey_stepper.dart';
import '../../../shared/widgets/kigo_loader.dart';

/// Consent Screen — Privacy notice acceptance.
///
/// Both pre-registered and new visitor flows converge here.
/// Records consent in DB before continuing to identity capture.
class ConsentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const ConsentScreen({super.key, this.visitData});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _isProcessing = false;
  bool _faceConsent = false; // opt-in: recordar rostro para futuras visitas
  static const _consentVersion = '1.0';

  /// True when the visitor was already recognized by face (enrolled before).
  /// In that case we must NOT offer to enroll again — it's redundant.
  bool get _alreadyEnrolled => widget.visitData?['_prefill_from_face'] == true;

  Future<void> _acceptConsent() async {
    if (_isProcessing) return;

    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) {
      _showError('No se encontró información de la visita. Regresa e intenta de nuevo.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final client = ref.read(supabaseProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);

      // 1. Record consent
      await client.from('consent_records').insert({
        'visit_id': visitId,
        'consent_version': _consentVersion,
      });

      // 2. Update visit status to IN_PROGRESS
      await client
          .from('visits')
          .update({'status': 'IN_PROGRESS'})
          .eq('id', visitId);

      // 3. Log journey event
      await journeyRepo.logEvent(
        visitId: visitId,
        eventType: 'VISITOR_ARRIVED',
        payload: {'consent_version': _consentVersion},
      );

      if (!mounted) return;

      // 4. Navigate to identity capture, carrying the face-enrollment consent.
      context.push('/identity', extra: {
        ...?widget.visitData,
        '_face_consent': _faceConsent,
      });
    } catch (e) {
      _showError('No se pudo registrar el consentimiento. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: KigoTheme.red500,
      ),
    );
  }

  /// Visitor declined the privacy notice: mark the visit as CANCELLED (so it
  /// doesn't linger as a "ghost" PENDING record) and reset the kiosk.
  Future<void> _declineConsent() async {
    final visitId = widget.visitData?['id'] as String?;
    if (visitId != null) {
      try {
        final client = ref.read(supabaseProvider);
        final journeyRepo = ref.read(journeyRepositoryProvider);
        await client
            .from('visits')
            .update({'status': 'CANCELLED'})
            .eq('id', visitId);
        await journeyRepo.logEvent(
          visitId: visitId,
          eventType: 'CANCELLED',
          payload: {'reason': 'CONSENT_DECLINED'},
        );
      } catch (_) {
        // Non-critical — still reset the kiosk so the next visitor can start.
      }
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: KigoTheme.umbral100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: KigoTheme.slate900,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Journey progress
              const JourneyStepper(current: JourneyStep.consent),

              const SizedBox(height: 32),

              const Icon(
                Icons.privacy_tip_outlined,
                size: 48,
                color: KigoTheme.kigo500,
              ),
              const SizedBox(height: 24),

              const Text(
                'Aviso de privacidad',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Para continuar, necesitamos tu consentimiento para '
                'capturar y procesar tu identificación y fotografía.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Consent details card
              Container(
                decoration: BoxDecoration(
                  color: KigoTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KigoTheme.umbral200),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos que se capturarán:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KigoTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _ConsentItem(
                      icon: Icons.badge_outlined,
                      text: 'Fotografía de tu identificación oficial',
                    ),
                    const _ConsentItem(
                      icon: Icons.camera_alt_outlined,
                      text: 'Fotografía de tu rostro',
                    ),
                    const _ConsentItem(
                      icon: Icons.access_time,
                      text: 'Registro de horarios de entrada y salida',
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: KigoTheme.umbral200, height: 1),
                    const SizedBox(height: 12),
                    const Text(
                      'Esta información se utilizará exclusivamente para '
                      'control de acceso y será tratada conforme a la Ley '
                      'Federal de Protección de Datos Personales.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: KigoTheme.gray500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Versión: $_consentVersion',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: KigoTheme.gray400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Optional: face enrollment opt-in (Idea 1).
              // Hidden when the visitor was recognized by face (already enrolled)
              // — offering to enroll again would be redundant/contradictory.
              if (!_alreadyEnrolled)
              GestureDetector(
                onTap: () => setState(() => _faceConsent = !_faceConsent),
                child: Container(
                  decoration: BoxDecoration(
                    color: _faceConsent
                        ? KigoTheme.kigo500.withValues(alpha: 0.06)
                        : KigoTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _faceConsent
                          ? KigoTheme.kigo500.withValues(alpha: 0.5)
                          : KigoTheme.umbral200,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _faceConsent
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: _faceConsent ? KigoTheme.kigo500 : KigoTheme.gray400,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recordar mi rostro',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: KigoTheme.slate900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Para agilizar tus próximas visitas con reconocimiento facial. Opcional.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: KigoTheme.gray500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Accept button
              if (_isProcessing)
                const KigoLoader(message: 'Registrando consentimiento')
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KigoTheme.orangeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MaterialButton(
                    onPressed: _acceptConsent,
                    height: 46,
                    minWidth: double.infinity,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KigoTheme.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Decline option
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text(
                        '¿Cancelar registro?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: KigoTheme.slate900,
                        ),
                      ),
                      content: const Text(
                        'Sin tu consentimiento no es posible completar '
                        'el proceso de acceso.',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: KigoTheme.slate500,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Volver',
                            style: TextStyle(color: KigoTheme.slate900),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _declineConsent();
                          },
                          child: const Text(
                            'Cancelar registro',
                            style: TextStyle(color: KigoTheme.red500),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'No acepto',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.gray500,
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ConsentItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KigoTheme.kigo500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: KigoTheme.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
