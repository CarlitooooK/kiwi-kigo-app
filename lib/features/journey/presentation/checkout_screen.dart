import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/visit_repository.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/kigo_loader.dart';

/// Checkout Screen — Confirm and complete the visit.
class CheckoutScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const CheckoutScreen({super.key, this.visitData});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isProcessing = false;

  Future<void> _confirmCheckout() async {
    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) return;

    setState(() => _isProcessing = true);

    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);

      // 1. Check out
      await visitRepo.checkOut(visitId);

      // 2. Log journey event
      await journeyRepo.logEvent(
        visitId: visitId,
        eventType: 'CHECKED_OUT',
      );

      if (!mounted) return;

      // 3. Navigate to completed
      context.pushReplacement('/visit-completed', extra: widget.visitData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo finalizar la visita. Intenta de nuevo. ($e)'),
            backgroundColor: KigoTheme.red500,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitor = widget.visitData?['visitors'] as Map<String, dynamic>? ?? {};
    final firstName = visitor['first_name'] ?? 'Visitante';

    return Scaffold(
      body: SafeArea(
        child: Padding(
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

              const Spacer(flex: 2),

              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: KigoTheme.sky50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 40,
                    color: KigoTheme.sky900,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                '¿Finalizar visita?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '$firstName, confirma que deseas registrar tu salida.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 1),

              // Actions
              if (_isProcessing)
                const KigoLoader(message: 'Finalizando visita')
              else ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KigoTheme.orangeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MaterialButton(
                    onPressed: _confirmCheckout,
                    height: 46,
                    minWidth: double.infinity,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Confirmar salida',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KigoTheme.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver a mi visita'),
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
