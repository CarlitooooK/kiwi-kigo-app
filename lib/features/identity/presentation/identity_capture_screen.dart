import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../../shared/widgets/journey_stepper.dart';
import '../../../shared/widgets/kigo_loader.dart';
import '../domain/identity_service_provider.dart';
import '../domain/identity_document_service.dart';
import '../../../shared/widgets/kigo_camera_overlay.dart';

/// Identity Capture Screen — Captures the visitor's ID document.
class IdentityCaptureScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const IdentityCaptureScreen({super.key, this.visitData});

  @override
  ConsumerState<IdentityCaptureScreen> createState() =>
      _IdentityCaptureScreenState();
}

class _IdentityCaptureScreenState extends ConsumerState<IdentityCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _capturedImage;
  Uint8List? _imageBytes;
  bool _isCapturing = false;
  bool _isProcessing = false;
  IdentityResult? _ocrResult;
  int _attempts = 0;

  Future<void> _captureId() async {
    _attempts++;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.black,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: KigoCameraOverlay(
          useFrontCamera: false,
          isIdCard: true,
          onCapture: (image) async {
            Navigator.pop(context);
            setState(() => _isProcessing = true);
            
            try {
              final bytes = await image.readAsBytes();
              
              // Process OCR
              final ocrService = ref.read(identityServiceProvider);
              final result = await ocrService.processDocument(
                imagePath: image.path,
                documentType: 'ID_FRONT',
              );

              if (mounted) {
                setState(() {
                  _capturedImage = image;
                  _imageBytes = bytes;
                  _ocrResult = result;
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
      _capturedImage = null;
      _imageBytes = null;
      _ocrResult = null;
    });
  }

  void _confirm() {
    final data = {
      ...?widget.visitData,
      '_id_image_path': _capturedImage!.path,
      '_id_image_bytes': _imageBytes,
      '_ocr_score': _ocrResult?.confidence ?? 0.0,
      '_ocr_data': _ocrResult?.extractedData ?? {},
      '_id_attempts': _attempts,
    };
    context.push('/photo', extra: data);
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
              const JourneyStepper(current: JourneyStep.identity),

              const SizedBox(height: 24),

              // Title
              Text(
                _capturedImage == null
                    ? 'Captura tu identificación'
                    : 'Verifica la imagen',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: KigoTheme.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _capturedImage == null
                    ? 'Coloca tu INE, pasaporte o identificación oficial '
                      'frente a la cámara'
                    : 'Asegúrate de que la información sea legible',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: KigoTheme.slate500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Image area
              Expanded(
                child: _isProcessing
                    ? const Center(child: KigoLoader(message: 'Extrayendo información...'))
                    : _capturedImage == null
                        ? _buildCaptureArea()
                        : _buildPreviewArea(),
              ),

              const SizedBox(height: 24),

              // OCR Result / Score
              if (_ocrResult != null && !_isProcessing) ...[
                _buildScoreIndicator(_ocrResult!.confidence),
                const SizedBox(height: 16),
              ],

              // Actions
              if (_isCapturing)
                const KigoLoader(message: 'Abriendo cámara')
              else if (_capturedImage == null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KigoTheme.orangeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MaterialButton(
                    onPressed: _captureId,
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
                          'Capturar identificación',
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
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.badge_outlined,
            size: 64,
            color: KigoTheme.umbral300,
          ),
          SizedBox(height: 16),
          Text(
            'Tu identificación aparecerá aquí',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: KigoTheme.gray500,
            ),
          ),
          SizedBox(height: 24),
          _Tip(icon: Icons.wb_sunny_outlined, text: 'Buena iluminación'),
          _Tip(icon: Icons.crop_free, text: 'Sin reflejos ni sombras'),
          _Tip(icon: Icons.text_fields, text: 'Texto legible'),
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
          _imageBytes != null
              ? Image.memory(
                  _imageBytes!,
                  fit: BoxFit.contain,
                )
              : const Center(
                  child: Icon(Icons.image, size: 48, color: KigoTheme.umbral300),
                ),
          if (_ocrResult != null && _ocrResult!.isValid)
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
                    Icon(Icons.check_circle, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Datos extraídos',
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

  Widget _buildScoreIndicator(double score) {
    Color color = score > 0.7 ? KigoTheme.green600 : score > 0.4 ? Colors.orange : KigoTheme.red500;
    String label = score > 0.7 ? 'Excelente captura' : score > 0.4 ? 'Lectura parcial' : 'Baja legibilidad';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '${(score * 100).toInt()}% (Calidad OCR)',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              color: color,
              backgroundColor: color.withValues(alpha: 0.2),
              minHeight: 6,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Este puntaje mide qué tan legibles son tus datos.',
              style: TextStyle(fontSize: 10, color: KigoTheme.slate500),
            ),
          ),
        ],
      ),
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
