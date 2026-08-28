import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kigo_theme.dart';

/// Evidence Result Screen — Shows processing outcome.
///
/// The visitor does NOT see the trust score number.
/// They see a human-readable quality message.
class EvidenceResultScreen extends StatelessWidget {
  final Map<String, dynamic>? visitData;

  const EvidenceResultScreen({super.key, this.visitData});

  @override
  Widget build(BuildContext context) {
    final trustScore = (visitData?['_trust_score'] as num?)?.toDouble() ?? 0;
    final evidenceComplete = visitData?['_evidence_complete'] == true;

    // Determine quality level for UX (NOT showing score to visitor)
    final isExcellent = trustScore >= 85;
    final isGood = trustScore >= 70;
    
    final factors = visitData?['_trust_factors'] as Map<dynamic, dynamic>?;

    final statusIcon = isExcellent
        ? Icons.check_circle_rounded
        : isGood
            ? Icons.check_circle_outline
            : Icons.info_outlined;

    final statusColor = isExcellent || isGood
        ? KigoTheme.green600
        : KigoTheme.yellow400;

    final statusTitle = isExcellent || isGood
        ? 'Registro completado'
        : 'Registro con observaciones';

    final statusMessage = isExcellent
        ? 'Tu información ha sido verificada correctamente.\n'
            'La calidad del registro es excelente.'
        : isGood
            ? 'Tu información ha sido verificada correctamente.\n'
                'Todos los datos fueron procesados.'
            : 'Tu registro fue procesado, pero la calidad de la evidencia '
                'podría ser mejor. Puedes continuar o intentar de nuevo.';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Step indicator
              const _StepIndicator(currentStep: 3, totalSteps: 3),

              const SizedBox(height: 40),

              // Status icon
              Icon(statusIcon, size: 72, color: statusColor),
              const SizedBox(height: 24),

              // Title
              Text(
                statusTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                statusMessage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Evidence summary card
              if (evidenceComplete)
                Container(
                  decoration: BoxDecoration(
                    color: KigoTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KigoTheme.umbral200),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const _EvidenceRow(
                        icon: Icons.badge_outlined,
                        label: 'Identificación',
                        status: 'Verificada',
                        isOk: true,
                      ),
                      const SizedBox(height: 8),
                      const _EvidenceRow(
                        icon: Icons.camera_alt_outlined,
                        label: 'Fotografía',
                        status: 'Capturada',
                        isOk: true,
                      ),
                      const SizedBox(height: 8),
                      const _EvidenceRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Consentimiento',
                        status: 'Aceptado',
                        isOk: true,
                      ),
                      if (!isGood && factors != null) ...[
                        const Divider(height: 24),
                        const Text(
                          'Detalles de validación:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _FactorRow(
                          label: 'Legibilidad ID',
                          score: ((factors['ocr'] as num?)?.toDouble() ?? 0) * 100,
                        ),
                        _FactorRow(
                          label: 'Coincidencia de nombre',
                          score: ((factors['name_match'] as num?)?.toDouble() ?? 0) * 100,
                        ),
                        _FactorRow(
                          label: 'Prueba de vida',
                          score: ((factors['liveness'] as num?)?.toDouble() ?? 0) * 100,
                        ),
                      ],
                    ],
                  ),
                ),

              const Spacer(flex: 1),

              // Continue to authorization
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: KigoTheme.orangeGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: MaterialButton(
                  onPressed: () {
                    context.push('/waiting-approval', extra: visitData);
                  },
                  height: 46,
                  minWidth: double.infinity,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KigoTheme.white,
                    ),
                  ),
                ),
              ),

              // Retry option (only if quality is low)
              if (!isGood) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    context.go('/identity', extra: visitData);
                  },
                  child: const Text('Mejorar evidencia'),
                ),
              ],

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        final isCurrent = index == currentStep - 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? KigoTheme.kigo500 : KigoTheme.umbral200,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool isOk;

  const _EvidenceRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: KigoTheme.slate500),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: KigoTheme.slate900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOk ? KigoTheme.green100 : KigoTheme.yellow50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOk ? KigoTheme.green600 : KigoTheme.yellow400,
            ),
          ),
        ),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  final String label;
  final double score;

  const _FactorRow({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final isOk = score >= 70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: KigoTheme.gray500)),
          Text(
            isOk ? 'OK' : 'Bajo (${score.toInt()}%)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOk ? KigoTheme.green600 : KigoTheme.red500,
            ),
          ),
        ],
      ),
    );
  }
}
