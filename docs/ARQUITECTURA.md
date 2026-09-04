# Kigo Welcome — Arquitectura y Stack Tecnológico

> Arquitectura completa del proyecto Self Check-In AI (FEPRO 2026) y su ecosistema.
> Última actualización: 2026-09-03.

---

## 1. Componentes del ecosistema

```
┌─────────────────────────┐        ┌──────────────────────────┐
│  kiwi_kigo (Kiosko F10)  │        │  kigo-console (React)    │
│  Flutter + Riverpod      │        │  Consola-lite anfitrión  │
│  - Registro (voz/táctil) │        │  + Formulario invitación │
│  - Trust Score (TFLite)  │        │  (GitHub Pages)          │
│  - Captura INE + selfie  │        └────────────┬─────────────┘
│  - Entrada NFC / QR      │                     │ embebida en WebView
│  - Relé/LED/sonidos F10  │                     │
└────────────┬────────────┘                     │
             │                     ┌─────────────┴─────────────┐
             │                     │  kigo_app (Producción)    │
             │                     │  Flutter + Cubit + go_router│
             │                     │  - WebView de la mini-app │
             │                     │  - Interceptor de QR       │
             │                     │    (WELCOME:, SUPPORT:)    │
             │                     └─────────────┬─────────────┘
             │                                   │
             ▼                                   ▼
      ┌───────────────────────────────────────────────┐
      │          Supabase (Postgres + RLS)             │
      │  visits · visitors · visit_evidence            │
      │  trust_evaluations · access_decisions          │
      │  visitor_journey_events · face_enrollments     │
      │  + pg_cron (expire_stale_visits)               │
      └───────────────────────────────────────────────┘
                          │
                          ▼
             Kigo Notifications API v2 (push al anfitrión)
```

---

## 2. Proyectos

| Proyecto | Stack | Rol | Quién compila |
|---|---|---|---|
| `kiwi_kigo` | Flutter 3.44.5 / Dart 3.12.2, Riverpod, go_router | **Kiosko** en el Telpo F10 | El usuario |
| `kigo-console` | React 18 + Vite 5, react-router (HashRouter) | **Consola-lite** del anfitrión + invitaciones | El agente (deploy a Pages) |
| `kigo_app` | Flutter, Cubit + get_it + go_router (AGP 9) | App de producción; embebe la mini-app en WebView | El usuario |
| `app-kigo-bus` | Kotlin/Android | Referencia (POS en el mismo F10); origen de los sonidos | — |

---

## 3. Kiosko `kiwi_kigo` — arquitectura interna

### 3.1 Patrón
- **Feature-first**: `lib/features/<feature>/{presentation,application,domain,data}`.
- **Estado:** Riverpod (`Provider`, `StateNotifier`, `FutureProvider`).
- **Navegación:** go_router con transiciones custom (slide / fade-scale).
- **Core compartido:** `lib/core/{router,services,theme,config,data,supabase,utils}`.
- **Widgets compartidos:** `lib/shared/widgets/`.

### 3.2 Features principales
- `welcome` — pantalla de inicio, escucha NFC, entrada rápida de anfitrión.
- `visits` — búsqueda de visita programada, registro táctil (purpose/identity/context).
- `voice` — registro guiado por voz (STT/TTS on-device).
- `consent` — aviso de privacidad.
- `identity` — captura de INE + OCR (ML Kit).
- `evidence` — captura de selfie, procesamiento, resultado.
- `trust` — Trust Score (MobileFaceNet + fórmula), enrolamiento facial.
- `authorization` — evaluación de acceso, espera de aprobación, concedido/denegado.
- `support` — pantalla con QR `SUPPORT:<phone>` para llamar a soporte.

### 3.3 Puente nativo con el F10 (Kotlin — `MainActivity.kt`)
Comunicación Flutter ↔ hardware Telpo F10 vía **reflexión sobre `PosUtil.jar`**
(empaquetado en `android/app/libs/`, resuelto en runtime solo en el F10).

- **MethodChannel `kigo.welcome/f10_door`:**
  - `isAvailable` — detecta F10 por `ro.internal.model`.
  - `openDoor`/`closeDoor` — relé (`PosUtil.setRelayPower`).
  - `setLed` — LED blanco (`setLedLight`).
  - `setLedColor` — LED de color (`controlLedBright(type, progress)`; 0=rojo,1=verde,2=azul,3=blanco).
    ⚠️ NUNCA `setColorLed`/`setColorLedJNI` (reinicia el F10).
- **MethodChannel `kigo.welcome/kiosk`:** `start`/`stop` lock task (modo kiosko).
- **EventChannel `kigo.welcome/f10_nfc`:** stream de UID de tarjetas NFC.
  - **Camino primario:** `android.nfc.NfcAdapter` + foreground dispatch (este F10 sí
    enruta tags por el stack estándar de Android; confirmado en dispositivo).
  - **Camino secundario:** `com.common.face.api.NfcRd_Utils` (lector dedicado `nfcrd`)
    vía reflexión — usado si el `NfcAdapter` no estuviera presente.

