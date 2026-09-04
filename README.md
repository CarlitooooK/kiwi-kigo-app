# Kigo Welcome Intelligence

Kiosko **Self Check-In AI** para el ecosistema Kigo — recepción inteligente de
visitantes con Trust Score facial on-device, registro por voz, invitaciones,
entrada rápida por NFC y consola-lite para el anfitrión.

**Segmento:** Corporativo / Codekeepers · **Reto:** FEPRO 2026
**Stack:** Flutter (kiosko) + React/Vite (consola) + Supabase

---

## Concepto

Kigo Welcome convierte la llegada de un visitante en un journey inteligente,
contextual y trazable:

```
Invitación / Walk-in → Welcome → (Voz o Táctil) → Aviso de privacidad
→ Identidad (OCR) → Selfie → Trust Score → Autorización del anfitrión → Acceso
```

Rutas alternas: **visita programada** (QR o teléfono), **entrada rápida por NFC**
(anfitrión), **visitante frecuente** (reconocimiento facial).

---

## Inteligencia Artificial (on-device, $0)

- **Reconocimiento facial** — MobileFaceNet (TFLite), embeddings 192-d, coseno.
- **OCR de identificación** — Google ML Kit Text Recognition.
- **Detección facial** — Google ML Kit Face Detection.

El **Trust Score** agregado es una fórmula ponderada (no IA), y el **liveness** de
un frame es heurística. Ver [`docs/IA_DEL_PROYECTO.md`](docs/IA_DEL_PROYECTO.md)
para el detalle honesto de qué es IA y qué no.

---

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/IA_DEL_PROYECTO.md`](docs/IA_DEL_PROYECTO.md) | IA real vs heurísticas, modelos y costos |
| [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) | Arquitectura completa y stack tecnológico |
| [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) | Estado del proyecto y contexto |
| [`docs/FLUJOS_Y_CASOS_DE_USO.md`](docs/FLUJOS_Y_CASOS_DE_USO.md) | Flujos y casos de uso |
| [`docs/supabase-schema.sql`](docs/supabase-schema.sql) | Esquema de la base de datos |
| [`docs/expire_stale_visits.sql`](docs/expire_stale_visits.sql) | Limpieza automática (pg_cron) |

---

## Repositorios

- **Kiosko (este repo):** `github.com/CarlitooooK/kiwi-kigo-app`
- **Consola/mini-app:** `github.com/CarlitooooK/kigo-kiwi-console`
  → publicada en `https://carlitooook.github.io/kigo-kiwi-console/`

---

## Requisitos

- **Flutter** 3.44.5 / **Dart** 3.12.2 (kiosko)
- **Node.js** 18+ y npm (consola)
- Cuenta **Supabase** con el esquema aplicado (`docs/supabase-schema.sql`,
  `docs/face_enrollments.sql`, `docs/expire_stale_visits.sql`)
- Para el kiosko real: dispositivo **Telpo F10** (o cualquier Android para modo degradado)

---

## Instalación — Kiosko (`kiwi_kigo`)

```bash
# 1. Dependencias
flutter pub get

# 2. Variables de entorno: crea el archivo .env en la raíz del proyecto
cp .env.example .env   # si existe; si no, crea .env con las claves de abajo

# 3. (una vez) genera código de Riverpod/Freezed si hiciste cambios
dart run build_runner build --delete-conflicting-outputs

# 4. Ejecutar
flutter run                       # en el dispositivo conectado
# o compilar el APK
flutter build apk --debug
```

### `.env` requerido (kiosko)

```env
SUPABASE_URL=https://<tu-proyecto>.supabase.co
SUPABASE_ANON_KEY=<tu-anon-key>

# Kigo Notifications API v2 (push al anfitrión)
KIGO_NOTIFICATIONS_BASE_URL=https://api.kigo.pro/notifications
KIGO_NOTIFICATIONS_API_KEY=<sk_live_...>
KIGO_NOTIFICATIONS_SUBTYPE_ID=<subtype-id>
KIGO_TEST_HOST_LEGACY_USER_ID=<legacyUserId del host de prueba>

# Kigo Verify (opcional; desactivado por defecto)
KIGO_VERIFY_ENABLED=false
KIGO_VERIFY_BASE_URL=<url>
KIGO_VERIFY_API_KEY=<kigo_pk_...>
```

> El `.env` se empaqueta en el APK al compilar — los cambios aplican en el próximo build.

### Notas del Telpo F10

```bash
# Conexión ADB inalámbrica
adb connect 192.168.1.72:5555

# NFC (se apaga al reiniciar el dispositivo)
adb -s 192.168.1.72:5555 shell svc nfc enable

# Micrófono USB (se resetea al reiniciar)
adb -s 192.168.1.72:5555 shell "tinymix -D 0 'Mic Capture Volume' 16"

# Instalar APK
adb -s 192.168.1.72:5555 install -r build/app/outputs/flutter-apk/app-debug.apk
```

El SDK del F10 (`PosUtil.jar` + `libposutil.so`) ya está incluido en
`android/app/{libs,jniLibs}` y se resuelve por reflexión solo en el hardware F10.
En cualquier otro Android la app corre en modo degradado (sin relé/LED/NFC físicos).

---

## Instalación — Consola (`kigo-console`)

```bash
cd ../kigo-console          # repo hermano

# 1. Dependencias
npm install

# 2. Variables de entorno: crea .env.local
#    VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY

# 3. Desarrollo local
npm run dev                 # http://localhost:5173

# 4. Build de producción
npm run build

# 5. Deploy a GitHub Pages
npm run deploy              # build + gh-pages -d dist
```

### Rutas de la consola (HashRouter)

- `#/host` — consola-lite del anfitrión (visitas de hoy, aprobar, auto-aprobación por Trust ≥ 70)
- `#/invite` — formulario de invitación (genera visita PRE_AUTHORIZED + QR)
- `#/authorize/:id` — autorización de una visita
- `#/visit/:id` — detalle de la visita

---

## Base de datos (Supabase)

Aplica en el **SQL Editor** de Supabase, en orden:

1. `docs/supabase-schema.sql` — tablas, estados y RLS.
2. `docs/face_enrollments.sql` — enrolamiento facial de recurrentes.
3. `docs/expire_stale_visits.sql` — limpieza automática de visitas fantasma (pg_cron).

---

## Estructura del kiosko

```
lib/
├── app.dart                 # MaterialApp.router
├── main.dart
├── core/                    # router, services (F10, NFC, sonido), theme, config, supabase
├── features/                # welcome, visits, voice, consent, identity, evidence,
│                            # trust, authorization, support (feature-first)
└── shared/widgets/          # widgets reutilizables (stepper, botón soporte, etc.)
android/app/
├── libs/PosUtil.jar         # SDK Telpo F10 (reflexión)
├── jniLibs/**/libposutil.so # nativo Telpo (todas las ABIs)
└── src/main/kotlin/.../MainActivity.kt  # puente: relé, LED, NFC, kiosko
assets/
├── models/mobilefacenet.tflite   # modelo de IA facial
├── sounds/                       # cues success/error
└── brand/                        # logo
```

---

## Licencia

Proyecto de demostración para FEPRO 2026 (Kigo / Parkimovil).
