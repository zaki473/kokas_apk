plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.kokas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // PERBAIKAN 1: Gunakan isCoreLibraryDesugaringEnabled untuk Kotlin DSL
        isCoreLibraryDesugaringEnabled = true 
    }

    // PERBAIKAN 2: Cara terbaru mengatur jvmTarget agar tidak deprecated
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.kokas"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // WAJIB: Tambahkan ini agar isCoreLibraryDesugaringEnabled berfungsi
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}