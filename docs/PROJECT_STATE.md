# Kigo Welcome — Estado del Proyecto (FEPRO 2026)

> Documento maestro de contexto. Última actualización: 2026-09-03.
> Kiosko Self Check-In AI para FEPRO 2026, segmento Corporativo/Codekeepers.
> Integrado con el ecosistema Kigo. Demo objetivo: 3–4 sep.
>
> **Docs relacionados:** [`IA_DEL_PROYECTO.md`](IA_DEL_PROYECTO.md) ·
> [`ARQUITECTURA.md`](ARQUITECTURA.md) · [`FLUJOS_Y_CASOS_DE_USO.md`](FLUJOS_Y_CASOS_DE_USO.md)
> · [`../README.md`](../README.md)

---

## 1. Visión general

MVP convertido en proyecto integrado con el ecosistema real de Kigo. Tres pilares de IA
**on-device ($0, sin costo extra)**:
1. **Trust Score real** — embeddings faciales MobileFaceNet (TFLite).
2. **Registro por voz** on-device (STT + TTS). *Nota: el F10 no tiene micrófono físico,
   ver §7.*
3. **Apertura física** del kiosko F10 (relé) + feedback (LED + sonidos).

Más un **flujo de invitación** (pre-registro web → QR → escaneo en F10) y una
**consola-lite del anfitrión** embebida en la app Kigo.

---

## 2. Proyectos (monorepo en `/Users/carloc/Desktop/Carlo/kiwi/`)

| Proyecto | Tipo | Rol |
|---|---|---|
| `kiwi_kigo` | Flutter (Riverpod) | **Kiosko** Self Check-In en el F10 |
| `kigo-console` | React/Vite | **Mini-app/consola** del anfitrión + formulario de invitación |
| `kigo_app` | Flutter (Cubit+get_it+go_router, AGP 9) | App de producción Kigo/Parkimovil (aquí se embebe la webview) |
| `app-kigo-bus` | Kotlin/Android | Proyecto de referencia (POS de cobro en el mismo F10). De ahí salieron los **sonidos** success/error. |

- Flutter 3.44.5 / Dart 3.12.2.
- **El usuario compila `kigo_app` y `kiwi_kigo` él mismo.** El agente compila la consola y hace deploy.

---

## 3. Infraestructura y credenciales

- **Supabase:** `https://xmsbwlhkwznhpfjamhen.supabase.co`
  - anon key: `sb_publishable_TM1EdSimgNyzjtXC2hBOLA_aHv9SIAT`
  - ORG: `a0000000-0000-0000-0000-000000000001`
  - RLS: INSERT permitido a rol `anon` (NO a `authenticated`). Por eso la consola usa un
    cliente anónimo dedicado (`supabaseAnon`, sin sesión) para los inserts del formulario.
- **F10:** `192.168.1.72:5555` (ADB wireless). Android 9 / API28 / arm64 / Snapdragon625 / DPI 240.
  - `ro.internal.model = F10`. Si ADB queda unauthorized: `adb disconnect && adb connect 192.168.1.72:5555`.
- **Teléfono del usuario** (moto g86, Android 16): logueado como legacyUserId **2085972** (Carlo Cabrera).
- **Mac IP:** `192.168.1.71` (ya NO se usa preview local; todo por GitHub Pages).
- **Notifications API (Kigo):** POST `api.kigo.pro/notifications/v2/`, subtype `6840b3990a7a8a123715c1d2`,
  `testHostLegacyUserId=2085972`. Llave `sk_live` en `.env`.

### Despliegue de la consola (GitHub Pages)
- Repo: `github.com/CarlitooooK/kigo-kiwi-console` (rama `gh-pages`).
- **URL pública:** `https://carlitooook.github.io/kigo-kiwi-console/`
  (OJO: usuario con **4 letras "o"** — `carlitooook`).
- Deploy: `npm run deploy` (build + `gh-pages -d dist`). Requirió activar Pages una vez
  (Settings → Pages → gh-pages / root).
- Base path `/kigo-kiwi-console/`, **HashRouter** → las rutas llevan `#/`.

### Rutas de la consola (todas con `#/`)
- `#/host` — consola-lite del anfitrión (la del FAB de app Kigo).
- `#/invite` — formulario de invitación (pre-registro + QR).
- `#/authorize/:id` — detalle/autorización de una visita.
- `#/visit/:id` — vista solo-lectura del visitante (abierta desde el QR del gafete).

