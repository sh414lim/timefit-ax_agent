plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.timefit.bootstrap.timefit_native"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Bootstrap-only namespace. Production identity is injected only after REL-001/003 approval.
        applicationId = "dev.timefit.bootstrap.timefit_native"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "TimeFit Dev")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "TimeFit Staging")
        }
    }

    buildTypes {
        release {
            // Intentionally unsigned until production identity and signing are approved.
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
}

val allowedFlutterTargetsByFlavor = mapOf(
    "Dev" to setOf(
        "lib/main.dart",
        "integration_test/chat_performance_test.dart",
    ),
    "Staging" to setOf("lib/main_staging.dart"),
)

val actualTarget = project.findProperty("target")?.toString() ?: "lib/main.dart"
val requestedTasks = gradle.startParameter.taskNames.map { it.substringAfterLast(':') }
val performanceTarget = "integration_test/chat_performance_test.dart"

if (actualTarget == performanceTarget) {
    val isExactDevProfileRequest = requestedTasks.isNotEmpty() &&
        requestedTasks.all { it.equals("assembleDevProfile", ignoreCase = true) }
    if (!isExactDevProfileRequest) {
        throw org.gradle.api.GradleException(
            "The CHAT-073 performance target requires only assembleDevProfile.",
        )
    }
} else {
    val requestedFlutterFlavor = allowedFlutterTargetsByFlavor.keys.firstOrNull { flavor ->
        requestedTasks.any { taskName -> taskName.contains(flavor, ignoreCase = true) }
    }
    if (requestedFlutterFlavor != null) {
        val allowedTargets = allowedFlutterTargetsByFlavor.getValue(requestedFlutterFlavor)
        if (actualTarget !in allowedTargets) {
            throw org.gradle.api.GradleException(
                "${requestedFlutterFlavor.lowercase()} does not allow the requested Flutter target.",
            )
        }
    }
}
