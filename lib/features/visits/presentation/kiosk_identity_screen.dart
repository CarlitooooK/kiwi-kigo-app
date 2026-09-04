import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../core/utils/kiosk_input_formatters.dart';
import '../../../shared/widgets/journey_stepper.dart';

/// Identity Screen — Step 2: What's your name?
/// Single question, large inputs, no noise.
class KioskIdentityScreen extends StatefulWidget {
  final Map<String, dynamic>? flowData;

  const KioskIdentityScreen({super.key, this.flowData});

  @override
  State<KioskIdentityScreen> createState() => _KioskIdentityScreenState();
}

class _KioskIdentityScreenState extends State<KioskIdentityScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Prefill from prior data (e.g. the voice flow captured a name and the
    // visitor chose to correct it here).
    final data = widget.flowData;
    if (data != null) {
      _firstNameController.text = (data['first_name'] as String?) ?? '';
      _lastNameController.text = (data['last_name'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      ...?widget.flowData,
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
    };
    context.push('/kiosk/context', extra: data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
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
                const SizedBox(height: 32),

                // Question
                const Text(
                  'Tu nombre',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: KigoTheme.slate900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Así te identificaremos durante tu visita',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.gray500,
                  ),
                ),
                const SizedBox(height: 32),

                // First name
                TextFormField(
                  controller: _firstNameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: KioskInputFormatters.name,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Ingresa tu nombre' : null,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),

                // Last name
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: KioskInputFormatters.name,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Apellidos',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa tus apellidos'
                      : null,
                  onFieldSubmitted: (_) => _continue(),
                ),

                const Spacer(),

                // CTA
                SizedBox(
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
                const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
