import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/journey_stepper.dart';

/// Purpose type card data.
class _PurposeType {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;

  const _PurposeType({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

const _purposes = [
  _PurposeType(
    id: 'CLIENT',
    label: 'Cliente',
    subtitle: 'Reunión comercial',
    icon: Icons.handshake_outlined,
  ),
  _PurposeType(
    id: 'PROVIDER',
    label: 'Proveedor',
    subtitle: 'Servicio o soporte',
    icon: Icons.engineering_outlined,
  ),
  _PurposeType(
    id: 'INTERVIEW',
    label: 'Entrevista',
    subtitle: 'Proceso de selección',
    icon: Icons.work_outline,
  ),
  _PurposeType(
    id: 'MAINTENANCE',
    label: 'Mantenimiento',
    subtitle: 'Reparación o servicio',
    icon: Icons.build_outlined,
  ),
  _PurposeType(
    id: 'DELIVERY',
    label: 'Entrega',
    subtitle: 'Paquetería o suministros',
    icon: Icons.local_shipping_outlined,
  ),
  _PurposeType(
    id: 'VISITOR',
    label: 'Visita personal',
    subtitle: 'Otro motivo',
    icon: Icons.person_outline,
  ),
];

/// Purpose Screen — Grid of visit type cards. Step 1 of guided registration.
class PurposeScreen extends StatelessWidget {
  /// Optional prefilled data (e.g. from face recognition of an enrolled
  /// visitor). Carried forward so identity/context screens can autofill.
  final Map<String, dynamic>? flowData;

  const PurposeScreen({super.key, this.flowData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Back
              GestureDetector(
                onTap: () => context.pop(),
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
              const SizedBox(height: 16),

              // Journey progress
              const JourneyStepper(current: JourneyStep.data),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Motivo de tu visita',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona el que mejor describa tu visita',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.gray500,
                ),
              ),
              const SizedBox(height: 24),

              // Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: _purposes.length,
                  itemBuilder: (context, index) {
                    final purpose = _purposes[index];
                    return _PurposeCard(
                      purpose: purpose,
                      onTap: () {
                        context.push('/kiosk/identity', extra: {
                          ...?flowData,
                          'visitor_type': purpose.id,
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurposeCard extends StatelessWidget {
  final _PurposeType purpose;
  final VoidCallback onTap;

  const _PurposeCard({required this.purpose, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KigoTheme.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: KigoTheme.kigo500.withValues(alpha: 0.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KigoTheme.umbral200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KigoTheme.kigo500.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  purpose.icon,
                  size: 22,
                  color: KigoTheme.kigo500,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  purpose.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: KigoTheme.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  purpose.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.gray500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
