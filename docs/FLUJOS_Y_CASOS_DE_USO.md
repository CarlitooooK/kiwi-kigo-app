# Kigo Welcome — Guía de Flujos y Casos de Uso

> Guía completa para entender el proyecto de principio a fin. Pensada para que
> todo el equipo comprenda cada flujo, cómo funciona en la app, y cómo convive
> con el ecosistema Kigo. Complemento de `PROJECT_STATE.md` (estado técnico).
>
> Segmento: **Corporativo / Codekeepers** (oficina, visitante con cita, autoriza
> el colaborador). Última actualización: 2026-08-30.

---

## 0. Mapa mental del sistema

Tres piezas trabajando juntas:

- **kiwi_kigo**: la app que corre EN el kiosko F10 (Telpo). Todo lo que ve el visitante.
- **kigo-console**: web desplegada en GitHub Pages. Es a la vez la consola del anfitrión
  y el formulario de invitación. Se **embebe** dentro de la app Kigo como WebView.
- **kigo_app**: la app de producción de Kigo/Parkimovil. Solo la tocamos para embeber la
  webview (FAB "Welcome") e interceptar el QR `WELCOME:`.
- **Supabase**: base de datos y storage compartidos por kiosko y consola.
- **Kigo**: Notifications API (push real al anfitrión) y Kigo Verify (enrolamiento facial).

Flujo de datos: kiwi_kigo y kigo-console ↔ Supabase (directo). kiwi_kigo → Kigo Notifications
(push). kigo_app embebe kigo-console como WebView y le da la identidad del anfitrión por bridge.

---

## 1. Actores

| Actor | Quién es | Dónde interactúa |
|---|---|---|
| **Visitante** | Cliente/proveedor/entrevista/etc. con cita o walk-in | Kiosko F10 |
| **Anfitrión** | Colaborador de Kigo que recibe la visita | App Kigo (webview) / push |
| **Operador** | Quien administra el kiosko (recepción) | Kiosko (modo kiosko, reset) |

Host de demo: **legacyUserId 2085972** (Carlo Cabrera).

---

## 2. Estados de una visita (ciclo de vida)

- **PENDING**: recién creada.
- **PRE_AUTHORIZED**: invitación pre-aprobada (entra directo al llegar, dentro de su vigencia).
- **IN_PROGRESS**: walk-in en proceso de registro.
- **ACTIVE / CHECKED_IN**: dentro de las instalaciones.
- **COMPLETED**: hizo checkout (salió).
- **REJECTED**: el anfitrión la rechazó.
- **CANCELLED**: no completó el registro (ej. rechazó el aviso de privacidad).

`source`: `KIOSK` (walk-in) | `KIGO_APP` (invitación) | `MANUAL`.

Transiciones:
- Walk-in requiere host: PENDING → IN_PROGRESS → (HOST_NOTIFIED) → HOST_APPROVED → ACTIVE → COMPLETED, o → HOST_REJECTED → REJECTED.
- Walk-in auto-aprobado: → AUTO_AUTHORIZED → ACTIVE → COMPLETED.
- Rechaza aviso de privacidad: → CANCELLED.
- Invitación: PRE_AUTHORIZED → (escanea/rostro) → ACTIVE → COMPLETED.

---

## 3. CASO 1 — Visitante walk-in (llega sin cita)

Flujo Must del PRD. Registro completo en el kiosko.

1. **Welcome** → "Prefiero escribir" (o "Registrarme por voz").
2. **Purpose** (`/kiosk/purpose`): tipo (Cliente/Proveedor/Entrevista/Mantenimiento/Entrega/Visita).
3. **Identity** (`/kiosk/identity`): nombre y apellidos.
4. **Context** (`/kiosk/context`): **celular** (obligatorio → WhatsApp), detalle por tipo, anfitrión.
5. **Consent** (`/consent`): aviso de privacidad (opcional: opt-in "Recordar mi rostro").
   - Si **rechaza** → `CANCELLED` + evento `CANCELLED(CONSENT_DECLINED)` + reset.
6. **Identity capture** (`/identity`): foto de la ID (OCR ML Kit autollena).
7. **Photo** (`/photo`): selfie (liveness + comparación con la ID).
8. **Processing** (`/processing`): **Trust Score IA** = OCR(.20)+nombre(.30)+liveness(.20)+
   similitud facial(.30, MobileFaceNet). Sube evidencia. Si hubo consentimiento facial → enrola (Caso 6).