---

## 4. Hardware F10 (hallazgos verificados)

Binarios: `PosUtil.jar` en `android/app/libs/`, `libposutil.so` en jniLibs.
Clase real: `com.common.pos.api.util.PosUtil` (invocada por **reflexión** en `MainActivity.kt`
vía MethodChannel `kigo.welcome/f10_door`). En dispositivos sin PosUtil degrada a no-op.

| Feature | Método SDK | Estado | Notas |
|---|---|---|---|
| **Relé puerta** | `setRelayPower(1/0)` | ✅ Funciona (clic audible) | Abre 5s y auto-cierra |
| **LED** | `setLedLight(x)` → `controlLedBright(3,x)` | ✅ Funciona | Blanco. **Brillo 200** (calibrado; 255 fuerte, 1 tenue). Se enciende al autorizar acceso. |
| **Lector QR** | (NO `barcode_scaner`) | ✅ Funciona | Es **keyboard-wedge**: `Newland NLS-CEM300-DK USB POS KBW`. Teclea el QR + Enter. Se captura con `ScanKeyboardListener` (Focus). El `barcode_scaner` serial devolvió `null`. |
| **Micrófono** | — | ❌ NO existe físico | Aunque `pm list features` reporta micrófono (heredado del SoC). STT no puede capturar. |
| **TTS** | flutter_tts + Google TTS | ✅ Funciona | Google TTS instalado por Play Store; default por ADB. |
| **STT** | speech_to_text | ⚠️ Init OK pero sin mic | GoogleTTSRecognitionService seteado como recognizer; locale es-US. No captura por falta de mic. |

Smoke tests: `flutter test integration_test/f10_smoke_test.dart -d 192.168.1.72:5555`
(relé, tflite, STT init, TTS canSpeak, LED, sonido). **`flutter test` DESINSTALA la app al
terminar** → reinstalar: `adb -s 192.168.1.72:5555 install -r build/app/outputs/flutter-apk/app-debug.apk`.

---

## 5. Flujos del kiosko (`kiwi_kigo`)

### Pantalla de bienvenida (`welcome_screen`)
Tres CTAs: "Tengo visita programada" (`/visit-lookup`), registro por voz (`/kiosk/voice`),
registro táctil (`/kiosk/purpose`). Modo kiosko (lock task) al entrar a reposo.

### A. Walk-in nuevo (registro)
`/kiosk/purpose` → `/kiosk/identity` (nombre) → `/kiosk/context` (celular + detalle por tipo + anfitrión)
→ `/consent` → `/identity` (captura ID+selfie) → `/processing` (Trust Score IA) → autorización.

- **Journey unificado** (voz y táctil): tipo → nombre → **celular (crítico)** → anfitrión → detalle (según tipo).
- **Quitados de captura:** empresa, área/piso. **Email eliminado por completo** (ni pedido, ni mostrado).
- **Simulados al final** (solo para mostrar en gafete/WhatsApp/webview): **empresa = "Kigo"** (fija),
  **área = aleatoria** de una lista (`lib/core/utils/simulated_data.dart`). Celular es **real**.
- `VoiceParser.phone()` convierte dígitos hablados/escritos a 10 dígitos.
- Registro por voz: si dices "incorrecto" al confirmar → va al formulario **prellenado** (`/kiosk/identity`
  con `toFlowData()`), no reinicia. `VoiceParser.yesNo()` corregido (negativos primero, palabra completa;
  "incorrecto" ya no se lee como "correcto").

### B. Visita programada / invitación (`/visit-lookup`)
Rediseñada **scan-first**:
- **Principal:** panel grande de escáner QR que pulsa ("Acerca tu QR al lector"). `ScanKeyboardListener`
  siempre activo. Acepta `https://parkimovil.com/app?qr=WELCOME:<id>`, `WELCOME:<id>`, o UUID pelón.
