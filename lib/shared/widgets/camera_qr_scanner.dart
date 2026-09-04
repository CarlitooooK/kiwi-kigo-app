import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../core/theme/kigo_theme.dart';

/// Camera-based QR scanner (ML Kit) for devices WITHOUT the F10's built-in
/// hardware reader — e.g. a tablet used as an extra kiosk for the demo.
///
/// Streams frames from the camera and runs the ML Kit barcode scanner until it
/// finds a QR, then calls [onScan] once with the decoded value.
class CameraQrScanner extends StatefulWidget {
  const CameraQrScanner({super.key, required this.onScan});

  final void Function(String code) onScan;

  @override
  State<CameraQrScanner> createState() => _CameraQrScannerState();
}

class _CameraQrScannerState extends State<CameraQrScanner> {
  CameraController? _controller;
  final BarcodeScanner _scanner =
      BarcodeScanner(formats: [BarcodeFormat.qrCode]);
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No hay cámara disponible.');
        return;
      }
      // Prefer the back camera for scanning a QR held up to the device.
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) return;
      _controller = controller;
      setState(() {});
      await controller.startImageStream(_onFrame);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la cámara.');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _done) return;
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input != null) {
        final barcodes = await _scanner.processImage(input);
        for (final b in barcodes) {
          final value = b.rawValue;
          if (value != null && value.trim().isNotEmpty) {
            _done = true;
            widget.onScan(value.trim());
            break;
          }
        }
      }
    } catch (_) {
      // ignore transient frame errors
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(
          controller.description.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    // For nv21 the planes are contiguous; use the first plane's bytes.
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _scanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (controller != null && controller.value.isInitialized)
              Center(child: CameraPreview(controller))
            else if (_error != null)
              Center(
                child: Text(_error!,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            // Scan frame overlay
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: KigoTheme.kigo500, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            // Hint + close
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                'Coloca el QR dentro del recuadro',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
