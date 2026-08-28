import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/visit_repository.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final input = _controller.text.trim();
      final visitRepo = ref.read(visitRepositoryProvider);
      final isEmail = input.contains('@');

      final results = await visitRepo.findPreRegistered(
        email: isEmail ? input : null,
        phone: !isEmail ? input : null,
        organizationId: 'a0000000-0000-0000-0000-000000000001',
      );

      if (!mounted) return;

      if (results.isNotEmpty) {
        context.push('/visit-found', extra: results.first);
      } else {
        setState(() {
          _errorMessage =
              'No encontramos una visita con esos datos. Verifica e intenta de nuevo.';
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Sin conexión. Verifica tu red e intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _BackButton(onTap: () => context.pop()),
                const Spacer(flex: 2),

                // Title
                Text(
                  'Buscar visita',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: KigoTheme.slate900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa tu correo o teléfono registrado',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: KigoTheme.gray500,
                  ),
                ),
                const SizedBox(height: 28),

                // Input
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Correo o teléfono',
                    hintText: 'ejemplo@empresa.com',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa tu correo o teléfono';
                    }
                    final v = value.trim();
                    final isEmail = v.contains('@');
                    final isPhone = RegExp(r'^\d{7,15}$').hasMatch(v.replaceAll(RegExp(r'[\s\-\+\(\)]'), ''));
                    if (!isEmail && !isPhone) {
                      return 'Ingresa un correo válido o un teléfono de al menos 7 dígitos';
                    }
                    if (isEmail && !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) {
                      return 'El formato del correo no es válido';
                    }
                    return null;
                  },
                ),

                // Error
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: KigoTheme.red500),
                      const SizedBox(width: 8),
                      Expanded(
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

                const SizedBox(height: 24),

                // CTA
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isLoading ? null : KigoTheme.orangeGradient,
                      color: _isLoading ? KigoTheme.kigo500.withValues(alpha: 0.6) : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
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

                const Spacer(flex: 1),

                // Escape to registration
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/register'),
                    child: Text(
                      'No tengo visita programada',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: KigoTheme.kigo500,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
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
