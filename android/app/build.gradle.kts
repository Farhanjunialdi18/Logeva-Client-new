import java.util.Properties

// Kunci rilis (android/key.properties + app/logeva-rilis.jks, tidak ikut git).
// SIMPAN CADANGANNYA: tanpa kunci yang sama, APK baru tidak bisa menimpa
// aplikasi yang sudah terpasang di HP lapangan.
val kunciRilis = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.gmls.logeva"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Dibutuhkan flutter_local_notifications (notifikasi lokal, tanpa internet).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // ID tetap aplikasi. JANGAN diganti lagi setelah dipasang di HP lapangan:
        // ID berbeda = aplikasi lain (tidak bisa update, data lama tertinggal).
        applicationId = "id.gmls.logeva"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (kunciRilis.isNotEmpty()) {
            create("rilis") {
                keyAlias = kunciRilis["keyAlias"] as String
                keyPassword = kunciRilis["keyPassword"] as String
                storeFile = file(kunciRilis["storeFile"] as String)
                storePassword = kunciRilis["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Tanpa key.properties (misal komputer lain) memakai kunci debug,
            // tapi APK itu TIDAK bisa menimpa APK rilis resmi di HP lapangan.
            signingConfig = if (kunciRilis.isNotEmpty())
                signingConfigs.getByName("rilis")
            else
                signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
