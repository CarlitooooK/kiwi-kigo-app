---
name: kigo-design-system
version: 3.0
description: >
  Self-contained Kigo design system. Primary color: Kigo 500 #FF6900.
  Applied as mandatory Design System for all Kigo Welcome Intelligence screens.
  Adapted for Flutter (not JSX) — tokens, colors, typography, spacing, and UX gates apply.
inclusion: always
---

# ADAPTATION NOTES FOR FLUTTER

This skill was originally written for JSX/React generators (Lovable, Figma Make).
For this Flutter project, the following adaptations apply:

- JSX locked components → translated to Flutter widgets with equivalent tokens
- CSS values → mapped to Flutter ThemeData, ColorScheme, TextTheme
- px values → dp in Flutter (1:1 ratio)
- `backdrop-filter` → not available in Flutter standard; use Container + BoxDecoration
- Liquid Glass navbar → NOT applicable to Kigo Welcome (this is a kiosk/console app, not the main Kigo app)
- Mobile header pills → NOT applicable (kiosk has its own flow-based navigation)
- Dashboard shell → adapted to Flutter NavigationRail pattern already in place

## WHAT APPLIES TO KIGO WELCOME:

1. COLOR SYSTEM — all tokens (Kigo orange, Umbral neutrals, Semantics, Grays)
2. TYPOGRAPHY — scale, weights, hierarchy discipline
3. UX RESEARCH GATE — mandatory before every screen
4. WRITING GATE — all copy rules (infinitive verbs, cause+action errors, gerund loading)
5. MOTION GATE — 6 defined moments only
6. UNIVERSAL PROHIBITIONS — orange count ≤3, weight-700 ≤2, no emojis, etc.
7. COMPONENTS — cards, inputs, badges, buttons (adapted to Flutter)
8. ACCESSIBILITY — touch targets ≥48dp, contrast, visible labels
9. EMPTY/ERROR/LOADING states — skeleton, CTA required, cause+action

## WHAT DOES NOT APPLY:

- 3-item floating pill navbar (Estacionar/Acceder/Escanear) — that's the main Kigo app
- Mobile header pills (Variant A/B/C) — kiosk uses its own navigation
- iPhone 17 Pro frame wrapper — not relevant for Flutter development
- Flujo completo / Una pantalla output format — for design tools only
- Dashboard React/shadcn shell — we use Flutter NavigationRail

---

# FULL SKILL CONTENT BELOW (reference)
# ================================================


## COLOR SYSTEM (Kigo Official Tokens)

### Primary — Kigo orange
| Token | Hex | Use |
|-------|-----|-----|
| Kigo 300 | #FFCBA4 | Active nav icon (light variant) |
| Kigo 500 | #FF6900 | Primary CTA, active accents — max 3 simultaneous |
| Kigo 600 | #E55E00 | Orange hover/pressed |
| Kigo 900 | #7A2E00 | Orange text on light bg (rare) |

### Neutral — Umbral warm
| Token | Hex | Use |
|-------|-----|-----|
| Umbral 50 | #FEF9F8 | Page background, content area |
| Umbral 100 | #F6EEED | Input background, card hover |
| Umbral 200 | #E9DEDD | Card border, dividers |
| Umbral 300 | #D5C5C3 | Skeleton shimmer base |

### Semantic
| Token | Hex | Use |
|-------|-----|-----|
| Green 600 | #00A63E | Success, transactional CTA |
| Green 100 | #DCFCE7 | Success badge background |
| Red 500 | #FB2C36 | Error text, inline errors |
| Red 600 | #E7000B | Error badge text |
| Red 100 | #FEE2E2 | Error badge background |
| Yellow 400 | #FDC700 | Warning |
| Yellow 50 | #FEFCE8 | Warning card background |
| Sky 50 | #F0F9FF | Info badge background |
| Sky 900 | #024A70 | Info badge text |