9. **Decisión**: auto-aprobado (`AUTO_AUTHORIZED`) / requiere host (push) / revisión manual.
10. **Resultado**: Aprobado → **Checked-in** (gafete + QR + **relé + LED + sonido**). Rechazado →
    **Access denied** (sonido de error).

Datos simulados (se muestran, no se piden): empresa "Kigo", área aleatoria. Email: no se usa.
Voz: mismo journey por TTS; el F10 no tiene micrófono, así que el STT cae al respaldo táctil.

---

## 4. CASO 2 — Visita programada por invitación

**A. Anfitrión crea la invitación (`#/invite`):** tipo, nombre, **celular**, anfitrión, detalle,
**vigencia** (30 min–1 semana) → crea visita `PRE_AUTHORIZED` (`KIGO_APP`, `scheduled_start/end`,
`host_kigo_user_id`) + **QR descargable** (`parkimovil.com/app?qr=WELCOME:<visitId>`) → comparte.

**B. Visitante llega (`/visit-lookup`, scan-first):** Welcome → "Tengo visita programada" →
**escanea el QR** (o busca por tel/correo). Validaciones:
- **Un solo uso**: si ya ACTIVE/COMPLETED/REJECTED/CANCELLED → bloquea.
- **Vigencia**: fuera de `scheduled_start..end` → "aún no válida" / "expiró el …".
Si válida → consent → **acceso directo** (pre-autorizada, no requiere host).

---

## 5. CASO 3 — Autorización del anfitrión (el loop Must)

1. Walk-in requiere host → **push real (Notifications API v2)** al anfitrión con deeplink
   `kigo://welcome/authorize?visit=<id>`.
2. Anfitrión abre → **consola-lite** (`#/host`) → visita en Pendientes con **detalle completo**
   (datos, Trust Score, fotos, journey).
3. **Aprobar** / **Rechazar** (+ enviar WhatsApp al aprobar). Cambia estado; el visitante ve el resultado.
4. **Sin respuesta**: queda en espera, consultable, no se pierde.

**Gate de acciones**: los botones solo aparecen si hay evento `HOST_NOTIFIED`. Invitaciones
pre-autorizadas no muestran "Autorizar" (entran directo).

---

## 6. CASO 4 — Consola-lite del anfitrión (`#/host`)

Webview del FAB "Welcome". Tabs: **Pendientes · Activas · Completadas · Canceladas · Invitaciones**.
- Activas → **Dar salida** (checkout) + WhatsApp.
- Invitaciones → historial con badge de vigencia ("Vence en X"/"Expirada").
- Cada tarjeta abre el detalle completo (Trust Score, evidencia, journey, acciones).
- Muestra visitas de hoy + invitaciones/programadas aún vigentes. Identidad por bridge.

---

## 7. CASO 5 — Checkout (cierre de visita)

- Vive en la **consola** (no en el kiosko: el F10 no debe quedar ocupado con un timer).
- Anfitrión da "Dar salida" en Activas → `COMPLETED`, `checked_out_at`, evento `CHECKED_OUT`.
- Si el visitante tiene rostro enrolado (no recurrente) → modal "¿Marcar como recurrente?" (Caso 6).

---

## 8. CASO 6 — Enrolamiento facial y "Ya vengo seguido"

Reconocimiento facial para agilizar frecuentes. **On-device ($0, offline)** con MobileFaceNet.

**Seguridad (clave del pitch):** el rostro es **conveniencia** (autollenar) o **fast-path para
recurrentes de confianza**, NUNCA credencial única para un extraño. Solo el ANFITRIÓN convierte
a alguien en recurrente, y solo tras una visita real autorizada + checkout.

- **Enrolar (kiosko):** opt-in "Recordar mi rostro" → al procesar selfie, guarda embedding (192-d)
  en `face_enrollments`. Evento `FACE_ENROLLED`. No-bloqueante.
- **Marcar recurrente (consola, tras checkout):** el anfitrión decide.
- **"Ya vengo seguido" (`/recurrent`):** toca el botón → una foto → reconoce (coseno ≥ 0.62):
  - Recurrente → abre puerta directo (relé+LED+sonido) + notifica anfitrión.
  - Enrolado no recurrente → autollena y sigue flujo normal.
  - No reconocido → registro normal.
- **Desenrolar (consola):** detalle → "Rostro registrado" → alternar recurrente / eliminar.

**Estado:** on-device funciona; **Kigo Verify desactivado** (`KIGO_VERIFY_ENABLED=false`) en pruebas.

