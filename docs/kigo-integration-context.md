# Kigo Ecosystem — Puntos de Integración autorizados para Kigo Welcome (kiwi_kigo)

Este documento resume TODO lo que la empresa Kigo autorizó para que el proyecto
del reto FEPRO (kiwi_kigo, kiosko Self Check-In del segmento Corporativo) conviva
con el ecosistema real de Kigo. NO es documentación oficial — es contexto derivado
del material compartido por la empresa y de la lectura del código de kigo_app.

## Las 3 integraciones autorizadas + el hardware

### 1. Kigo Verify — Face Enrollment (servicio remoto, web + webhook)
Servicio de enrolamiento facial con liveness, hospedado por Kigo. Flujo "self-service"
por enlace web (no requiere el SDK del dispositivo).

- Base URL (dev): https://verify-api.kigo.dev
- Auth: header `x-api-key` (llave pública de proyecto tipo `kigo_pk_...`).
  Llave de proyecto FEPRO (dev): la fija el proyecto `d59a7163-063d-4a8f-a73b-f07929ecce71`.
  ⚠️ La llave dev compartida puede crear enrolamientos y DESCARGAR los rostros de todo
  el proyecto Fepro. Es sensible. Tratarla como secreto (mover a backend/.env, no commitear).
- El `project_id` del body se IGNORA (lo fija la llave). El `delivery_channel`
  (WHATSAPP/SMS/EMAIL) existe pero NO entrega nada (bug conocido: `recipient_ref` vacío).
  → El envío del `enrollment_url` lo hace NUESTRO sistema (usar `metadata.phone`).

