import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'kigo_loader.dart';

class KigoCameraOverlay extends StatefulWidget {
  final bool useFrontCamera;
  final bool isIdCard;
  final Function(XFile) onCapture;

  const KigoCameraOverlay({
    super.key,
    this.useFrontCamera = true,
    this.isIdCard = false,
    required this.onCapture,
  });

  @override
  State<KigoCameraOverlay> createState() => _KigoCameraOverlayState();
}

class _KigoCameraOverlayState extends State<KigoCameraOverlay> {
  CameraController? _controller;
  bool _isInitialized = false;
  // The F10 kiosk mounts its camera sensor rotated 180°, so the preview shows
  // upside-down. We rotate the preview only on the F10 (detected natively).
  bool _flip180 = false;

  static const MethodChannel _f10Channel = MethodChannel('kigo.welcome/f10_door');

  @override
  void initState() {
    super.initState();
    _detectF10();
    _initializeCamera();
  }

  Future<void> _detectF10() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final isF10 = await _f10Channel.invokeMethod<bool>('isAvailable') ?? false;
      if (mounted && isF10) setState(() => _flip180 = true);
    } catch (_) {
      // Not the F10 (or channel absent) → no flip.
    }
  }

  /// Turns the F10 white LED on/off as fill light for the capture (better OCR,
  /// selfie and face-embedding quality). No-op on non-F10 devices.
  Future<void> _fillLight(bool on) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      // type 3 = white (per F10 SDK controlLedBright). 200 = calibrated brightness.
      await _f10Channel.invokeMethod('setLedColor', {
        'type': 3,
        'progress': on ? 200 : 0,
      });
    } catch (_) {
      // channel absent / non-F10 → ignore
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == (widget.useFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      // Fill light on while the camera is open (improves capture quality).
      await _fillLight(true);
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _fillLight(false); // turn off the fill light when leaving the camera
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final image = await _controller!.takePicture();
      // NOTE: only the live PREVIEW needs the 180° flip on the F10 (it renders
      // the raw sensor). The captured JPEG already comes out upright, so we do
      // NOT rotate the file — doing so would invert the saved photo.
      widget.onCapture(image);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: KigoLoader(message: 'Iniciando cámara...'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Use FittedBox to ensure the preview covers the screen without distortion
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                // On the F10 the sensor is mounted 180°; rotate the preview.
                child: _flip180
                    ? RotatedBox(quarterTurns: 2, child: CameraPreview(_controller!))
                    : CameraPreview(_controller!),
              ),
            ),
          ),
          
          // Overlay mask
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: widget.isIdCard 
                    ? Builder(
                        builder: (context) {
                          // Responsive ID guide: ~90% of the screen width, capped,
                          // keeping a credit-card / INE aspect ratio (~1.585:1).
                          final screenW = MediaQuery.of(context).size.width;
                          final w = (screenW * 0.9).clamp(320.0, 640.0);
                          final h = w / 1.585;
                          return Container(
                            width: w,
                            height: h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 280,
                        height: 400,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(150),
                        ),
                      ),
                ),
              ],
            ),
          ),

          // Controls
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  widget.isIdCard 
                    ? 'Centra el frente de tu identificación'
                    : 'Centra tu rostro en el óvalo',
                  style: const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                // Face-only tip: unobstructed face → better recognition.
                if (!widget.isIdCard) ...[
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Retira lentes de sol, gorras o accesorios que cubran tu cara',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Back button
          Positioned(
            top: 48,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
