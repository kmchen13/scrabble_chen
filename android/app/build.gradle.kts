plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.scrabble_P2P"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.scrabble_P2P"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug") // signe en debug pour test
        }
    }

applicationVariants.configureEach {
    outputs.configureEach {
        val appName = "scrabble_P2P"
        val versionName = "v1.7.0"

        // Ajoute l’ABI dans le nom de fichier pour éviter les conflits
        val abiFilter = (this as? com.android.build.gradle.internal.api.BaseVariantOutputImpl)
            ?.filters
            ?.find { it.filterType == com.android.build.OutputFile.ABI }
            ?.identifier

        val suffix = if (abiFilter != null) "-$abiFilter" else ""
        (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl).outputFileName =
            "$appName-$versionName$suffix.apk"
    }
}

}

flutter {
    source = "../.."
}
