import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/data/visit_repository.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/kigo_loader.dart';
import '../data/hosts_provider.dart';

/// Adaptive field configuration per visitor type.
/// Each type shows different fields and copy.
class _VisitorTypeConfig {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool showCompany;
  final bool showEmail;
  final bool showPhone;
  final bool showPurpose;
  final bool showArea;
  final bool companyRequired;
  final String companyLabel;
  final String purposeLabel;
  final String purposeHint;

  const _VisitorTypeConfig({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.showCompany = true,
    this.showEmail = true,
    this.showPhone = true,
    this.showPurpose = true,
    this.showArea = true,
    this.companyRequired = false,
    this.companyLabel = 'Empresa',
    this.purposeLabel = 'Motivo de visita',
    this.purposeHint = '',
  });
}

const _typeConfigs = <String, _VisitorTypeConfig>{
  'VISITOR': _VisitorTypeConfig(
    label: 'Visitante',
    subtitle: 'Visita personal o de negocios',
    icon: Icons.person_outline,
    showCompany: true,
    showEmail: true,
    showPhone: true,
    showPurpose: true,
    showArea: true,
  ),
  'CLIENT': _VisitorTypeConfig(
    label: 'Cliente',
    subtitle: 'Reunión comercial o seguimiento',
    icon: Icons.handshake_outlined,
    showCompany: true,
    companyRequired: true,
    showEmail: true,
    showPhone: true,
    showPurpose: true,
    purposeLabel: 'Asunto',
    purposeHint: 'Reunión de seguimiento, demo, revisión...',
    showArea: true,
  ),
  'PROVIDER': _VisitorTypeConfig(
    label: 'Proveedor',
    subtitle: 'Servicio, instalación o soporte',
    icon: Icons.engineering_outlined,
    showCompany: true,
    companyRequired: true,
    companyLabel: 'Empresa proveedora',
    showEmail: false,
    showPhone: true,
    showPurpose: true,
    purposeLabel: 'Servicio a realizar',
    purposeHint: 'Mantenimiento HVAC, limpieza, TI...',
    showArea: true,
  ),
  'MAINTENANCE': _VisitorTypeConfig(
    label: 'Mantenimiento',
    subtitle: 'Reparación o servicio técnico',
    icon: Icons.build_outlined,
    showCompany: true,
    companyRequired: true,
    companyLabel: 'Empresa de servicio',
    showEmail: false,
    showPhone: true,
    showPurpose: true,
    purposeLabel: 'Trabajo a realizar',
    purposeHint: 'Reparación eléctrica, plomería, aire acondicionado...',
    showArea: true,
  ),
  'DELIVERY': _VisitorTypeConfig(
    label: 'Entrega',
    subtitle: 'Paquetería, mensajería o suministros',
    icon: Icons.local_shipping_outlined,
    showCompany: true,
    companyLabel: 'Empresa de envío',
    showEmail: false,
    showPhone: false,
    showPurpose: false,
    showArea: true,
  ),
  'INTERVIEW': _VisitorTypeConfig(
    label: 'Entrevista',
    subtitle: 'Proceso de selección o evaluación',
    icon: Icons.work_outline,
    showCompany: false,
    showEmail: true,
    showPhone: true,
    showPurpose: true,
    purposeLabel: 'Posición',
    purposeHint: 'Desarrollador, diseñador, analista...',
    showArea: true,
  ),
  'OTHER': _VisitorTypeConfig(
    label: 'Otro',
    subtitle: 'Tipo de visita no listado',
    icon: Icons.more_horiz,
    showCompany: true,
    showEmail: true,
    showPhone: true,
    showPurpose: true,
    showArea: true,
  ),
};

/// Adaptive Visitor Registration Screen.
///
/// The form changes dynamically based on visitor type:
/// - Different fields shown/hidden
/// - Different labels and hints
/// - Different required fields
///
/// This reduces friction: a delivery person doesn't need to provide email.
class VisitorRegistrationScreen extends ConsumerStatefulWidget {
  const VisitorRegistrationScreen({super.key});

  @override
  ConsumerState<VisitorRegistrationScreen> createState() =>
      _VisitorRegistrationScreenState();
}

