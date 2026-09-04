import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/f10_door_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/theme/kigo_theme.dart';

/// Host Fast-Entry — shown when a recognized host taps their NFC card on the
/// Welcome screen. No registration, no waiting: green LED + success sound +
/// door opens, then the kiosk auto-returns to Welcome for the next person.
///
/// For the demo the card match is a fixed UID (see WelcomeScreen); this screen
/// just performs the "granted" side effects and greets the host.
class HostFastEntryScreen extends ConsumerStatefulWidget {
  final String? hostName;

  const HostFastEntryScreen({super.key, this.hostName});

  @override
  ConsumerState<HostFastEntryScreen> createState() =>
      _HostFastEntryScreenState();
}

class _HostFastEntryScreenState extends ConsumerState<HostFastEntryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  Timer? _returnTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _grantAccess());
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _grantAccess() async {
    debugPrint('HostFastEntry: _grantAccess start');
    // Success cue.
    ref.read(soundServiceProvider).playSuccess();

    final door = ref.read(f10DoorServiceProvider);
    // Open the relay (holds 5s, auto-closes) + green "granted" LED.
    await door.openDoor(hold: const Duration(seconds: 5));
    await door.setLedColor(F10LedColor.green, brightness: 200);
    Future.delayed(const Duration(seconds: 5), () => door.ledOff());

    // Auto-return to Welcome so the kiosk frees up for the next person.
    _returnTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('HostFastEntry: auto-return timer fired');
      _finish();
    });
    debugPrint('HostFastEntry: _grantAccess done, timer armed');
  }

  bool _finished = false;
  void _finish() {
    if (_finished) return;
    _finished = true;
    debugPrint('HostFastEntry: _finish → pop');
    ref.read(f10DoorServiceProvider).ledOff();
    if (!mounted) return;
    // Pop back to the existing Welcome (which keeps its NFC subscription alive)
    // instead of go('/') — that would rebuild Welcome and tear down/re-create
    // the broadcast stream, which is what broke repeated taps.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.hostName ?? '').trim();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success mark — centered circle with a subtle ring.
              Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: KigoTheme.green100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: KigoTheme.green600.withValues(alpha: 0.25),
                        width: 8,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 76,
                      color: KigoTheme.green600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                name.isEmpty ? 'Acceso concedido' : 'Hola, $name',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Pill badge — "entrada rápida".
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: KigoTheme.green100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.nfc_rounded, size: 16, color: KigoTheme.green600),
                      SizedBox(width: 6),
                      Text(
                        'Entrada rápida de anfitrión',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: KigoTheme.green600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Puedes pasar, la puerta está abierta.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Primary CTA — Kigo orange gradient, matches the rest of the app.
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KigoTheme.orangeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Listo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
