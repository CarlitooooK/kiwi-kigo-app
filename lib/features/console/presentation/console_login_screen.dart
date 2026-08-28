import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/kigo_loader.dart';

/// Console Login Screen — Email/password authentication for admin/host/reception.
class ConsoleLoginScreen extends ConsumerStatefulWidget {
  const ConsoleLoginScreen({super.key});

  @override
  ConsumerState<ConsoleLoginScreen> createState() => _ConsoleLoginScreenState();
}

class _ConsoleLoginScreenState extends ConsumerState<ConsoleLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(supabaseProvider);
      await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      context.go('/console');
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _mapAuthError(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo conectar al servidor. Verifica tu red e intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Credenciales incorrectas. Verifica tu correo y contraseña.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Correo no confirmado. Revisa tu bandeja de entrada.';
    }
    return 'Error de autenticación. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Branding
                  const Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: KigoTheme.kigo500,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kigo Welcome',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: KigoTheme.slate900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Consola de gestión',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: KigoTheme.slate500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El correo es obligatorio';
                      }
                      if (!v.contains('@')) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'La contraseña es obligatoria';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _login(),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: KigoTheme.red100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 20,
                            color: KigoTheme.red500,
                          ),
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
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Login button
                  if (_isLoading)
                    const KigoLoader(message: 'Iniciando sesión')
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: KigoTheme.orangeGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: MaterialButton(
                        onPressed: _login,
                        height: 46,
                        minWidth: double.infinity,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: KigoTheme.white,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Back to kiosk link
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text(
                      'Volver al kiosco',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: KigoTheme.gray500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
