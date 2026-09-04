import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math' as math;

class FaceVerificationService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // For blinking
      enableLandmarks: true,
      enableTracking: true,
    ),
  );

  /// Analyzes a selfie for liveness/quality.
  ///
  /// True liveness needs multiple frames (blink/turn); with a single capture we
  /// compute an honest, VARIABLE quality-of-face score from ML Kit signals
  /// instead of fixed increments (the old version summed constants and always
  /// hit 1.0). Signals: eyes open, natural head pose, face size/framing, and a
  /// smile bonus. Returns 0.0–1.0.
  Future<LivenessResult> checkLiveness(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return LivenessResult.failure('No se detectó ningún rostro');
      }
      if (faces.length > 1) {
        return LivenessResult.failure('Se detectó más de un rostro');
      }

      final face = faces.first;
      double score = 0.0;

      // 1) Eyes open (0..0.35). Uses the real probability; closed eyes / a photo
      //    with half-lidded eyes scores lower. If classification is missing,
      //    give a small neutral credit.
      final le = face.leftEyeOpenProbability;
      final re = face.rightEyeOpenProbability;
      if (le != null && re != null) {
        final eyesOpen = ((le + re) / 2).clamp(0.0, 1.0);
        score += 0.35 * eyesOpen;
      } else {
        score += 0.15;
      }

      // 2) Natural head pose (0..0.30). A tiny non-zero angle suggests a real 3D
      //    head, not a flat photo held perfectly straight; but extreme angles
      //    (looking away) are penalized. Sweet spot ~2°–18° on Y.
      final y = face.headEulerAngleY?.abs() ?? 0.0;
      final z = face.headEulerAngleZ?.abs() ?? 0.0;
      double poseScore;
      if (y < 1.0) {
        poseScore = 0.10; // suspiciously flat (possible photo of a photo)
      } else if (y <= 18.0) {
        poseScore = 0.30; // natural
      } else if (y <= 30.0) {
        poseScore = 0.18; // turned a bit much
      } else {
        poseScore = 0.05; // looking away
      }
      if (z > 20.0) poseScore *= 0.6; // heavily tilted → likely bad capture
      score += poseScore;

      // 3) Face size / framing (0..0.25). A real close selfie fills a good part
      //    of the frame; a tiny face (photo far away) scores low. We only have
      //    the bounding box here, so use its area heuristically via landmarks
      //    spread (eye distance) as a proxy for closeness.
      final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
      final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
      if (leftEye != null && rightEye != null) {
        final eyeDist = math.sqrt(
          math.pow(rightEye.x - leftEye.x, 2) + math.pow(rightEye.y - leftEye.y, 2),
        );
        // eyeDist grows with closeness. ~60px+ is a good close selfie on the F10.
        final framing = (eyeDist / 90.0).clamp(0.0, 1.0);
        score += 0.25 * framing;
      } else {
        score += 0.10;
      }

      // 4) Smile bonus (0..0.10) — a natural expression is a mild liveness cue.
      final smile = face.smilingProbability;
      if (smile != null) score += 0.10 * smile.clamp(0.0, 1.0);

      return LivenessResult.success(score: score.clamp(0.0, 1.0));
    } catch (e) {
      return LivenessResult.failure('Error en prueba de vida: $e');
    }
  }

  /// Compares two images to see if they contain the same person using facial geometry ratios.
  Future<double> compareFaces(String idImagePath, String selfiePath) async {
    try {
      final idInput = InputImage.fromFilePath(idImagePath);
      final selfieInput = InputImage.fromFilePath(selfiePath);
      
      final idFaces = await _faceDetector.processImage(idInput);
      final selfieFaces = await _faceDetector.processImage(selfieInput);
      
      if (idFaces.isEmpty || selfieFaces.isEmpty) {
        return 0.05; // Critical penalty
      }

      final f1 = idFaces.first;
      final f2 = selfieFaces.first;

      // Extract basic geometric ratios to compare "facial structure"
      // Note: This is an offline heuristic for 1:1 verification
      Map<String, double> getRatios(Face face) {
        final Map<String, double> ratios = {};
        
        final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
        final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
        final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
        final mouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;

        if (leftEye != null && rightEye != null && nose != null && mouth != null) {
          double eyeDist = math.sqrt(math.pow(rightEye.x - leftEye.x, 2) + math.pow(rightEye.y - leftEye.y, 2));
          double eyeToNose = math.sqrt(math.pow(nose.x - (leftEye.x + rightEye.x)/2, 2) + math.pow(nose.y - (leftEye.y + rightEye.y)/2, 2));
          double noseToMouth = math.sqrt(math.pow(mouth.x - nose.x, 2) + math.pow(mouth.y - nose.y, 2));

          ratios['eye_nose'] = eyeDist / eyeToNose;
          ratios['nose_mouth'] = eyeDist / noseToMouth;
        }
        return ratios;
      }

      final r1 = getRatios(f1);
      final r2 = getRatios(f2);

      if (r1.isEmpty || r2.isEmpty) return 0.5; // Could not calculate geometry

      // Compare ratios (The closer to 0 difference, the higher the score)
      double diff = 0.0;
      r1.forEach((key, val) {
        if (r2.containsKey(key)) {
          diff += (val - r2[key]!).abs();
        }
      });

      // Ratios are typically around 1.0 - 2.0, so a diff of > 0.5 is huge.
      double similarity = 1.0 - (diff * 2); 
      
      return similarity.clamp(0.1, 0.98); 
    } catch (e) {
      return 0.0;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}

class LivenessResult {
  final bool isLive;
  final double score;
  final String? errorMessage;

  LivenessResult({required this.isLive, required this.score, this.errorMessage});

  factory LivenessResult.success({required double score}) {
    return LivenessResult(isLive: score > 0.7, score: score);
  }

  factory LivenessResult.failure(String error) {
    return LivenessResult(isLive: false, score: 0, errorMessage: error);
  }
}
