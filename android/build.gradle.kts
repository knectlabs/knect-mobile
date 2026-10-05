import com.android.build.gradle.LibraryExtension
import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.variant.LibraryAndroidComponentsExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some Flutter plugins (e.g. tflite_flutter) pin their Android library module's
// Java compatibility to 1.8, while the Kotlin compile task the toolchain injects
// defaults to the JDK running Gradle (21). Gradle rejects that pairing as
// "Inconsistent JVM-target compatibility". Hook the Android Library plugin as
// it is applied to each subproject — before AGP locks compileOptions — and
// raise Java compatibility to 17 so it matches the Kotlin target. This runs on
// every build, so it survives `flutter pub get` refreshing the plugin cache.
// (The app module already targets 17.)
subprojects {
    plugins.withId("com.android.library") {
        if (name == "tflite_flutter") {
            extensions.configure(LibraryAndroidComponentsExtension::class.java) {
                finalizeDsl {
                    // The plugin pins SDK 31, below its transitive AndroidX requirements.
                    it.compileSdk = project(":app")
                        .extensions.getByType(ApplicationExtension::class.java).compileSdk
                }
            }
        }
        extensions.configure(LibraryExtension::class.java) {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
