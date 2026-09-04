# Kigo Welcome — Inteligencia Artificial del Proyecto

> Documento honesto sobre qué es **IA real** y qué es **heurística/fórmula** en el
> kiosko Self Check-In (FEPRO 2026). Toda la IA corre **on-device, offline, a $0**
> (sin APIs de pago, sin LLM). Última actualización: 2026-09-03.

---

## Principio rector: honestidad técnica

No todo lo que "parece inteligente" es IA. Este documento separa con precisión:

- **IA real** — modelos de machine learning (redes neuronales) que infieren sobre
  datos: reconocimiento facial, OCR y detección facial.
- **NO es IA** — fórmulas ponderadas y heurísticas deterministas: el Trust Score
  agregado y el liveness de un solo frame.

Presentamos cada pieza como lo que realmente es.

---

## 1. IA REAL

### 1.1 Reconocimiento facial — MobileFaceNet (TFLite)

**El corazón de IA del proyecto.** Verificación facial 1:1 entre la selfie y el
rostro de la identificación, y reconocimiento 1:N para visitantes recurrentes.

- **Modelo:** MobileFaceNet, red neuronal convolucional.
- **Runtime:** `tflite_flutter` (TensorFlow Lite) — `assets/models/mobilefacenet.tflite`.
- **Entrada:** recorte facial 112×112×3 float32. **Salida:** embedding de **192 dimensiones**.
- **Comparación:** similitud coseno entre embeddings. Misma persona ≈ 0.6–0.85;
  personas distintas ≈ 0.0–0.3. Umbral de match para recurrentes: **≥ 0.62**.
- **Piso de ruido:** cosenos < 0.15 se reportan como 0 (no representan coincidencia real).
- **Dónde vive:** `lib/features/trust/data/face_embedder.dart`,
  `face_recognition_service.dart`.
- **Por qué es IA:** una CNN entrenada mapea rostros a un espacio vectorial donde la
  distancia refleja identidad. No es comparación de píxeles ni de proporciones
  geométricas — es inferencia aprendida.

### 1.2 OCR de identificaciones — ML Kit Text Recognition

Lectura del texto de la INE/identificación para extraer CURP, clave de elector,
nombre y fecha de nacimiento.

- **Modelo:** Google ML Kit Text Recognition (redes neuronales de reconocimiento de texto).
- **Paquete:** `google_mlkit_text_recognition`.
- **Dónde vive:** `lib/features/identity/domain/mlkit_identity_service.dart`.
- **Por qué es IA:** el reconocimiento óptico de caracteres usa modelos de deep
  learning para segmentar y clasificar glifos. La **extracción posterior** (regex
  de CURP/clave) sí es determinista, pero el OCR subyacente es IA.

### 1.3 Detección facial — ML Kit Face Detection

Localiza rostros, ojos, pose y sonrisa en una imagen. Sustrato de la selfie, el
liveness y el recorte que alimenta a MobileFaceNet.

- **Modelo:** Google ML Kit Face Detection.
- **Paquete:** `google_mlkit_face_detection`.
- **Señales:** bounding box, landmarks (ojos), `leftEyeOpenProbability`,
  `rightEyeOpenProbability`, ángulos de pose, `smilingProbability`.
- **Por qué es IA:** detección y análisis de rostros con modelos entrenados.

### 1.4 (Contexto) Detección de códigos de barras / QR — ML Kit

En dispositivos sin lector físico (tablets), el escaneo de QR usa
`google_mlkit_barcode_scanning`. Es visión por computadora de ML Kit. En el F10 se
usa el lector físico keyboard-wedge (no IA).

---

## 2. NO ES IA (y lo decimos claro)

### 2.1 Trust Score agregado — fórmula ponderada

El número 0–100 que ve el anfitrión **no es un modelo de IA**: es un promedio
ponderado de cuatro señales. Mide **calidad de la evidencia de registro**, nunca
"peligrosidad".

```
score = (OCR·0.20 + coincidencia_nombre·0.30 + liveness·0.20 + face_match·0.30) · 100
```

