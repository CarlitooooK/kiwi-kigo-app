import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/kigo_theme.dart';

/// Support screen — shows a small QR that, when scanned with the Kigo app,
/// places a direct phone call to the support line.
///
/// The QR encodes `SUPPORT:<phone>`; the Kigo app's scan cubit intercepts that
/// prefix and dials `tel:<phone>` (no WhatsApp, no extra view). This screen is
/// reachable from the global "Contactar soporte" button present across flows.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  /// Hardcoded support number for the demo.
  static const String supportPhone = '2218380451';
  String get _qrData => 'SUPPORT:$supportPhone';

  String get _prettyPhone {
    // 2218380451 → 221 838 0451
    if (supportPhone.length == 10) {
      return '${supportPhone.substring(0, 3)} '
          '${supportPhone.substring(3, 6)} '
          '${supportPhone.substring(6)}';
    }
    return supportPhone;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
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
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: KigoTheme.slate900),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              const Icon(Icons.support_agent_rounded,
                  size: 52, color: KigoTheme.kigo500),
              const SizedBox(height: 16),
              const Text(
                'Contactar soporte',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Escanea este código con tu app de Kigo para llamar a soporte.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KigoTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KigoTheme.umbral200),
                  ),
                  child: QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: KigoTheme.slate900,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: KigoTheme.slate900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Also show the number in plain text as a fallback.
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: KigoTheme.umbral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_rounded,
                          size: 18, color: KigoTheme.slate900),
                      const SizedBox(width: 8),
                      Text(
                        _prettyPhone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: KigoTheme.slate900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
