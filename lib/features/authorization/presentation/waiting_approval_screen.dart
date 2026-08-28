import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/kigo_theme.dart';
import '../data/authorization_provider.dart';

/// Waiting Approval Screen — Visitor waits while host decides.
class WaitingApprovalScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const WaitingApprovalScreen({super.key, this.visitData});

  @override
  ConsumerState<WaitingApprovalScreen> createState() =>
      _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends ConsumerState<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timeoutTimer;
  Timer? _pollingTimer;
  int _elapsedSeconds = 0;
  bool _hasEvaluated = false;
  late AnimationController _pulseController;

  static const _timeoutSeconds = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateAccess();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _evaluateAccess() async {
    if (_hasEvaluated || widget.visitData == null) return;
    _hasEvaluated = true;

    final notifier = ref.read(authorizationProvider.notifier);
    await notifier.evaluate(widget.visitData!);
  }

  void _startWaiting() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);

      if (_elapsedSeconds >= _timeoutSeconds) {
        timer.cancel();
        _handleTimeout();
      }
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkForDecision();
    });
  }

  Future<void> _checkForDecision() async {
    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) return;

    try {
      final client = ref.read(supabaseProvider);
      final decisions = await client
          .from('access_decisions')
          .select()
          .eq('visit_id', visitId)
          .inFilter('decided_by', ['HOST', 'RECEPTION', 'ADMIN'])
          .order('created_at', ascending: false)
          .limit(1);

      if (decisions.isNotEmpty) {
        final decision = decisions.first;
        final decisionType = decision['decision'] as String;

        _timeoutTimer?.cancel();
        _pollingTimer?.cancel();

        if (!mounted) return;

        if (decisionType == 'GRANTED') {
          ref
              .read(authorizationProvider.notifier)
              .simulateHostApproval(visitId);
        } else {
          ref.read(authorizationProvider.notifier).simulateHostRejection(
                visitId,
                decision['reason'] ?? 'Rejected by host',
              );
        }
      }
    } catch (_) {
      // Silently fail polling, will retry next cycle
    }
  }

  void _handleTimeout() {
    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) return;

    ref.read(authorizationProvider.notifier).escalate(visitId);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authorizationProvider);

    // React to state changes
    ref.listen<AuthorizationState>(authorizationProvider, (prev, next) {
      switch (next.status) {
        case AuthorizationStatus.autoGranted:
        case AuthorizationStatus.hostApproved:
          context.pushReplacement('/checked-in', extra: widget.visitData);
          break;
        case AuthorizationStatus.hostRejected:
          context.pushReplacement('/access-denied', extra: widget.visitData);
          break;
        case AuthorizationStatus.requiresHost:
        case AuthorizationStatus.manualReview:
          _startWaiting();
          break;
        case AuthorizationStatus.escalated:
          break;
        default:
          break;
      }
    });

    return PopScope(
      canPop: false, // Never allow back from waiting screen
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Show confirmation dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text(
                'Cancelar visita',
                style: TextStyle(fontWeight: FontWeight.w600, color: KigoTheme.slate900),
              ),
              content: const Text('Si regresas, tu solicitud de acceso se cancelará.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Seguir esperando'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/');
                  },
                  child: const Text('Cancelar visita', style: TextStyle(color: KigoTheme.red500)),
                ),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildContent(authState),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AuthorizationState authState) {
    switch (authState.status) {
      case AuthorizationStatus.initial:
      case AuthorizationStatus.evaluating:
        return _buildEvaluating();
      case AuthorizationStatus.requiresHost:
      case AuthorizationStatus.manualReview:
        return _buildWaiting();
      case AuthorizationStatus.escalated:
        return _buildEscalated();
      case AuthorizationStatus.error:
        return _buildError(authState.errorMessage);
      default:
        return _buildEvaluating();
    }
  }

  Widget _buildEvaluating() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: KigoTheme.kigo500),
          const SizedBox(height: 24),
          const Text(
            'Evaluando acceso',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: KigoTheme.slate900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Verificando políticas de acceso',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: KigoTheme.slate500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting() {
    final hostName =
        widget.visitData?['profiles']?['full_name'] ?? 'tu anfitrión';
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final progress = _elapsedSeconds / _timeoutSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),

        // Animated icon
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.05),
                child: child,
              );
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: KigoTheme.kigo500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 40,
                color: KigoTheme.kigo500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        const Text(
          'Esperando autorización',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: KigoTheme.slate900,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Se ha notificado a $hostName.\nEsperando su respuesta.',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: KigoTheme.slate500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Timer
        Center(
          child: Text(
            timeString,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w300,
              color: KigoTheme.slate500,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 4,
            color: KigoTheme.kigo500,
            backgroundColor: KigoTheme.umbral200,
          ),
        ),

        const Spacer(flex: 1),

        // Contact host option
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notificación enviada al anfitrión'),
              ),
            );
          },
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: const Text('Recordar al anfitrión'),
        ),

        const SizedBox(height: 12),

        // Cancel
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: KigoTheme.gray500,
            ),
          ),
        ),

        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildEscalated() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KigoTheme.yellow50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.escalator_warning_rounded,
              size: 36,
              color: KigoTheme.yellow400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Escalando solicitud',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: KigoTheme.slate900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu anfitrión no ha respondido.\n'
            'Se ha notificado a recepción para asistirte.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: KigoTheme.slate500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notificación enviada a recepción'),
                ),
              );
            },
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Contactar recepción'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text(
              'Cancelar visita',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: KigoTheme.gray500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String? errorMessage) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 64,
          color: KigoTheme.red500,
        ),
        const SizedBox(height: 24),
        const Text(
          'Ocurrió un error',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: KigoTheme.slate900,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          errorMessage ?? 'No se pudo procesar tu solicitud. Intenta de nuevo.',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: KigoTheme.slate500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: KigoTheme.orangeGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: MaterialButton(
            onPressed: () {
              _hasEvaluated = false;
              _evaluateAccess();
            },
            height: 46,
            minWidth: double.infinity,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Reintentar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: KigoTheme.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: KigoTheme.gray500,
            ),
          ),
        ),
      ],
    );
  }
}
