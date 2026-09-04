import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';

/// Result of creating a Kigo Verify enrollment.
@immutable
class VerifyEnrollment {
  final bool ok;
  final String? enrollmentId;
  final String? enrollmentUrl;
  final String? status;
  final String? error;

  const VerifyEnrollment._({
    required this.ok,
    this.enrollmentId,
    this.enrollmentUrl,
    this.status,
    this.error,
  });

  const VerifyEnrollment.success({
    required String enrollmentId,
    required String enrollmentUrl,
    String? status,
  }) : this._(ok: true, enrollmentId: enrollmentId, enrollmentUrl: enrollmentUrl, status: status);

  const VerifyEnrollment.failure(String error) : this._(ok: false, error: error);
}

/// Kigo Verify — Face Enrollment (real Kigo ecosystem service).
///
/// We register the visitor's face in Kigo Verify (liveness-backed enrollment).
/// For the on-site kiosk flow the actual recognition is done on-device with
/// MobileFaceNet; the Verify enrollment records the face in Kigo's real system
/// (external_ref = visitorId) so it's part of the ecosystem, not a silo.
///
/// Kigo does NOT deliver the enrollment_url (known bug: recipient_ref empty);
/// our system sends it (WhatsApp/SMS) using metadata.phone. We can also poll
/// GET /v1/enrollments/{id} for status since we have no public webhook.
///
/// SECURITY: the kigo_pk_ dev key can create enrollments and download every
/// face in the FEPRO project. Demo-only via .env; move to a backend for prod.
class KigoVerifyService {
  const KigoVerifyService();

  static const Duration _timeout = Duration(seconds: 15);

  /// Creates an enrollment for a visitor. Returns the enrollment id + url.
  /// [externalRef] should be our visitorId so we can reconcile later.
  Future<VerifyEnrollment> createEnrollment({
    required String externalRef,
    String? phone,
    String? name,
    int ttlHours = 24,
    Map<String, dynamic>? extraMetadata,
  }) async {
    if (!EnvConfig.verifyConfigured) {
      return const VerifyEnrollment.failure('Kigo Verify no configurado');
    }

    final url = Uri.parse('${EnvConfig.verifyBaseUrl}/v1/enrollments');
    final body = <String, dynamic>{
      'external_ref': externalRef,
      'ttl_hours': ttlHours.clamp(1, 72),
      'metadata': {
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (name != null && name.isNotEmpty) 'nombre': name,
        'source': 'kiwi_kigo',
        ...?extraMetadata,
      },
    };

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final req = await client.postUrl(url);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set('x-api-key', EnvConfig.verifyApiKey);
      req.add(utf8.encode(jsonEncode(body)));

      final resp = await req.close().timeout(_timeout);
      final respBody = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final json = jsonDecode(respBody) as Map<String, dynamic>;
        return VerifyEnrollment.success(
          enrollmentId: json['enrollment_id'] as String? ?? '',
          enrollmentUrl: json['enrollment_url'] as String? ?? '',
          status: json['status'] as String?,
        );
      }
      debugPrint('KigoVerify: HTTP ${resp.statusCode} — $respBody');
      return VerifyEnrollment.failure('HTTP ${resp.statusCode}');
    } on TimeoutException {
      return const VerifyEnrollment.failure('Tiempo de espera agotado');
    } catch (e) {
      debugPrint('KigoVerify: error $e');
      return VerifyEnrollment.failure(e.toString());
    } finally {
      client?.close(force: true);
    }
  }

  /// Polls the status of an enrollment (our safety net without a webhook).
  /// Returns the status string (PENDING/COMPLETED/…) or null on error.
  Future<String?> getStatus(String enrollmentId) async {
    if (!EnvConfig.verifyConfigured || enrollmentId.isEmpty) return null;
    final url = Uri.parse('${EnvConfig.verifyBaseUrl}/v1/enrollments/$enrollmentId');
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final req = await client.getUrl(url);
      req.headers.set('x-api-key', EnvConfig.verifyApiKey);
      final resp = await req.close().timeout(_timeout);
      final respBody = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final json = jsonDecode(respBody) as Map<String, dynamic>;
        return json['status'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('KigoVerify.getStatus: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}

final kigoVerifyServiceProvider = Provider<KigoVerifyService>((ref) {
  return const KigoVerifyService();
});
