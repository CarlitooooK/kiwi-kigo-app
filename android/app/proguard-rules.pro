# R8/ProGuard rules for Kigo Welcome (release builds).

# ML Kit text recognition references optional language recognizers (Chinese,
# Devanagari, Japanese, Korean) that we don't bundle — tell R8 to ignore them.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# TensorFlow Lite (MobileFaceNet embeddings) — keep runtime + reflection APIs.
-dontwarn org.tensorflow.lite.InterpreterFactoryApi
-dontwarn org.tensorflow.lite.annotations.UsedByReflection
-keep class org.tensorflow.lite.** { *; }
-keep class com.common.pos.api.util.** { *; }

# Telpo F10 dedicated NFC reader (accessed via reflection + dynamic Proxy):
#   com.common.face.api.NfcRd_Utils / NfcRdlistener / NfcRdObserver.
# Keep the classes AND the NfcRdlistener interface (its method names are used
# reflectively), or R8 could rename/strip them and break the proxy.
-keep class com.common.face.api.** { *; }
-keep interface com.common.face.api.** { *; }