**Plan futuro (definido, no implementado) — Kigo Verify con liveness:**
- Invitación crea enrollment de Kigo Verify + manda `enrollment_url` por WhatsApp.
- La persona hace **liveness** en su teléfono antes de llegar (rostro verificado, no una foto).
- Al COMPLETED, la foto verificada se vuelve el rostro de referencia (embedding generado en el kiosko).
- "Ya vengo seguido" seguirá **híbrido**: matching siempre local/offline contra el pool combinado
  (rostros locales + verificados por Kigo). Kigo aporta confianza (liveness); el kiosko, velocidad (offline).

---

## 9. Convivencia con el ecosistema Kigo

| Integración | Qué hace hoy | Estado |
|---|---|---|
| **Notifications API v2** | Push real al anfitrión + deeplink a autorizar | ✅ Activo |
| **WebView / bridge** | Consola y formulario embebidos en app Kigo; identidad del host por `bridgeAuthUserId()` | ✅ Activo |
| **QR universal-link** | Gafete/invitación usan `parkimovil.com/app?qr=WELCOME:<id>`; app Kigo intercepta `WELCOME:` | ✅ Activo |
| **Kigo Verify (face)** | Enrolamiento facial con liveness a distancia | ⏸️ Integrado, desactivado; plan en Caso 6 |
| **Hardware F10 (PosUtil)** | Relé (puerta), LED (feedback), lector QR (keyboard-wedge) | ✅ Activo |

**Hardware F10 (Telpo):** relé abre puerta; LED blanco (brillo 200) da feedback; el lector QR es
un Newland USB **keyboard-wedge** (teclea el QR, se captura por listener de teclado, no por el
lector serial del SDK); **no tiene micrófono físico** (TTS sí, STT no capta).

---

## 10. Reglas de negocio y decisiones clave

- **Email** eliminado por completo del journey.
- **Empresa** siempre "Kigo" (simulada); **área** aleatoria (simulada); **celular** real y obligatorio.
- **Invitación**: un solo uso + vigencia (30 min–1 semana).
- **Acciones del host** solo tras `HOST_NOTIFIED`; invitaciones entran directo.
- **Rostro** nunca es llave única para extraños (solo recurrentes de confianza).
- **Checkout** en la consola, no en el kiosko.
- **Reset entre sesiones** (el siguiente visitante no ve datos del anterior).
- **Modo kiosko** (lock task): no sale sin clave de operador.

---

## 11. Rubric FEPRO — dónde puntúa

| Criterio (peso) | Qué lo cubre |
|---|---|
| Núcleo (30%) | Registro + consentimiento + evidencia + solicitud + **push real al host** + autorizar/rechazar + resultado + **bitácora**. Caso sin respuesta cubierto. |
| UX / baja fricción (15%) | < 3 min, scan-first, autollenado por rostro, voz, feedback (LED/sonido). |
| IA con valor (15%) | Trust Score (MobileFaceNet), OCR (ML Kit), reconocimiento facial. On-device. |
| Código (15%) | Modular (Riverpod, servicios, repos), documentado, este set de docs. |
| Impacto/viabilidad (15%) | Integrado con el ecosistema REAL de Kigo (push, webview, QR, Verify, F10). |
| Presentación/demo (10%) | Arco: walk-in → invitación → rostro recurrente → checkout, con hardware real. |

---

## 12. Guion sugerido para la demo

1. **Walk-in**: registro (o voz) → ID (OCR) + selfie → Trust Score → **push real** → el anfitrión
   autoriza desde Kigo → **puerta abre** (relé+LED+sonido) → checkout en consola.
2. **Invitación**: anfitrión invita → QR con vigencia → visitante escanea → entra directo.
3. **Recurrente**: marcado recurrente por el anfitrión → toca "Ya vengo seguido" → el kiosko lo
   reconoce y abre la puerta, avisando al anfitrión.
4. **Trazabilidad**: se muestra el journey completo de cada visita en la consola.

Cierre: *"Núcleo cerrado, IA on-device a $0, e integrado con el ecosistema real de Kigo — push,
webview, QR universal, Verify y hardware F10."*

---

## 13. Referencias

- Estado técnico: `docs/PROJECT_STATE.md`
- Integraciones Kigo (endpoints/llaves): `docs/kigo-integration-context.md`
- Schema BD: `docs/supabase-schema.sql` · Rostros: `docs/face_enrollments.sql`
- Hand-off mini-app: `../kigo-console/MINIAPP_HANDOFF.md`
- PRD y rúbrica: `Kigo_FEPRO2026_PRD_Reto.pdf`, `Kigo_FEPRO2026_Plan_y_Evaluacion.pdf`
