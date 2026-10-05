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
    // same variables locally. With none of them set the debug key keeps
    // working, so `flutter run --release` on a fresh checkout still builds.
    // Set any of them — or HUNDRED_REQUIRE_UPLOAD_KEY=true, as the store
    // pipeline does — and an incomplete setup fails the build by name instead
    // of quietly signing a "release" with the debug key.
    //
    // Blank counts as unset: GitHub hands an unset secret over as "".
    fun env(name: String): String? = System.getenv(name)?.takeIf { it.isNotBlank() }

    val ksPath = env("HUNDRED_KEYSTORE_PATH")
    val ksStorePassword = env("HUNDRED_KEYSTORE_PASSWORD")
    val ksAlias = env("HUNDRED_KEY_ALIAS")
    // keytool's default PKCS12 keystores have a single password for both.
    val ksKeyPassword = env("HUNDRED_KEY_PASSWORD") ?: ksStorePassword
    val ksFile = ksPath?.let { file(it) }

    val signingProblems = buildList {
        when {
            ksFile == null -> add("HUNDRED_KEYSTORE_PATH is not set")
            !ksFile.isFile -> add("HUNDRED_KEYSTORE_PATH: no file at ${ksFile.absolutePath}")
        }
        if (ksStorePassword == null) add("HUNDRED_KEYSTORE_PASSWORD is not set")
        if (ksAlias == null) add("HUNDRED_KEY_ALIAS is not set")
    }
    val signingRequested = env("HUNDRED_REQUIRE_UPLOAD_KEY") == "true" ||
        listOf(
            "HUNDRED_KEYSTORE_PATH",
            "HUNDRED_KEYSTORE_PASSWORD",
            "HUNDRED_KEY_ALIAS",
            "HUNDRED_KEY_PASSWORD",
        ).any { env(it) != null }
    if (signingRequested && signingProblems.isNotEmpty()) {
        throw GradleException(
            "Release signing is incomplete (see docs/play-release.md):\n  " +
                signingProblems.joinToString("\n  "),
        )
    }

    signingConfigs {
        if (signingProblems.isEmpty()) {
            create("upload") {
                storeFile = ksFile
                storePassword = ksStorePassword
                keyAlias = ksAlias
                keyPassword = ksKeyPassword
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
