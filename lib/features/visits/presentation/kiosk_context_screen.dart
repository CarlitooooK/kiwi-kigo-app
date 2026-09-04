import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/visit_repository.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/config/env_config.dart';
import '../../../core/utils/simulated_data.dart';
import '../../../core/utils/kiosk_input_formatters.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/journey_stepper.dart';
import '../../../shared/widgets/kigo_loader.dart';

/// Context Screen — Step 3: visit details.
/// Fields adapt per visitor type. We collect phone (real, for WhatsApp), the
/// purpose/detail by type, and the host. Company, email and destination area
/// are NOT collected — company/area are simulated at submit; email is dropped.
class KioskContextScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? flowData;

  const KioskContextScreen({super.key, this.flowData});

  @override
  ConsumerState<KioskContextScreen> createState() =>
      _KioskContextScreenState();
}

class _KioskContextScreenState extends ConsumerState<KioskContextScreen> {
  final _phoneController = TextEditingController();
  final _purposeController = TextEditingController();
  final _hostController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  static const _orgId = 'a0000000-0000-0000-0000-000000000001';

  @override
  void initState() {
    super.initState();
    // Prefill from prior data (voice flow captures host/detail/phone).
    final data = widget.flowData;
    if (data != null) {
      _hostController.text = (data['host_name_manual'] as String?) ??
          (data['host_name'] as String?) ??
          '';
      _purposeController.text = (data['detail'] as String?) ?? '';
      _phoneController.text = (data['phone'] as String?) ?? '';
    }
  }

  String get _visitorType =>
      widget.flowData?['visitor_type'] as String? ?? 'VISITOR';

  @override
  void dispose() {
    _phoneController.dispose();
    _purposeController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  // === Adaptive config per type ===

  String get _title {
    switch (_visitorType) {
      case 'CLIENT':
        return 'Datos de tu reunión';
      case 'PROVIDER':
      case 'MAINTENANCE':
        return 'Datos del servicio';
      case 'DELIVERY':
        return 'Datos de la entrega';
      case 'INTERVIEW':
        return 'Datos de tu entrevista';
      default:
        return 'Detalles de tu visita';
    }
  }

  bool get _showPhone => true; // phone is now collected for all types
  bool get _phoneRequired => _visitorType != 'DELIVERY';

  bool get _showPurpose => _visitorType != 'DELIVERY';
  String get _purposeLabel {
    switch (_visitorType) {
      case 'CLIENT':
        return 'Asunto de la reunión';
      case 'PROVIDER':
        return 'Servicio a realizar';
      case 'MAINTENANCE':
        return 'Trabajo a realizar';
      case 'INTERVIEW':
        return 'Posición a la que aplicas';
      default:
        return 'Motivo de visita';
    }
  }

  String get _purposeHint {
    switch (_visitorType) {
      case 'CLIENT':
        return 'Seguimiento, demo, revisión de proyecto...';
      case 'PROVIDER':
        return 'Instalación, soporte técnico, entrega de equipo...';
      case 'MAINTENANCE':
        return 'Reparación eléctrica, plomería, HVAC...';
      case 'INTERVIEW':
        return 'Desarrollador, diseñador, analista...';
      default:
        return '';
    }
  }

  // === Submit ===

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);

      final visitor = await visitRepo.createVisitor(
        firstName: widget.flowData?['first_name'] ?? '',
        lastName: widget.flowData?['last_name'] ?? '',
        organizationId: _orgId,
        // Simulated company (always Kigo); phone is REAL (WhatsApp). No email.
        company: SimulatedData.company,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        visitorType: _visitorType,
      );

      final hostName = _hostController.text.trim();

      final visit = await visitRepo.createVisit(
        visitorId: visitor['id'],
        organizationId: _orgId,
        purpose: _purposeController.text.trim().isNotEmpty
            ? _purposeController.text.trim()
            : null,
        // Destination area is simulated for the demo.
        area: SimulatedData.randomArea(),
        source: 'KIOSK',
      );

      await journeyRepo.logEvent(
        visitId: visit['id'],
        eventType: 'VISIT_CREATED',
        payload: {
          'source': 'KIOSK',
          'visitor_type': _visitorType,
          'host_name_manual': hostName.isNotEmpty ? hostName : null,
          // Kigo identity of the host (demo: fixed test user; prod: from a host
          // directory picker). The Kigo mini-app matches this against
          // kigo.auth.init().userId to confirm the viewer is the right host.
          'host_kigo_user_id': EnvConfig.testHostLegacyUserId,
        },
      );

      if (!mounted) return;

      final visitData = {
        ...visit,
        'visitors': visitor,
      };
      context.push('/consent', extra: visitData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos registrar tu visita. Verifica tu conexión e intenta de nuevo.',
            ),
            backgroundColor: KigoTheme.red500,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: KigoTheme.slate900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: JourneyStepper(current: JourneyStep.data),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Último paso antes de verificación',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.gray500,
                  ),
                ),
              ),
            ),

            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Phone (real — used for WhatsApp). Company/email/area are
                      // not collected here.
                      if (_showPhone) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: KioskInputFormatters.phone,
                          decoration: const InputDecoration(
                            labelText: 'Celular',
                            hintText: '10 dígitos',
                            prefixIcon: Icon(Icons.smartphone_outlined),
                          ),
                          validator: (v) {
                            final raw = (v ?? '').trim();
                            if (_phoneRequired && raw.isEmpty) {
                              return 'El celular es necesario';
                            }
                            if (raw.isNotEmpty) {
                              final digits = raw.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
                              if (!RegExp(r'^\d{10,15}$').hasMatch(digits)) {
                                return 'Ingresa un celular válido (10 dígitos)';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Purpose / Position / Service
                      if (_showPurpose) ...[
                        TextFormField(
                          controller: _purposeController,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: KioskInputFormatters.freeText,
                          decoration: InputDecoration(
                            labelText: _purposeLabel,
                            hintText: _purposeHint.isNotEmpty ? _purposeHint : null,
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Host — text field, not dropdown
                      TextFormField(
                        controller: _hostController,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: KioskInputFormatters.name,
                        decoration: const InputDecoration(
                          labelText: 'Persona a quien visitas',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Indica a quién visitas'
                            : null,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // CTA fixed at bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: _isSubmitting
                  ? const Center(
                      child: KigoLoader(message: 'Registrando tu visita'),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: KigoTheme.orangeGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: MaterialButton(
                          onPressed: _continue,
                          height: 46,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
