import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/kigo_loader.dart';
import '../../identity/domain/identity_service_provider.dart';
import '../../identity/domain/face_verification_service.dart';
import '../../../shared/widgets/kigo_camera_overlay.dart';

/// Photo Capture Screen — Captures the visitor's selfie.
class PhotoCaptureScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const PhotoCaptureScreen({super.key, this.visitData});

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _capturedPhoto;
  Uint8List? _photoBytes;
  bool _isCapturing = false;
  bool _isProcessing = false;
  LivenessResult? _livenessResult;
  double? _comparisonScore;
  int _attempts = 0;

  Future<void> _capturePhoto() async {
    _attempts++;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.black,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: KigoCameraOverlay(
          useFrontCamera: true,
          onCapture: (image) async {
            Navigator.pop(context);
            setState(() => _isProcessing = true);
            
            try {
              final bytes = await image.readAsBytes();
              final faceService = ref.read(faceVerificationServiceProvider);
              
              // 1. Check Liveness
              final liveness = await faceService.checkLiveness(image.path);
              
              // 2. Compare with ID Image (if available)
              double comparison = 0.0;
              final idPath = widget.visitData?['_id_image_path'] as String?;
              if (idPath != null) {
                comparison = await faceService.compareFaces(idPath, image.path);
              }

              if (mounted) {
                setState(() {
                  _capturedPhoto = image;
                  _photoBytes = bytes;
                  _livenessResult = liveness;
                  _comparisonScore = comparison;
                  _isProcessing = false;
                });
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isProcessing = false);
              }
            }
          },
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _capturedPhoto = null;
      _photoBytes = null;
      _livenessResult = null;
      _comparisonScore = null;
    });
  }

  void _confirm() {
    final data = {
      ...?widget.visitData,
      '_selfie_path': _capturedPhoto!.path,
      '_selfie_bytes': _photoBytes,
      '_liveness_score': _livenessResult?.score ?? 0.0,
      '_comparison_score': _comparisonScore ?? 0.0,
      '_is_live': _livenessResult?.isLive ?? false,
      '_selfie_attempts': _attempts,
    };
    context.push('/processing', extra: data);
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
              const SizedBox(height: 24),

              // Back button
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
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: KigoTheme.slate900,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Step indicator
              const _StepIndicator(currentStep: 2, totalSteps: 3),

              const SizedBox(height: 24),

              // Title
              Text(
                _capturedPhoto == null
                    ? 'Captura tu fotografía'
                    : 'Verifica tu foto',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _capturedPhoto == null
                    ? 'Necesitamos una fotografía de tu rostro '
                      'para completar el registro'
                    : 'Asegúrate de que tu rostro sea visible y la imagen sea clara',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Photo area
              Expanded(
                child: _isProcessing
                    ? const Center(child: KigoLoader(message: 'Validando identidad...'))
                    : _capturedPhoto == null
                        ? _buildCaptureArea()
                        : _buildPreviewArea(),
              ),

              const SizedBox(height: 24),

              // Liveness Score
              if (_livenessResult != null && !_isProcessing) ...[
                _buildLivenessIndicator(_livenessResult!),
                const SizedBox(height: 16),
              ],

              // Actions
              if (_isCapturing)
                const KigoLoader(message: 'Abriendo cámara')
              else if (_capturedPhoto == null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KigoTheme.orangeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MaterialButton(
                    onPressed: _capturePhoto,
                    height: 46,
                    minWidth: double.infinity,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: KigoTheme.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tomar fotografía',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: KigoTheme.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KigoTheme.orangeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MaterialButton(
                    onPressed: _confirm,
                    height: 46,
                    minWidth: double.infinity,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KigoTheme.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tomar otra foto'),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureArea() {
    return Container(
      decoration: BoxDecoration(
        color: KigoTheme.umbral100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KigoTheme.umbral200, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Face outline circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: KigoTheme.kigo500.withValues(alpha: 0.4),
                width: 3,
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              size: 80,
              color: KigoTheme.umbral300,
            ),
          ),
          const SizedBox(height: 24),
          const _Tip(icon: Icons.wb_sunny_outlined, text: 'Buena iluminación'),
          const _Tip(icon: Icons.face_rounded, text: 'Rostro visible y centrado'),
          const _Tip(icon: Icons.visibility, text: 'Sin lentes oscuros ni cubrebocas'),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _photoBytes != null
              ? Image.memory(
                  _photoBytes!,
                  fit: BoxFit.contain,
                )
              : const Center(
                  child: Icon(Icons.image, size: 48, color: KigoTheme.umbral300),
                ),
          if (_livenessResult != null && _livenessResult!.isLive)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: KigoTheme.green600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      'Rostro detectado',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLivenessIndicator(LivenessResult result) {
    final color = result.isLive ? KigoTheme.green600 : result.score > 0.4 ? Colors.orange : KigoTheme.red500;
    final compScore = _comparisonScore ?? 0.0;
    final compColor = compScore > 0.7 ? KigoTheme.green600 : compScore > 0.4 ? Colors.orange : KigoTheme.red500;

    return Column(
      children: [
        // Liveness Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Detección de vida', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Text('${(result.score * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: result.score, color: color, backgroundColor: color.withValues(alpha: 0.1), minHeight: 4),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Comparison Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: compColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: compColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Coincidencia con ID', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Text('${(compScore * 100).toInt()}%', style: TextStyle(color: compColor, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: compScore, color: compColor, backgroundColor: compColor.withValues(alpha: 0.1), minHeight: 4),
            ],
          ),
        ),
        if (!result.isLive)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(result.errorMessage ?? 'Error de validación', style: TextStyle(color: KigoTheme.red500, fontSize: 11)),
          ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        final isCurrent = index == currentStep - 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? KigoTheme.kigo500 : KigoTheme.umbral200,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: KigoTheme.slate500),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: KigoTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
