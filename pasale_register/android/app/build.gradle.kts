plugins {
    id("com.android.application")
    // No kotlin-android: app is Java-only (MainActivity.java). Avoids KGP app warning.
    // See https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.pasale_register"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.akai.pasaleko"
        // ML Kit + camera require a modern minSdk.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Field-trial: still debug-signed until a release keystore is set.
            signingConfig = signingConfigs.getByName("debug")
            // Shrink unused resources + R8 code shrink (smaller APK, harder reverse-eng).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

// google-services plugin is applied above; google-services.json is optional
// until Firebase is configured. A placeholder file is committed for builds.
dependencies {
    // Firebase BoM (versions resolved by Flutter plugins; BoM keeps alignment).
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
}