- **Secundaria (colapsada):** "No tengo el QR, buscar con mis datos" → teléfono/correo.
- "No tengo visita programada" → `/kiosk/purpose` (flujo nuevo; **ya NO** va a `/register` legacy).
- **Guardas de un solo uso + vigencia** (`_usageBlockMessage`): bloquea si estado ACTIVE/CHECKED_IN/
  IN_PROGRESS ("ya está activa"), COMPLETED ("ya completada"), REJECTED, CANCELLED; y si está fuera de
  la ventana `scheduled_start`/`scheduled_end` ("aún no válida" / "expiró el ...").

### Cierre del kiosko (`checked_in_screen`)
Pantalla de éxito verde: gafete (nombre + **Empresa: Kigo** + **Área** simulada + Entrada) + **QR**
(`https://parkimovil.com/app?qr=WELCOME:<visitId>`) + botón "Listo" (reset manual, sin timeout).
Al conceder acceso: abre relé + **enciende LED (200) 5s** + **suena success.wav**. Reset invalida providers.

### Rechazo del aviso de privacidad (`consent_screen`)
"Cancelar registro" → marca la visita como **`CANCELLED`** + evento `CANCELLED` (reason `CONSENT_DECLINED`)
y resetea el kiosko. Ya no queda "fantasma" en PENDING.

### Acceso denegado (`access_denied_screen`)
Reproduce **error.wav** al mostrarse.

---

## 6. Consola-lite del anfitrión (`kigo-console`, `#/host`)

Es la webview que abre el **FAB "Welcome"** de app Kigo (`hostConsole: true` →
`welcome_miniapp_demo_screen.dart` carga `https://carlitooook.github.io/kigo-kiwi-console/#/host`).

- Identidad del anfitrión vía `bridgeAuthUserId()` (legacyUserId). En navegador sin bridge → muestra todo.
- **Tabs:** Pendientes · Activas · Completadas · **Canceladas** (CANCELLED+REJECTED) · **Invitaciones**.
  Tabs con scroll horizontal.
- Cada tarjeta abre el **detalle completo** (`#/authorize/:id?from=host`): datos, **Trust Score** (TrustRing),
  **fotos/evidencia** (visor fullscreen), **journey** (JourneyTimeline con etiquetas legibles, incl.
  "Rechazó el aviso de privacidad" para CANCELLED/CONSENT_DECLINED), y acciones.
- **Gate de acciones** (autorizar/rechazar/WhatsApp), tanto en card como en detalle:
  - Solo si la visita tiene evento **`HOST_NOTIFIED`** (walk-in que llegó al paso de autorización).
  - **Invitaciones pre-autorizadas NO** muestran "Autorizar" (entran directo) → muestran
    "Invitación · acceso directo".
- **Activas** → Dar salida (checkout) + WhatsApp. **Completadas** → solo lectura.
- Botón **"Invitar"** en el header → `#/invite`.
- **Filtro de datos:** trae creadas HOY **+** pre-autorizadas aún vigentes (`scheduled_end >= now`)
  aunque sean de otro día. Invitaciones: historial completo (200) con badge de vigencia
  ("Vence en X" / "Expirada").
- Acciones compartidas en `src/lib/hostActions.js` (approveVisit, rejectVisit, checkOutVisit, whatsappLink).

---

## 7. Formulario de invitación (`#/invite`)

- Campos: tipo, nombre, apellidos, **celular** (validado 10 díg), anfitrión, detalle por tipo,
  **Vigencia del acceso** (30 min / 1h / 3h / 8h / 1 día / 3 días / 1 semana; default 1 día).
- Crea visitante (company=Kigo, phone real, **sin email**) + visita **`PRE_AUTHORIZED`**
  (`source: KIGO_APP`, `is_preauthorized: true`, area simulada, `scheduled_start`/`scheduled_end`) +
  evento `VISIT_CREATED` con `host_kigo_user_id` (del bridge; null si navegador sin sesión).
- Genera **QR descargable** (lib `qrcode`) con `https://parkimovil.com/app?qr=WELCOME:<visitId>`.
  Descarga: intenta `<a download>`, fallback abrir en pestaña + "mantén presionada la imagen"
  (para WebView Android).
- Usa `supabaseAnon` (evita el bloqueo RLS cuando hay sesión de anfitrión).

**Vigencia:** cuenta **desde el momento de crear** la invitación. (Pendiente opcional: inicio programable.)

---

## 8. Integración QR ↔ app Kigo

