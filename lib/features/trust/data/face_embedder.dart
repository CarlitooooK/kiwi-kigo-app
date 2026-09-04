import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device face embedding via MobileFaceNet (TFLite).
///
/// This is the "real AI" behind the Trust Score: instead of comparing facial
/// landmark ratios (the old geometric heuristic), we run a convolutional model
/// that maps a face crop to a 192-d embedding vector. Two photos of the same
/// person land close together in that space; cosine similarity gives a genuine
/// 1:1 verification score.
///
/// Everything runs offline on the device (F10 included) at $0 cost — no API,
/// no network. Model: assets/models/mobilefacenet.tflite (input 112x112x3
/// float32, output 1x192).
class FaceEmbedder {
  static const _modelAsset = 'assets/models/mobilefacenet.tflite';
  static const int _inputSize = 112;
  static const int _embeddingSize = 192;

  Interpreter? _interpreter;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool get isReady => _interpreter != null;

  /// Lazily loads the TFLite model. Safe to call multiple times.
  Future<void> ensureLoaded() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
    } catch (e) {
      debugPrint('FaceEmbedder: could not load model: $e');
      _interpreter = null;
    }
  }

  /// Computes the L2-normalized embedding for the largest face in [imagePath].
  /// Returns null if no face is found or the model is unavailable.
  Future<Float32List?> embedFromFile(String imagePath) async {
    await ensureLoaded();
    if (_interpreter == null) return null;

    // 1. Detect the face to know where to crop.
    final input = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(input);
    if (faces.isEmpty) return null;
    final face = _largestFace(faces);

    // 2. Decode the image bytes.
    final bytes = await _readBytes(imagePath);
    if (bytes == null) return null;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // 3. Crop to the face bounding box (clamped to image bounds), then resize.
    final crop = _cropFace(decoded, face.boundingBox);
    final resized = img.copyResize(crop, width: _inputSize, height: _inputSize);

    // 4. Build the normalized input tensor and run inference.
    final inputTensor = _toInputTensor(resized);
    final output = List.generate(1, (_) => List.filled(_embeddingSize, 0.0));
    _interpreter!.run(inputTensor, output);

    // 5. L2-normalize the embedding for cosine similarity.
    return _l2Normalize(Float32List.fromList(
      output[0].map((e) => e.toDouble()).toList().cast<double>(),
    ));
  }

  /// Cosine similarity in [-1, 1]. For L2-normalized vectors this is the dot
  /// product. Same person typically > 0.6–0.7.
  double cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length) return 0.0;
    double dot = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  Face _largestFace(List<Face> faces) {
    faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    return faces.first;
  }

  img.Image _cropFace(img.Image src, Rect box) {
    // Expand the box ~20% to include forehead/chin, then clamp to bounds.
    final cx = box.center.dx;
    final cy = box.center.dy;
    final half = math.max(box.width, box.height) * 0.6;
    var x = (cx - half).round().clamp(0, src.width - 1);
    var y = (cy - half).round().clamp(0, src.height - 1);
    var w = (half * 2).round();
    var h = (half * 2).round();
    if (x + w > src.width) w = src.width - x;
    if (y + h > src.height) h = src.height - y;
    if (w <= 0 || h <= 0) return src;
    return img.copyCrop(src, x: x, y: y, width: w, height: h);
  }

  /// MobileFaceNet expects float32 in [-1, 1]: (pixel - 127.5) / 128.
  List<List<List<List<double>>>> _toInputTensor(img.Image image) {
    return [
      List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final p = image.getPixel(x, y);
          return [
            (p.r - 127.5) / 128.0,
            (p.g - 127.5) / 128.0,
            (p.b - 127.5) / 128.0,
          ];
        });
      })
    ];
  }

  Float32List _l2Normalize(Float32List v) {
    double sum = 0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm == 0) return v;
    final out = Float32List(v.length);
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / norm;
    }
    return out;
  }

  Future<Uint8List?> _readBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (e) {
      debugPrint('FaceEmbedder: read error: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _faceDetector.close();
  }
}