class _VisitorRegistrationScreenState
    extends ConsumerState<VisitorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _purposeController = TextEditingController();
  final _areaController = TextEditingController();
  final _manualHostController = TextEditingController();

  String _selectedVisitorType = AppConstants.typeVisitor;
  String? _selectedHostId;
  bool _isSubmitting = false;

  static const _orgId = 'a0000000-0000-0000-0000-000000000001';

  _VisitorTypeConfig get _config =>
      _typeConfigs[_selectedVisitorType] ?? _typeConfigs['VISITOR']!;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    _areaController.dispose();
    _manualHostController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);

      final visitor = await visitRepo.createVisitor(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
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
        visitorType: _selectedVisitorType,
      );

      final visit = await visitRepo.createVisit(
        visitorId: visitor['id'],
        organizationId: _orgId,
        hostId: _selectedHostId,
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
          'visitor_type': _selectedVisitorType,
          'host_name_manual': _manualHostController.text.trim().isNotEmpty
              ? _manualHostController.text.trim()
              : null,
        },
      );

      if (!mounted) return;

      final visitData = {...visit, 'visitors': visitor};
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
    final hostsAsync = ref.watch(hostsProvider(_orgId));
    final config = _config;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  const Text(
                    'Comenzar tu visita',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: KigoTheme.slate900,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // === Visitor type selector ===
                      const Text(
                        'Tipo de visita',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: KigoTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConstants.visitorTypes.map((type) {
                          final typeConfig = _typeConfigs[type]!;
                          final isSelected = type == _selectedVisitorType;
                          return ChoiceChip(
                            avatar: Icon(
                              typeConfig.icon,
                              size: 16,
                              color: isSelected
                                  ? KigoTheme.kigo500
                                  : KigoTheme.slate500,
                            ),
                            label: Text(typeConfig.label),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedVisitorType = type);
                              }
                            },
                          );
                        }).toList(),
                      ),

                      // Type context message
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          config.subtitle,
                          key: ValueKey(config.subtitle),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: KigoTheme.gray500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // === Personal info (always shown) ===
                      const Text(
                        'Tus datos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: KigoTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre',
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Ingresa tu nombre'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Apellidos',
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Ingresa tus apellidos'
                                  : null,
                            ),
                          ),
                        ],
                      ),

                      // === Adaptive fields ===
                      if (config.showCompany) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _companyController,
                          decoration: InputDecoration(
                            labelText: config.companyLabel,
                            prefixIcon: const Icon(Icons.business_outlined),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: config.companyRequired
                              ? (v) => v == null || v.trim().isEmpty
                                  ? 'Indica la empresa'
                                  : null
                              : null,
                        ),
                      ],

                      if (config.showEmail) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],

                      if (config.showPhone) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // === Visit details ===
                      const Text(
                        'Detalles',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: KigoTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Host selection (always)
                      hostsAsync.when(
                        data: (hosts) {
                          if (hosts.isEmpty) {
                            return TextFormField(
                              controller: _manualHostController,
                              decoration: const InputDecoration(
                                labelText: 'Persona a quien visitas',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Indica a quién visitas'
                                  : null,
                            );
                          }
                          return DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Persona a quien visitas',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: hosts.map((h) {
                              return DropdownMenuItem<String>(
                                value: h['id'] as String,
                                child: Text(h['full_name'] as String),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedHostId = v),
                            validator: (v) =>
                                v == null ? 'Selecciona a quién visitas' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(
                          color: KigoTheme.kigo500,
                          backgroundColor: KigoTheme.umbral100,
                        ),
                        error: (e, st) => TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Persona a quien visitas',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),

                      if (config.showPurpose) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _purposeController,
                          decoration: InputDecoration(
                            labelText: config.purposeLabel,
                            hintText: config.purposeHint.isNotEmpty
                                ? config.purposeHint
                                : null,
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ],

                      if (config.showArea) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _areaController,
                          decoration: const InputDecoration(
                            labelText: 'Área o piso',
                            prefixIcon: Icon(Icons.meeting_room_outlined),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ],

                      const SizedBox(height: 36),

                      // Submit
                      if (_isSubmitting)
                        const KigoLoader(message: 'Registrando tu visita')
                      else
                        SizedBox(
                          height: 46,
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: KigoTheme.orangeGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: MaterialButton(
                              onPressed: _submit,
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

                      const SizedBox(height: 32),
                    ],
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