### Gray scale
| Token | Hex | Use |
|-------|-----|-----|
| Neutral 900 / Slate 900 | #0F172B | Primary text |
| Slate 500 | #62748E | Secondary text |
| Gray 200 | #E5E7EB | Console sidebar background |
| Gray 400 | #9CA3AF | Captions |
| Gray 500 | #6B7280 | Supporting text |

## TYPOGRAPHY
- Hero/key value: 32-48px / 700
- Screen title: 22-24px / 700 (max 1 per screen)
- Section heading: 17px / 600
- Body: 15-16px / 400
- Caption/label: 13-14px / 400 / #6B7280
- Badge: 12px / 600

## WEIGHT DISCIPLINE
- Maximum 2 weight-700 elements visible simultaneously
- Body text ALWAYS at 400
- 600 for card titles, headers, structure
- 700 ONLY for hero anchors and key outcome values

## BUTTONS
- Height: 46px (always fixed, never padding-defined)
- Width: 100%
- Border-radius: 14px
- Orange CTA: gradient(180deg, #FF8848 0%, #FF6900 100%) — intent, no money
- Green CTA: gradient(180deg, #66BB6A 0%, #00A63E 100%) — transactional
- Font: 14px / 600 / white
- Loading: spinner replaces text, button disabled

## CARDS
- Background: #FFFFFF
- Border: 1px solid #E9DEDD (Umbral 200)
- Border-radius: 14px
- Padding: 14px 16px (mobile) / 16px 20px (console)
- Never nest cards inside cards
- Gap between cards: 12px

## INPUTS
- Height: 48px mobile / 44px console
- Background: #F6EEED default / #FFFFFF focus
- Border: 1.5px solid #E9DEDD default / 2px solid #FF6900 focus
- Border-radius: 10px mobile / 8px console
- Always visible label above (never placeholder-only)

## BADGES
| State | Background | Text |
|-------|-----------|------|
| Success | #DCFCE7 | #00A63E |
| Warning | #FEFCE8 | #A65F00 |
| Error | #FEE2E2 | #E7000B |
| Info | #F0F9FF | #024A70 |
| Neutral | #F5F5F5 | Slate 500 |

## WRITING RULES
- Buttons: verbs in infinitive (Recargar, Confirmar pago, Pagar ahora)
- Errors: cause + action ("No pudimos procesar tu pago. Intenta de nuevo.")
- Loading: gerund without ellipsis ("Procesando pago", "Verificando acceso")
- Empty states: ALWAYS include a CTA
- Tone: Cercano, directo, profesional. Tuteo. No "usted". No emojis.
- Domain: Tag (not sticker), Acceso (not entrada), Escanear (not leer), Vehículo (not carro)

## MOTION (6 defined moments only)
1. Screen navigation: FadeTransition 200ms / slide 300ms forward / 250ms back
2. Bottom sheets: 250ms entry / 200ms exit
3. Skeleton → content: 150ms crossfade
4. Tap feedback: scale 0.97 primary / 0.98 card, 100ms
5. Success state: spring scale 0→1.1→0.95→1, 500ms (green icon, NEVER orange)
6. Header transitions: crossfade 200ms

Everything else: DO NOT ANIMATE.

## UNIVERSAL PROHIBITIONS
- Maximum 3 orange elements visible simultaneously
- Maximum 2 weight-700 elements visible simultaneously
- No emojis anywhere
- No orange on: badge backgrounds, section headings, body text
- No alternating table row colors
- Body text always 400 weight
- No full-screen spinner (skeleton only for content loading)
- Spinner only INSIDE buttons during async actions

## UX RESEARCH GATE (mandatory before every screen)
Produce this block BEFORE any screen implementation:
```
UX ANALYSIS — [Screen name]
User: [who + where they come from]
Goal: [one sentence]
Emotional state: [anxiety / confidence / urgency / neutral]
Visual hierarchy:
1. [most important]
2. [second]
3. [third]
4. [CTA]
Semantic CTA: [green / orange] — [reason]
Removals: [what was cut and why]
```
