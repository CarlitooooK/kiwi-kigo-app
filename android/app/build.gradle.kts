plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.kiwi_kigo"
    // tflite_flutter requires compileSdk >= 33.
    compileSdk = maxOf(flutter.compileSdkVersion, 34)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.kiwi_kigo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // tflite_flutter needs API 26+ for its native TFLite runtime.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// tflite_flutter 0.11.0 pulls three TensorFlow Lite artifacts
// (tensorflow-lite, -api, -gpu) that all declare the `org.tensorflow.lite`
// namespace. AGP 9's manifest merger rejects the duplicate. The main
// `tensorflow-lite` artifact already bundles the API classes, so we drop the
// `-api` and `-gpu` modules to leave a single namespace owner.
configurations.all {
    exclude(group = "org.tensorflow", module = "tensorflow-lite-api")
    exclude(group = "org.tensorflow", module = "tensorflow-lite-gpu")
    exclude(group = "org.tensorflow", module = "tensorflow-lite-gpu-api")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Telpo F10 access-control SDK:
//   PosUtil (relay/door) is invoked via reflection from MainActivity. Its
//   native lib lives in src/main/jniLibs (libposutil.so, all ABIs) and its
//   Java classes are bundled from app/libs/PosUtil.jar. Verified on-device:
//   the F10 firmware does NOT expose PosUtil on the app classpath, so the .jar
//   must ship inside the APK for reflection to resolve.
dependencies {
    implementation(files("libs/PosUtil.jar"))
}

flutter {
    source = "../.."
}