- QR del gafete = `https://parkimovil.com/app?qr=WELCOME:<visitId>` (prefijo real de Kigo).
- En `kigo_app`, `ScanCubit.scanQrCode` intercepta el marcador `WELCOME:` → abre la webview de
  solo-lectura `#/visit/:id` (no va al backend de scan).
- El FAB del home (`home_screen.dart`) abre la consola-lite con `extra: {'hostConsole': true}`.
- `network_security_config.xml` (cleartext LAN) ya no es necesario porque la URL es HTTPS (github.io).

---

## 9. Estado por pilar / feature

| Feature | Estado |
|---|---|
| Relé F10 | ✅ Verificado en HW |
| Trust Score IA (MobileFaceNet TFLite) | ✅ Integrado en evidence_processing |
| Voz on-device (STT/TTS) | ⚠️ TTS OK; STT bloqueado por falta de micrófono físico en el F10 |
| Notificación push al anfitrión | ✅ HTTP 200 real a 2085972 |
| Cierre kiosko (gafete+QR+Listo) | ✅ |
| Mini-app anfitrión (autorizar/rechazar/checkout/WhatsApp) | ✅ Verificado en vivo |
| QR gafete → vista solo-lectura en Kigo | ✅ Verificado |
| WhatsApp al visitante | ✅ Verificado (wa.me) |
| LED feedback (200) | ✅ Verificado en HW |
| Sonidos success/error | ✅ Verificado |
| Escaneo QR (keyboard-wedge) | ✅ Verificado end-to-end |
| Formulario invitación + QR descargable | ✅ Desplegado |
| Consola-lite (tabs, detalle, gate de acciones) | ✅ Desplegado |
| Historial de invitaciones | ✅ |
| Filtro cancelada/rechazada | ✅ |
| Vigencia de invitaciones (30min–1sem) | ✅ Desplegado |
| Un solo uso (QR quemado) | ✅ |
| Face enrollment on-device (MobileFaceNet) | ✅ Enrola al capturar selfie (opt-in) |
| Kigo Verify (enrollment remoto) | ⏸️ Integrado pero DESACTIVADO (`KIGO_VERIFY_ENABLED=false`) para no ensuciar pruebas |
| "Ya vengo seguido" (reconocimiento facial) | ✅ Recurrente entra directo / enrolado autollena / no reconocido flujo normal |
| Marcar recurrente (consola, tras checkout) | ✅ Desplegado |
| Desenrolar rostro (consola, en detalle) | ✅ Desplegado |

---

## 8b. Face Enrollment (Idea 1) — detalle

**Seguridad de raíz:** el rostro **solo abre la puerta** para quien el ANFITRIÓN marcó como
recurrente tras una visita real autorizada + checkout. El enrolamiento auto-servicio (kiosko)
solo habilita **autollenado** (conveniencia), nunca acceso para un extraño.

- **Enrolar (kiosko):** opt-in "Recordar mi rostro" en `consent_screen` → `_face_consent` viaja por
  el flujo → en `evidence_processing_screen._enrollFace()`: embedding on-device (MobileFaceNet) +
  (si Verify activo) enrollment en Kigo Verify + guarda en `face_enrollments` + evento `FACE_ENROLLED`.
  No-bloqueante.
- **Marcar recurrente (consola):** tras checkout, si el visitante tiene rostro enrolado, modal
  "¿Marcar como recurrente?" → `markRecurrent`. Solo el anfitrión (autoridad de confianza).
- **"Ya vengo seguido" (`/recurrent`, kiosko):** CTA en welcome → captura UNA foto (no cámara en
  vivo) → `FaceRecognitionService.recognize()` (coseno ≥ 0.62, 1:N contra enrolados):
  - Recurrente → abre puerta directo (relé+LED+sonido) + notifica anfitrión.
  - Enrolado no-recurrente → autollena (`/kiosk/purpose` con datos) y sigue flujo normal.
  - No reconocido → mensaje → flujo normal. (No bloqueante.)
- **Desenrolar (consola):** en el detalle (`#/authorize/:id`), tarjeta "Rostro registrado" →
  alternar recurrente / eliminar rostro (`unenrollFace`).
- **Archivos:** `lib/core/services/kigo_verify_service.dart`, `lib/features/trust/data/{face_enrollment_repository,face_recognition_service}.dart`,
  `lib/features/welcome/presentation/recurrent_entry_screen.dart`, `docs/face_enrollments.sql`,
  `kigo-console/src/lib/hostActions.js` (hasFaceEnrollment/markRecurrent/unenrollFace).
