plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hundreddays.hundred_days"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications, which uses java.time on
        // API levels that predate it.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hundreddays.hundred_days"
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

    // Release signing comes from the environment, so the key never lives in
    // the repository: CI decodes it from a secret, a developer can export the
    // same variables locally. Without them the debug key keeps working, so
    // `flutter run --release` on a fresh checkout still builds.
    val ksPath = System.getenv("HUNDRED_KEYSTORE_PATH")
    val ksStorePassword = System.getenv("HUNDRED_KEYSTORE_PASSWORD")
    val ksAlias = System.getenv("HUNDRED_KEY_ALIAS")
    val ksKeyPassword = System.getenv("HUNDRED_KEY_PASSWORD")

    signingConfigs {
        if (!ksPath.isNullOrEmpty() && !ksStorePassword.isNullOrEmpty() &&
            !ksAlias.isNullOrEmpty() && file(ksPath).exists()
        ) {
            create("upload") {
                storeFile = file(ksPath)
                storePassword = ksStorePassword
                keyAlias = ksAlias
                keyPassword = ksKeyPassword ?: ksStorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
                ?: signingConfigs.getByName("debug")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