Endpoints:
- POST /v1/enrollments
  body: { external_ref, webhook_url, redirect_url?, ttl_hours(1..72,def24), metadata{} libre }
  resp: { enrollment_id, enrollment_url (verify.kigo.dev/#token=...), status:PENDING,
          expires_at, webhook_secret (SOLO UNA VEZ), webhook_endpoint_id }
- GET  /v1/enrollments/{id}       → estado. Estados: PENDING, CONSENT_GIVEN,
        LIVENESS_STARTED, LIVENESS_COMPLETED, COMPLETED, LIVENESS_FAILED, QUALITY_FAILED
- GET  /v1/enrollments/{id}/photo → JPEG (image/jpeg). 404 hasta COMPLETED. = photo_url del webhook
- GET  /v1/enrollments?limit=20   → lista del proyecto (para sync hacia control de acceso)

Webhook: al COMPLETED, Kigo hace POST a nuestro `webhook_url` con evento
`EnrollmentCompleted` { external_ref, metadata verbatim, photo_url }.
- Firma en header `X-Kigo-Signature`, verificable con `webhook_secret`.
- Correlación por header `X-Kigo-Correlation-Id` = external_ref.
- Debe responder 2xx. Un 404 se reintenta ~15h y luego la entrega MUERE.
- Red de seguridad si se pierde entrega: hacer polling a GET /v1/enrollments/{id}.

Orden de uso: (1) crear enrolamiento con webhook_url → (2) mandar enrollment_url a la
persona (WhatsApp/SMS por nuestro sistema con metadata.phone) → (3) al completarse,
recibir webhook con photo_url y reconciliar por external_ref.

### 2. Notificaciones Kigo — Notifications API v2 (push/email/sms al ecosistema)
Servicio de orquestación de notificaciones del ecosistema Kigo mobile.
OpenAPI 3.1 completo guardado en /Users/carloc/Desktop/Carlo/kiwi/api-1.json.

- Gateway: https://api.kigo.pro/notifications  (servers url relativo "/notifications")
- Base de ejemplos: POST https://api.kigo.pro/notifications/v2/
- Auth: `x-api-key` (sk_live_...) para service-to-service (crear notif, catálogos);
        `x-token` (sesión de usuario) para operaciones user-scoped (list, mark-read, count).
- Apps soportadas: kigo, ebigo, best_parking, espacia.

Endpoint clave — enviar push:
POST /v2/  (ApiKeyAuth)
{
  "app":"kigo",
  "users":[{"legacyUserId":2085972}] | [{"userId":"<ULID>"}],
  "subTypeId":"<ObjectId de subtipo>",
  "title": (5..140), "message": (5..280),
  "action": { "type":"deeplink|url|image", "action":"kigo://home", "label":"Abrir" },
  "channels":[{"type":"push|email|sms","value":[...]}],
  "pushExtras": { "sound":"default", "data":{"screen":"home"},
                  "android":{"channelId":..,"clickAction":"com.parkimovil.app.ui.home.HomeActivity"} },
  "aditionalInfo": {} // validado contra el schema del subtype
}
subTypeIds de ejemplo vistos: 6840b3990a7a8a123715c1d2 (push simple),
6840b3970a7a8a123715c1c0 (push tipo imagen/comprobante).
Categorías de notificación: acceso, pago, comunidad, beneficio.
Otros: GET /v2/ (list), GET /v2/count, PUT /v2/mark-read, GET /v2/categorized[-sectioned],
catálogos admin de types/subtypes/sounds.
→ Uso para Welcome: notificar al ANFITRIÓN (colaborador Kigo) que tiene un visitante
  esperando autorización, con action deeplink a la mini-app/consola. Resuelve el Must
  "notificar al anfitrión" con el canal REAL de Kigo (no solo journey event en Supabase).

### 3. Mini-app / WebView bridge dentro de la app Kigo
- SDK npm: @kigo-dev/marketplace-sdk (https://www.npmjs.com/package/@kigo-dev/marketplace-sdk)
- Permite montar una mini-app (webview) dentro de la app Kigo de producción.
- En kigo_app el puente nativo existe: lib/app/presentation/bridge/kigo_bridge_delegate_impl.dart,
  lib/app/application/bridge/kigo_bridge_handler.dart, kigo_bridge_message/response (freezed),
  y KigoWebViewScreen. El marketplace (home/infestructure/market_place/movilomas) ya usa webviews.
→ Uso para Welcome: la consola de anfitrión (kigo-console) o una vista de "mis visitas"
  podría vivir como mini-app dentro de Kigo, autenticada con la sesión del colaborador.

### 4. Hardware físico: Telpo F10 (SDK local, NO el Gateway ESP32)
El kiosko que entregó la empresa es un TELPO F10 — terminal Android de control de acceso.
SDK COMPLETO en /Users/carloc/Desktop/Carlo/kiwi/kiwi_kigo/F10SDK (versión 20220623):
- sdk/PosUtil.jar + libposutil.so (armeabi, armeabi-v7a, arm64-v8a) — libs nativas JNI.
- doc/Telpo F10SDK Manual.docx, apk/F10Demosdk_20220623.apk (demo instalable).
- demo/F10SDK: proyecto Android (package com.common.f10sdk, minSdk14 target29) con Activities
  que demuestran cada capacidad del hardware vía `com.common.pos.api.util.PosUtil`:
  * RelayActivity: PosUtil.setRelayPower(1)=abrir / setRelayPower(0)=cerrar  ← ABRE LA PUERTA (relé)
  * WiegandActivity: getWg26Status(cardnum)/getWg34Status — salida Wiegand (a paneles de acceso);
    también registerBroadcastWiegandInput()/getWiegandInput() para LEER tarjetas Wiegand.
  * NFCActivity: lector NFC nativo (NfcAdapter) — lee UID de tarjetas.
  * LedActivity, RS485Activity, LanActivity: LED, RS485, LAN del dispositivo.
- IMPORTANTE: el F10 NO es el Kigo Gateway ESP32/BLE de kigo_app (KigoGatewayFacade). Es un
  dispositivo distinto. La app kiosko corre SOBRE el F10 (Android) y controla el relé/Wiegand/NFC
  DIRECTO por JNI (PosUtil), sin BLE. Para usarlo desde Flutter hay que crear un MethodChannel
  (plugin/platform channel) que exponga PosUtil.setRelayPower, Wiegand y NFC a Dart.

## Cómo estas piezas cierran el "loop" y elevan el proyecto a producción
Flujo Welcome integrado propuesto (a validar con el usuario, aún NO implementar):
1. Registro/consentimiento/evidencia en el kiosko F10 (kiwi_kigo actual).
2. Face enrollment: opción A (en sitio) capturar selfie local + validar con FaceValidator
   estilo kigo_app; opción B (Kigo Verify) crear enrollment y mandar enrollment_url por
   WhatsApp/SMS con metadata.phone, recibir photo_url por webhook.
3. Notificar al anfitrión vía Notifications API v2 (push con deeplink a autorizar).
4. Anfitrión autoriza (consola / mini-app webview en Kigo).
5. Al conceder: abrir puerta con PosUtil.setRelayPower(1) en el F10 (o emitir Wiegand al panel).
6. Bitácora: journey en Supabase + eventos de acceso.

## APIs base de kigo_app (referencia, ya en el código de producción)
- ApiClient / ApiClientKigoPro: headers x-token, x-api-key (FlavorConfig.kigoApiKey/kigoProApiKey),
  x-device-id, x-client=parkimovil, x-platform, x-country. baseUrl por FlavorConfig.
- Geosek (GeosekApiClient / GeosekGuestApiClient): accesos residencial/seguridad + invitados,
  auth `geosekAuth` + `md5Geosek`.
- KYC (kyc/v1/validation/*) + Jumio: verificación de identidad formal (KigoPro).
- KigoGatewayFacade (BLE ESP32): control de acceso alternativo (otro hardware, no el F10).
- FaceValidatorImpl (ML Kit) con reglas Hikvision: 1 rostro, ojos≥60px, cara 30-70% del frame,
  tilt ≤15° — reutilizable para validar la calidad de la selfie antes de enrolar.

## Seguridad / credenciales (tratar como secretos, mover a backend/.env, NO commitear)
- Kigo Verify api-key dev (kigo_pk_...): puede descargar todos los rostros del proyecto Fepro.
  Revocar si se filtra: DELETE /v1/api-keys/01a03a34-22e3-70a2-bb0c-e9bcb60611c5 (con llave admin).
- Notifications sk_live_...: llave service-to-service de producción (api.kigo.pro).
- Ambas aparecen en material compartido; en el código deben ir por variables de entorno.