- **Dónde vive:** `lib/features/trust/data/ai_trust_score_service.dart` (engine `AI_V1`).
- **Matices deterministas:** penalización por reintentos (−5 por intento extra > 2),
  pisos duros (face_match < 0.15 → score ×0.4; OCR < 0.1 → score ×0.5).
- **Importante:** aunque el archivo se llame `ai_trust_score_service`, el **agregado
  es una fórmula**. Lo que sí es IA es **una de sus entradas** (`face_match`, que viene
  de MobileFaceNet). La coincidencia de nombre usa similitud de cadenas (no IA).

### 2.2 Liveness — heurística sobre señales de ML Kit

Con una sola foto no hay liveness real (que requiere varios frames: parpadeo, giro).
Calculamos un score de **calidad de rostro** honesto y variable a partir de señales
de ML Kit, no un modelo anti-spoofing.

```
liveness = ojos_abiertos(0–0.35) + pose_natural(0–0.30) + encuadre(0–0.25) + sonrisa(0–0.10)
```

- **Dónde vive:** `lib/features/identity/domain/face_verification_service.dart`.
- **Por qué NO es IA:** es una suma ponderada de probabilidades que ML Kit ya calculó.
  La *detección facial* que la alimenta sí es IA; la *fórmula de liveness* no.

### 2.3 Registro por voz — STT/TTS on-device (motor del sistema)

- **STT:** `speech_to_text` (motor de reconocimiento de voz del dispositivo Android).
- **TTS:** `flutter_tts` (síntesis de voz del sistema).
- **Parser:** `voice_parser.dart` — reglas deterministas (coincidencia por palabra,
  conversión de dígitos hablados). **No hay NLP/LLM.**
- **Por qué se aclara:** el STT del sistema sí usa modelos de voz, pero **nosotros no
  entrenamos ni ejecutamos un modelo**; usamos el servicio del SO. La lógica de flujo
  y el parseo son reglas, no IA.

---

## 3. Tabla resumen

| Componente | ¿IA real? | Tecnología | Archivo |
|---|---|---|---|
| Verificación facial 1:1 / 1:N | ✅ Sí | MobileFaceNet (TFLite), coseno | `face_embedder.dart`, `face_recognition_service.dart` |
| OCR de identificación | ✅ Sí | ML Kit Text Recognition | `mlkit_identity_service.dart` |
| Detección facial (ojos/pose/sonrisa) | ✅ Sí | ML Kit Face Detection | `face_verification_service.dart`, `face_embedder.dart` |
| Escaneo QR por cámara (no-F10) | ✅ Sí | ML Kit Barcode Scanning | `camera_qr_scanner.dart` |
| **Trust Score agregado** | ❌ No | Fórmula ponderada | `ai_trust_score_service.dart` |
| **Liveness (1 frame)** | ❌ No | Heurística sobre señales ML Kit | `face_verification_service.dart` |
| Extracción CURP/clave | ❌ No | Regex determinista | `mlkit_identity_service.dart` |
| Coincidencia de nombre | ❌ No | Similitud de cadenas | `ai_trust_score_service.dart` |
| Flujo/parseo de voz | ❌ No | Reglas deterministas | `voice_parser.dart` |
| STT / TTS | ⚠️ Del sistema | Motores del SO Android | `voice_service.dart` |

---

## 4. Costo y privacidad

- **$0 de inferencia:** todo corre en el dispositivo. Cero llamadas a APIs de IA de pago,
  cero LLM. El modelo TFLite (~4 MB) va empaquetado en el APK.
- **Privacidad:** los embeddings faciales y el OCR se calculan **en el F10**; las imágenes
  no se envían a terceros para inferencia. El rostro **nunca es llave única** para un
  extraño — solo conveniencia (autollenar) o fast-path para recurrentes que el anfitrión
  marcó explícitamente tras un checkout autorizado.

---

## 5. Modelo empaquetado

- `assets/models/mobilefacenet.tflite` — MobileFaceNet, input 112×112×3 float32, output 1×192.
- Registrado en `pubspec.yaml` bajo `assets/models/`.
