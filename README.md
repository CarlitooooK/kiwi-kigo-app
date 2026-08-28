# Kigo Welcome Intelligence — MVP

Una capa inteligente de recepción y gestión de visitantes para el ecosistema Kigo.

**Segmento:** Corporativo / Oficina  
**Stack:** Flutter + Supabase  
**Propuesta:** FEPRO 2026

## Concepto

Kigo Welcome convierte la llegada de un visitante en un Visitor Journey inteligente, contextual, automatizado y trazable.

```
Invitación → Visita programada → Welcome → Check-in → Identidad
→ Evidencia → Trust Layer → Access Policy → Autorización → Acceso
→ Visita activa → Check-out → Visitor Journey
```

## Arquitectura

```
┌─────────────────────────────────────────────┐
│              FLUTTER APP                     │
├─────────────────────────────────────────────┤
│  KIOSK (Visitante)  │  CONSOLE (Admin/Host) │
│         ↓                      ↓            │
│      Riverpod State Management              │
│         ↓                      ↓            │
│      Repositories + Use Cases               │
│                    ↓                        │
└────────────────────┼────────────────────────┘
                     │
              ┌──────▼──────┐
              │  SUPABASE   │
              ├─────────────┤
              │ Auth        │
              │ PostgreSQL  │
              │ Storage     │
              │ Realtime    │
              └─────────────┘
```

## Quick Start

### 1. Prerrequisitos
- Flutter 3.12+
- Proyecto Supabase configurado

### 2. Configurar
```bash
cp .env.example .env
# Editar .env con tus credenciales de Supabase
```

### 3. Instalar dependencias
```bash
flutter pub get
```

### 4. Ejecutar
```bash
flutter run -d chrome     # Web
flutter run -d macos      # macOS
flutter run               # iOS/Android
```

### 5. Console admin
Acceder a `/console/login` con un usuario creado en Supabase Auth.

## Estructura

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/          → Environment
│   ├── constants/       → App constants, enums
│   ├── data/            → Repositories (visit, org, journey)
│   ├── network/         → Connectivity
│   ├── router/          → GoRouter + auth guard
│   ├── services/        → Kigo integration interfaces
│   ├── supabase/        → Client + auth providers
│   └── theme/           → Material 3 theme
├── features/
│   ├── welcome/         → Kiosk entry point
│   ├── visits/          → Lookup + Registration
│   ├── consent/         → Privacy notice
│   ├── identity/        → ID document capture
│   ├── evidence/        → Photo + processing
│   ├── trust/           → TrustScoreService + Mock
│   ├── authorization/   → AccessPolicy + waiting + decisions
│   ├── journey/         → Active visit + checkout + completed
│   └── console/         → Login + Dashboard + Visits + Detail
└── shared/widgets/      → Reusable components
```

## Flujo del Visitante (Kiosk)

1. **Welcome** → ¿Tiene visita? / Registrarse
2. **Lookup** → Busca por email/teléfono
3. **Visit Found** → Muestra datos pre-registrados
4. **Registration** → Formulario para walk-ins
5. **Consent** → Aviso de privacidad
6. **Identity** → Captura de ID (cámara)
7. **Photo** → Captura de selfie
8. **Processing** → Upload + Trust evaluation
9. **Result** → Calidad de registro
10. **Authorization** → Auto / Host required / Denied
11. **Checked-in** → Acceso autorizado
12. **Active Visit** → Timer + journey + contact host
13. **Checkout** → Confirmación de salida
14. **Completed** → Resumen + journey timeline

## Consola de Gestión

- **Login** → Supabase Auth (email/password)
- **Dashboard** → Stats del día (hoy, activas, pendientes, completadas)
- **Visitas** → Lista con filtros + búsqueda
- **Detalle** → Info completa + Trust Score + Journey + Autorizar/Rechazar

## Trust Layer

```
TrustScoreService (interface)
├── MockTrustScoreService (MVP)
└── AiTrustScoreService (futuro)

Evidence → TrustEvaluation → AccessPolicy → AccessDecision
```

El Trust Score representa **Registration & Evidence Quality**, nunca peligrosidad.

## Supabase Schema

- `organizations` — Configuración del inmueble
- `profiles` — Usuarios (Admin, Host, Reception)
- `visitors` — Personas que visitan
- `visits` — Eventos de visita
- `visit_evidence` — Fotos de ID y selfie
- `trust_evaluations` — Score del Trust Layer
- `access_decisions` — Decisiones de política
- `visitor_journey_events` — Timeline completa
- `consent_records` — Registro legal

## Diseño

> ⚠️ El diseño actual es un placeholder con Material 3.
> Cuando la **Kigo Design Skill** esté disponible, se aplicará como Design System obligatorio.

## Próximos pasos (post-MVP)

- [ ] Integración IA real (AiTrustScoreService)
- [ ] OCR para identificaciones
- [ ] Push notifications para anfitriones
- [ ] Múltiples organizaciones
- [ ] Configuración de políticas desde consola
- [ ] Dashboard analytics
- [ ] Integración con APIs reales de Kigo
