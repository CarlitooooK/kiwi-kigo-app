import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/visit_repository.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/kigo_loader.dart';

/// Context Screen — Step 3: All visit details.
/// Fields adapt per visitor type but ALL relevant info is collected.
///
/// Per type:
/// - CLIENT: empresa (req), email, teléfono, asunto, área, anfitrión
/// - PROVIDER: empresa (req), teléfono, servicio a realizar, área, anfitrión
/// - MAINTENANCE: empresa (req), teléfono, trabajo a realizar, área, anfitrión
/// - DELIVERY: empresa, área, anfitrión (minimal)
/// - INTERVIEW: email (req), teléfono, posición, área, anfitrión
/// - VISITOR: empresa, email, teléfono, motivo, área, anfitrión
class KioskContextScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? flowData;

  const KioskContextScreen({super.key, this.flowData});

  @override
  ConsumerState<KioskContextScreen> createState() =>
      _KioskContextScreenState();
}

class _KioskContextScreenState extends ConsumerState<KioskContextScreen> {
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _purposeController = TextEditingController();
  final _areaController = TextEditingController();
  final _hostController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  static const _orgId = 'a0000000-0000-0000-0000-000000000001';

  String get _visitorType =>
      widget.flowData?['visitor_type'] as String? ?? 'VISITOR';

  @override
  void dispose() {
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    _areaController.dispose();
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

  bool get _showCompany => true; // Siempre, excepto control por label
  String get _companyLabel {
    switch (_visitorType) {
      case 'PROVIDER':
        return 'Empresa proveedora';
      case 'MAINTENANCE':
        return 'Empresa de servicio';
      case 'DELIVERY':
        return 'Empresa de envío';
      case 'CLIENT':
        return 'Tu empresa';
      case 'INTERVIEW':
        return 'Empresa (si aplica)';
      default:
        return 'Empresa';
    }
  }

  bool get _companyRequired =>
      ['PROVIDER', 'MAINTENANCE', 'CLIENT'].contains(_visitorType);

  bool get _showEmail => ['CLIENT', 'INTERVIEW', 'VISITOR'].contains(_visitorType);
  bool get _emailRequired => _visitorType == 'INTERVIEW';

  bool get _showPhone => _visitorType != 'DELIVERY';

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
        company: _companyController.text.trim().isNotEmpty
            ? _companyController.text.trim()
            : null,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
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
        area: _areaController.text.trim().isNotEmpty
            ? _areaController.text.trim()
            : null,
        source: 'KIOSK',
      );

      await journeyRepo.logEvent(
        visitId: visit['id'],
        eventType: 'VISIT_CREATED',
        payload: {
          'source': 'KIOSK',
          'visitor_type': _visitorType,
          'host_name_manual': hostName.isNotEmpty ? hostName : null,
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
                      // Company
                      if (_showCompany) ...[
                        TextFormField(
                          controller: _companyController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: _companyLabel,
                            prefixIcon: const Icon(Icons.business_outlined),
                          ),
                          validator: _companyRequired
                              ? (v) => v == null || v.trim().isEmpty
                                  ? 'Este campo es necesario'
                                  : null
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Email
                      if (_showEmail) ...[
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (_emailRequired && (v == null || v.trim().isEmpty)) {
                              return 'El correo es necesario';
                            }
                            if (v != null && v.trim().isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                              return 'El formato del correo no es válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Phone
                      if (_showPhone) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final digits = v.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
                              if (!RegExp(r'^\d{7,15}$').hasMatch(digits)) {
                                return 'Ingresa un teléfono válido (7-15 dígitos)';
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
                          decoration: InputDecoration(
                            labelText: _purposeLabel,
                            hintText: _purposeHint.isNotEmpty ? _purposeHint : null,
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Area
                      TextFormField(
                        controller: _areaController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Área o piso',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Host — text field, not dropdown
                      TextFormField(
                        controller: _hostController,
                        textCapitalization: TextCapitalization.words,
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
