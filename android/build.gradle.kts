allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. tflite_flutter 0.11.0) compile their Java tasks to 1.8
// while Kotlin targets a newer JVM, which breaks the build with
// "Inconsistent JVM Target Compatibility". Scope the fix to that plugin only:
// pin both its Java and Kotlin compile tasks to 1.8 so they stay consistent,
// leaving every other module (including :app on 17) untouched.
subprojects {
    if (project.name == "tflite_flutter") {
        afterEvaluate {
            // Align JVM target (Java 1.8 vs Kotlin) to avoid the inconsistency error.
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
                }
            }
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = JavaVersion.VERSION_1_8.toString()
                targetCompatibility = JavaVersion.VERSION_1_8.toString()
            }
            // The plugin compiles against android-31; its own sources need >= 33.
            extensions.findByName("android")?.let { ext ->
                try {
                    val m = ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    m.invoke(ext, 34)
                } catch (_: Throwable) {
                    // If the setter shape differs, the app-level compileSdk still applies.
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
