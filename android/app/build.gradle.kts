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
