plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePath = System.getenv("CAR_CARE_KEYSTORE")
val hasReleaseSigning = !keystorePath.isNullOrBlank()

android {
    if (hasReleaseSigning) {
        signingConfigs.create("production") {
            storeFile = file(requireNotNull(keystorePath))
            storePassword = requireNotNull(System.getenv("CAR_CARE_STORE_PASSWORD"))
            keyAlias = requireNotNull(System.getenv("CAR_CARE_KEY_ALIAS"))
            keyPassword = requireNotNull(System.getenv("CAR_CARE_KEY_PASSWORD"))
        }
    }
    namespace = "com.example.car_care_app"
    compileSdk = 36
    buildToolsVersion = "35.0.0"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.car_care_app"
        minSdk = 23
        targetSdk = 35
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseSigning) "production" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
