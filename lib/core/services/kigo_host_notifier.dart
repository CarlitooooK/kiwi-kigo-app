import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';

/// Result of a host-notification attempt.
@immutable
class NotifyResult {
  final bool sent;
  final String? error;
  const NotifyResult.sent() : sent = true, error = null;
  const NotifyResult.failed(this.error) : sent = false;
}

/// Sends a real push to the visit host through the Kigo Notifications API v2.
///
/// This closes the PRD "notify the host" requirement with Kigo's real channel
/// (push + deeplink), not just a journey event.
///
/// SECURITY: the `sk_live_` key is a production service key. For the FEPRO demo
/// it is read from .env (git-ignored) and the call goes straight from the app.
/// In production this must run on a backend so the key never ships in the APK.
/// The API contract is identical either way — moving it later changes nothing
/// functionally.
class KigoHostNotifier {
  const KigoHostNotifier();

  static const Duration _timeout = Duration(seconds: 10);

  /// Notifies the host that a visitor is waiting for authorization.
  ///
  /// [hostLegacyUserId] is the Kigo user to push to. During the demo we use a
  /// fixed test user (EnvConfig.testHostLegacyUserId) so the push lands on a
  /// real device.
  Future<NotifyResult> notifyVisitorWaiting({
    required int hostLegacyUserId,
    required String visitorName,
    required String visitId,
    String? area,
    String? purpose,
  }) async {
    if (!EnvConfig.notificationsConfigured) {
      return const NotifyResult.failed('Notifications no configuradas');
    }
    if (hostLegacyUserId <= 0) {
      return const NotifyResult.failed('Host inválido');
    }

    final url = Uri.parse('${EnvConfig.notificationsBaseUrl}/v2/');
    final body = <String, dynamic>{
      'app': 'kigo',
      'users': [
        {'legacyUserId': hostLegacyUserId}
      ],
      'subTypeId': EnvConfig.notificationsSubtypeId,
      'title': 'Tienes una visita esperando',
      'message': _message(visitorName, purpose, area),
      'action': {
        'type': 'deeplink',
        // Deep link the host to the authorization mini-app for this visit.
        'action': 'kigo://welcome/authorize?visit=$visitId',
        'label': 'Autorizar',
      },
      'channels': [
        {'type': 'push', 'value': <String>[]}
      ],
      'pushExtras': {
        'sound': 'default',
        'data': {'screen': 'welcome_authorize', 'visit_id': visitId},
      },
    };

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final req = await client.postUrl(url);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set('x-api-key', EnvConfig.notificationsApiKey);
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      req.add(utf8.encode(jsonEncode(body)));

      final resp = await req.close().timeout(_timeout);
      final status = resp.statusCode;
      // Drain the body (and log on error for diagnostics).
      final respBody = await resp.transform(utf8.decoder).join();

      if (status >= 200 && status < 300) {
        return const NotifyResult.sent();
      }
      debugPrint('KigoHostNotifier: HTTP $status — $respBody');
      return NotifyResult.failed('HTTP $status');
    } on TimeoutException {
      return const NotifyResult.failed('Tiempo de espera agotado');
    } catch (e) {
      debugPrint('KigoHostNotifier: error $e');
      return NotifyResult.failed(e.toString());
    } finally {
      client?.close(force: true);
    }
  }

  String _message(String visitorName, String? purpose, String? area) {
    final who = visitorName.trim().isEmpty ? 'Un visitante' : visitorName.trim();
    final buffer = StringBuffer('$who está en recepción');
    if ((purpose ?? '').isNotEmpty) buffer.write(' · ${purpose!.trim()}');
    if ((area ?? '').isNotEmpty) buffer.write(' · ${area!.trim()}');
    buffer.write('. Abre para autorizar el acceso.');
    return buffer.toString();
  }
}

final kigoHostNotifierProvider = Provider<KigoHostNotifier>((ref) {
  return const KigoHostNotifier();
});