- **Tabla `face_enrollments`:** visitor_id, organization_id, embedding (jsonb, 192-d L2-norm),
  photo_path, is_recurrent, kigo_enrollment_id, kigo_status. RLS anon. Nuevos event_type:
  FACE_ENROLLED, FACE_MATCH, RECURRENT_ENTERED, CANCELLED.
- **Kigo Verify:** llave `kigo_pk_...` en `.env` (probada en vivo). Base `verify-api.kigo.dev`.
  **DESACTIVADO** por `KIGO_VERIFY_ENABLED=false` durante pruebas.
- **PLAN PENDIENTE (Flujo A, no implementado):** invitación → Kigo Verify con liveness a
  distancia → al COMPLETED, guardar la photo verificada como rostro de referencia (embedding
  generado en el kiosko) en `face_enrollments`. "Ya vengo seguido" es HÍBRIDO: matching siempre
  local/offline contra el pool combinado (locales + verificados por Kigo).

---

## 10. Datos de prueba (Supabase)

- Fotos reales reusables: visit `6abf4efd-8e13-43d5-b8c3-c219a6eca987` (SELFIE en `visitor-photos`,
  ID_FRONT en `visit-evidence`).
- Conteos aprox. (2026-08-29): ~57 visits, ~59 visitors, ~431 journey events. 1 profile, 1 organization.
- Limpieza de BD/buckets: **pendiente/pospuesta** (el usuario decidirá A=total o B=conservando `6abf4efd`).
  La anon key puede no tener DELETE por RLS en algunas tablas → quizá requiera service_role/dashboard.

---

## 11. Modelo de datos relevante (schema Supabase)

- `visits.source` CHECK: `KIGO_APP` | `KIOSK` | `MANUAL` (invitaciones usan **KIGO_APP**).
- `visits.status` CHECK: PENDING, PRE_AUTHORIZED, IN_PROGRESS, CHECKED_IN, ACTIVE, COMPLETED, REJECTED, CANCELLED.
- `visits`: `scheduled_start`, `scheduled_end`, `is_preauthorized`, `area`, `purpose`, `checked_in_at`, `checked_out_at`.
- `visitors`: `first_name`, `last_name`, `company`, `phone`, `email`(no usado), `visitor_type`.
- `visitor_journey_events`: `event_type`, `payload` (incl. `host_kigo_user_id`), `created_at`.
  Eventos: VISIT_CREATED, VISITOR_ARRIVED, IDENTITY_VALIDATED, EVIDENCE_PROCESSED, TRUST_EVALUATED,
  ACCESS_REQUESTED, HOST_NOTIFIED, HOST_APPROVED, HOST_REJECTED, AUTO_AUTHORIZED, CHECKED_IN,
  CHECKED_OUT, ESCALATED, **CANCELLED**.

---

## 12. Pendientes / pospuestos

- Limpieza de BD + buckets (decidir alcance).
- Inicio de vigencia programable (hoy la vigencia corre desde la creación).
- Middleware teléfono→legacyUserId (pedido por tech lead FEPRO).
- Columna `host_kigo_user_id` indexada en `visits` (hoy vive en el payload del evento).
- WhatsApp automático real (requiere WhatsApp Business API; hoy es wa.me con un toque).
- Micrófono externo USB para habilitar STT real en el F10 (opcional, depende de accesorio).
- Eliminar por completo la pantalla legacy `/register` + `VisitorRegistrationScreen` (ya sin uso en UI).

---

## 13. Comandos útiles

```bash
# Kiosko: build + instalar en F10
cd /Users/carloc/Desktop/Carlo/kiwi/kiwi_kigo
flutter build apk --debug && adb -s 192.168.1.72:5555 install -r build/app/outputs/flutter-apk/app-debug.apk

# Consola: build + deploy a GitHub Pages
cd /Users/carloc/Desktop/Carlo/kiwi/kigo-console
npm run deploy

# Smoke tests HW en F10 (¡reinstalar app después!)
flutter test integration_test/f10_smoke_test.dart -d 192.168.1.72:5555

# Reconectar F10
adb disconnect && adb connect 192.168.1.72:5555
```