### 3.4 Servicios Dart clave (`lib/core/services/`)
- `f10_door_service.dart` — puerta/LED (enum `F10LedColor`).
- `f10_nfc_service.dart` — stream de UIDs NFC.
- `f10_scanner_service.dart` — `ScanKeyboardListener` (lector QR keyboard-wedge).
- `sound_service.dart` — cues success/error (`audioplayers`).
- `kiosk_service.dart` — modo kiosko (lock task).

---

## 4. Consola `kigo-console` — arquitectura interna

- **Vite + React 18**, `HashRouter` (base `/kigo-kiwi-console/` en Pages).
- **Páginas:** `HostConsole` (`#/host`), `InviteForm` (`#/invite`),
  `HostAuthorize` (`#/authorize/:id`), `VisitDetail` (`#/visit/:id`).
- **Datos:** `src/lib/` — `visitRepository.js`, `hostActions.js`, `journeyRepository.js`,
  `supabase.js` (cliente autenticado + `supabaseAnon` sin sesión para inserts del formulario).
- **Bridge Kigo:** `kigoBridge.js` (`@kigo-dev/marketplace-sdk`) para auth del host y toasts
  cuando corre embebida en la app Kigo.
- **Features destacadas:** auto-aprobación por Trust ≥ 70 (toggle persistente en
  `localStorage`), gestión de enrolamiento recurrente, QR de invitación (`qrcode`),
  export PDF (`jspdf`).

---

## 5. Backend — Supabase

### 5.1 Tablas
`organizations`, `profiles`, `visitors`, `visits`, `visit_evidence`,
`trust_evaluations`, `access_decisions`, `visitor_journey_events`, `face_enrollments`.

### 5.2 Estados de visita
`PENDING → PRE_AUTHORIZED → IN_PROGRESS → CHECKED_IN/ACTIVE → COMPLETED`,
con ramas `REJECTED` y `CANCELLED`.

### 5.3 RLS (Row Level Security)
- Rol `anon`: **INSERT** permitido; **UPDATE** permitido en `visits`; **DELETE** bloqueado
  (salvo `face_enrollments`).
- La consola usa cliente autenticado; el formulario de invitación usa `supabaseAnon`.

### 5.4 Automatización server-side
- **`pg_cron` + `public.expire_stale_visits()`** (ver `docs/expire_stale_visits.sql`):
  cada minuto cancela visitas fantasma — `PENDING/IN_PROGRESS` > 10 min,
  `ACTIVE/CHECKED_IN` > 8 h → `CANCELLED` + evento de journey. `SECURITY DEFINER`.

---

## 6. Integraciones Kigo

- **Notifications API v2** (`api.kigo.pro/notifications/v2/`): push al anfitrión cuando un
  walk-in requiere autorización, y recordatorios (con cooldown de 30 s en el kiosko).
- **WebView / mini-app**: la consola-lite se embebe en `kigo_app`.
- **Interceptor de QR en `kigo_app`** (`scan_cubit.dart`): prefijos
  `WELCOME:<visitId>` (abre la visita) y `SUPPORT:<phone>` (llama a soporte, `tel:`).
- **Kigo Verify**: integrado pero **desactivado** por defecto (`KIGO_VERIFY_ENABLED=false`).

---

## 7. Stack tecnológico (resumen)

### Kiosko (`kiwi_kigo`)
| Área | Tecnología |
|---|---|
| Framework | Flutter 3.44.5 / Dart 3.12.2 |
| Estado | flutter_riverpod, riverpod_annotation |
| Navegación | go_router |
| Backend SDK | supabase_flutter |
| IA on-device | tflite_flutter (MobileFaceNet), google_mlkit_text_recognition, google_mlkit_face_detection, google_mlkit_barcode_scanning |
| Cámara/imagen | camera, image_picker, image |
| Voz | speech_to_text, flutter_tts |
| Audio | audioplayers |
| UI | google_fonts, flutter_svg, qr_flutter, cached_network_image |
| Utils | intl, uuid, equatable, freezed, json_serializable, flutter_dotenv, connectivity_plus |
| Nativo | Kotlin, PosUtil.jar (reflexión), NfcAdapter/NfcRd_Utils |

### Consola (`kigo-console`)
| Área | Tecnología |
|---|---|
| Build | Vite 5 |
| UI | React 18, react-router-dom (HashRouter) |
| Backend SDK | @supabase/supabase-js |
| Kigo | @kigo-dev/marketplace-sdk |
| QR / PDF | qrcode, jspdf, jspdf-autotable |
| Deploy | gh-pages (GitHub Pages) |

### Backend
| Área | Tecnología |
|---|---|
| DB | Supabase (PostgreSQL) |
| Seguridad | Row Level Security |
| Automatización | pg_cron |
| Notificaciones | Kigo Notifications API v2 |

---

## 8. Hardware — Telpo F10

- Android 9 (API 28), arm64, Snapdragon 625, DPI 240.
- Relé de puerta, LED de color, lector QR keyboard-wedge (Newland NLS-CEM300-DK USB),
  NFC (NfcAdapter estándar), micrófono USB C-Media, cámara frontal.
- SDK: `PosUtil.jar` + `libposutil.so` (todas las ABIs) en `android/app/{libs,jniLibs}`.
- Notas operativas: NFC y volumen de micrófono se **resetean al reiniciar** el F10
  (habilitar NFC: `adb shell svc nfc enable`; mic: `tinymix -D 0 'Mic Capture Volume' 16`).
