import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load .env file from project root (two levels up from android/app/)
val envFile = file("../../.env")
val envProperties = Properties()
if (envFile.exists()) {
    envFile.inputStream().use { envProperties.load(it) }
}

android {
    namespace = "com.lagona.riderapp.lagona_rider_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lagona.riderapp.lagona_rider_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Google Maps API Key from .env file
        // Try to get from .env file first, then from gradle properties
        val googleMapsApiKey = envProperties.getProperty("GOOGLE_MAPS_API_KEY")?.trim()
            ?: project.findProperty("GOOGLE_MAPS_API_KEY") as String?
            ?: throw GradleException("GOOGLE_MAPS_API_KEY is not set in .env file or gradle.properties. Please configure it.")
        
        // Create a string resource that can be used in AndroidManifest.xml
        resValue("string", "google_maps_api_key", googleMapsApiKey)
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
