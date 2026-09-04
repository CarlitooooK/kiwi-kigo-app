import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/data/journey_repository.dart';
import '../../../core/theme/kigo_theme.dart';
import '../../trust/data/trust_providers.dart';
import '../../trust/data/face_enrollment_repository.dart';
import '../../../core/services/kigo_verify_service.dart';
import '../../../core/utils/string_similarity.dart';

/// Evidence Processing Screen — Fluid animated upload + trust evaluation.
class EvidenceProcessingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? visitData;

  const EvidenceProcessingScreen({super.key, this.visitData});

  @override
  ConsumerState<EvidenceProcessingScreen> createState() =>
      _EvidenceProcessingScreenState();
}

class _EvidenceProcessingScreenState
    extends ConsumerState<EvidenceProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  int _currentStepIndex = 0;
  bool _hasError = false;
  String? _errorMessage;

  final _steps = const [
    _ProcessStep(
      label: 'Subiendo identificación',
      icon: Icons.badge_outlined,
    ),
    _ProcessStep(
      label: 'Subiendo fotografía',
      icon: Icons.camera_alt_outlined,
    ),
    _ProcessStep(
      label: 'Validando identidad',
      icon: Icons.verified_user_outlined,
    ),
    _ProcessStep(
      label: 'Evaluando calidad del registro',
      icon: Icons.analytics_outlined,
    ),
    _ProcessStep(
      label: 'Listo',
      icon: Icons.check_circle_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _processEvidence();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _animateToProgress(double target) {
    final currentValue = _progressAnimation.value;
    _progressAnimation = Tween<double>(begin: currentValue, end: target).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOutCubic),
    );
    _progressController.forward(from: 0);
  }

  void _advanceStep(int index, double progress) {
    if (!mounted) return;
    setState(() => _currentStepIndex = index);
    _animateToProgress(progress);
  }

  Future<void> _processEvidence() async {
    final visitId = widget.visitData?['id'] as String?;
    if (visitId == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No se encontró la visita. Regresa e intenta de nuevo.';
      });
      return;
    }

    try {
      final client = ref.read(supabaseProvider);
      final journeyRepo = ref.read(journeyRepositoryProvider);
      final uuid = const Uuid();

      // Step 1 & 2 & 3: Calculate everything first
      _advanceStep(1, 0.3);

      final idPath = widget.visitData?['_id_image_path'] as String?;
      final selfiePath = widget.visitData?['_selfie_path'] as String?;

      // Inputs for the Trust Score engine.
      final ocrScore = (widget.visitData?['_ocr_score'] as num?)?.toDouble() ?? 0.0;
      final livenessScore = (widget.visitData?['_liveness_score'] as num?)?.toDouble() ?? 0.0;

      final visitor = widget.visitData?['visitors'] as Map<String, dynamic>?;
      final formName = '${visitor?['first_name'] ?? ''} ${visitor?['last_name'] ?? ''}';
      final ocrData = widget.visitData?['_ocr_data'] as Map<dynamic, dynamic>?;
      final ocrName = ocrData?['name'] as String?;
      final nameMatchScore = StringSimilarity.compare(formName, ocrName);

      final idAttempts = (widget.visitData?['_id_attempts'] as int?) ?? 1;
      final selfieAttempts = (widget.visitData?['_selfie_attempts'] as int?) ?? 1;

      // === Real AI Trust Score (engine AI_V1) ===
      // Face match is now a genuine MobileFaceNet embedding similarity, not a
      // landmark-ratio heuristic. The service also blends OCR, name and liveness.
      final trustService = ref.read(trustScoreServiceProvider);
      final evaluation = await trustService.evaluate(
        visitId: visitId,
        evidenceData: {
          'id_image_path': idPath,
          'selfie_path': selfiePath,
          'ocr_score': ocrScore,
          'name_match_score': nameMatchScore,
          'liveness_score': livenessScore,
          'id_attempts': idAttempts,
          'selfie_attempts': selfieAttempts,
        },
      );

      final finalScore = evaluation.score;
      final comparisonScore =
          (evaluation.factors['face_match'] as num?)?.toDouble() ?? 0.0;

      // Step 4: Upload and Save everything
      _advanceStep(2, 0.6);

      // Upload ID
      String? idStoragePath;
      final idBytes = widget.visitData?['_id_image_bytes'] as Uint8List?;
      if (idBytes != null) {
        idStoragePath = '$visitId/id_front_${uuid.v4()}.jpg';
        await client.storage.from('visit-evidence').uploadBinary(
          idStoragePath,
          idBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        await client.from('visit_evidence').insert({
          'visit_id': visitId,
          'type': 'ID_FRONT',
          'storage_path': idStoragePath,
          'metadata': {
            'quality': 'good',
            'ocr_score': ocrScore,
            'name_match_score': nameMatchScore,
            'attempts': idAttempts,
            'captured_data': {
              'name': ocrData?['name'],
              'curp': ocrData?['curp'],
              'elector_key': ocrData?['elector_key'],
              'birth_date': ocrData?['birth_date'],
            },
          },
        });
      }

      // Upload Selfie
      String? selfieStoragePath;
      final selfieBytes = widget.visitData?['_selfie_bytes'] as Uint8List?;
      if (selfieBytes != null) {
        selfieStoragePath = '$visitId/selfie_${uuid.v4()}.jpg';
        await client.storage.from('visitor-photos').uploadBinary(
          selfieStoragePath,
          selfieBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        await client.from('visit_evidence').insert({
          'visit_id': visitId,
          'type': 'SELFIE',
          'storage_path': selfieStoragePath,
          'metadata': {
            'quality': 'good',
            'liveness_score': livenessScore,
            'comparison_score': comparisonScore,
            'attempts': selfieAttempts,
          },
        });

        // === Face enrollment (Idea 1) ===
        // If the visitor consented to face enrollment, index their face for
        // future visits: on-device embedding (recognition) + Kigo Verify
        // (registers the face in the real Kigo ecosystem). Non-blocking: any
        // failure here must NOT stop the access flow.
        final faceConsent = widget.visitData?['_face_consent'] == true;
        final visitorId = visitor?['id'] as String?;
        if (faceConsent && visitorId != null && selfiePath != null) {
          await _enrollFace(
            visitId: visitId,
            visitorId: visitorId,
            selfiePath: selfiePath,
            selfieStoragePath: selfieStoragePath,
            visitorName: formName.trim(),
            phone: visitor?['phone'] as String?,
          );
        }
      }

      // Save Trust Evaluation
      _advanceStep(3, 0.85);

      await client.from('trust_evaluations').insert({
        'visit_id': visitId,
        'score': finalScore,
        'factors': evaluation.factors,
        'engine': evaluation.engine,
      });

      await journeyRepo.logEvent(
        visitId: visitId,
        eventType: 'IDENTITY_VALIDATED',
        payload: {
          'ocr_score': ocrScore,
          'liveness_score': livenessScore,
          'comparison_score': comparisonScore,
          'name_match_score': nameMatchScore,
          'final_trust_score': finalScore,
          'engine': evaluation.engine,
        },
      );

      // Step 5: Done
      _advanceStep(4, 1.0);
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      final resultData = {
        ...?widget.visitData,
        '_trust_score': finalScore,
        '_trust_factors': {
          'ocr': ocrScore,
          'name_match': nameMatchScore,
          'liveness': livenessScore,
          'face_match': comparisonScore,
        },
        '_evidence_complete': true,
      };
      resultData.remove('_id_image_bytes');
      resultData.remove('_selfie_bytes');

      context.pushReplacement('/processing-result', extra: resultData);
    } catch (e) {
      debugPrint('Error en procesamiento de evidencia: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error al procesar y subir la evidencia. Por favor, verifica que los buckets de storage existan en tu Supabase. ($e)';
      });
    }
  }

  /// Enrolls the visitor's face for future visits (Idea 1). On-device embedding
  /// for recognition + Kigo Verify enrollment for the real ecosystem. Fully
  /// non-blocking: swallows errors so the access flow is never interrupted.
  Future<void> _enrollFace({
    required String visitId,
    required String visitorId,
    required String selfiePath,
    String? selfieStoragePath,
    String? visitorName,
    String? phone,
  }) async {
    try {
      // 1. On-device embedding (MobileFaceNet) from the captured selfie.
      final embedder = ref.read(faceEmbedderProvider);
      final embedding = await embedder.embedFromFile(selfiePath);
      if (embedding == null) {
        debugPrint('FaceEnroll: no face embedding produced, skipping');
        return;
      }

      // 2. Kigo Verify — register the face in the real Kigo ecosystem.
      String? kigoId;
      String? kigoStatus;
      final verify = ref.read(kigoVerifyServiceProvider);
      final result = await verify.createEnrollment(
        externalRef: visitorId,
        phone: phone,
        name: visitorName,
        extraMetadata: {'visit_id': visitId},
      );
      if (result.ok) {
        kigoId = result.enrollmentId;
        kigoStatus = result.status;
      }

      // 3. Persist the enrollment (embedding + Kigo ids) for recognition.
      await ref.read(faceEnrollmentRepositoryProvider).enroll(
            visitorId: visitorId,
            embedding: embedding,
            photoPath: selfieStoragePath,
            kigoEnrollmentId: kigoId,
            kigoStatus: kigoStatus,
          );

      await ref.read(journeyRepositoryProvider).logEvent(
            visitId: visitId,
            eventType: 'FACE_ENROLLED',
            payload: <String, dynamic>{
              'engine': 'MobileFaceNet',
              'kigo_verify': result.ok,
              'kigo_enrollment_id': kigoId,
            },
          );
    } catch (e) {
      debugPrint('FaceEnroll: non-blocking error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _hasError, // Only allow back if there's an error
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _hasError ? _buildError() : _buildProcessing(),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    return Column(
      children: [
        const Spacer(flex: 2),

        // Animated pulsing icon
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: KigoTheme.kigo500.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                _steps[_currentStepIndex].icon,
                key: ValueKey(_currentStepIndex),
                size: 36,
                color: KigoTheme.kigo500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Title
        const Text(
          'Preparando tu acceso',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: KigoTheme.slate900,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Animated step label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _steps[_currentStepIndex].label,
            key: ValueKey(_steps[_currentStepIndex].label),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: KigoTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 40),

        // Smooth animated progress bar
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 4,
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value,
                      color: KigoTheme.kigo500,
                      backgroundColor: KigoTheme.umbral200,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Step indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_steps.length - 1, (index) {
                    final isCompleted = index < _currentStepIndex;
                    final isActive = index == _currentStepIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? KigoTheme.green600
                            : isActive
                                ? KigoTheme.kigo500
                                : KigoTheme.umbral200,
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),

        const Spacer(flex: 3),

        // Reassurance text
        const Text(
          'Esto toma solo unos segundos',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: KigoTheme.gray400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline_rounded, size: 56, color: KigoTheme.red500),
        const SizedBox(height: 24),
        const Text(
          'Error al procesar',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: KigoTheme.slate900,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Ocurrió un error. Intenta de nuevo.',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: KigoTheme.gray500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: KigoTheme.orangeGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: MaterialButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _currentStepIndex = 0;
                });
                _animateToProgress(0);
                _processEvidence();
              },
              height: 46,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }
}

class _ProcessStep {
  final String label;
  final IconData icon;

  const _ProcessStep({required this.label, required this.icon});
}
