import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mlkit_identity_service.dart';
import 'face_verification_service.dart';

final identityServiceProvider = Provider<MLKitIdentityService>((ref) {
  final service = MLKitIdentityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final faceVerificationServiceProvider = Provider<FaceVerificationService>((ref) {
  final service = FaceVerificationService();
  ref.onDispose(() => service.dispose());
  return service;
});
