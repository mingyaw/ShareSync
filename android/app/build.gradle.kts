plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.sharesync.android"
    compileSdk = 35

    val enableQrPinnedHttps = providers
        .gradleProperty("sharesync.qrPinnedHttps")
        .map { it.equals("true", ignoreCase = true) }
        .orElse(false)

    defaultConfig {
        applicationId = "com.sharesync.android"
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        buildConfigField("boolean", "SHARESYNC_QR_PINNED_HTTPS", enableQrPinnedHttps.get().toString())
        buildConfigField("String", "SHARESYNC_CHANNEL", "\"release\"")
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            buildConfigField("String", "SHARESYNC_CHANNEL", "\"debug\"")
        }
        create("beta") {
            initWith(getByName("debug"))
            applicationIdSuffix = ".beta"
            versionNameSuffix = "-beta"
            matchingFallbacks += listOf("debug")
            buildConfigField("String", "SHARESYNC_CHANNEL", "\"beta\"")
        }
        getByName("release") {
            isDebuggable = false
            isMinifyEnabled = false
            buildConfigField("String", "SHARESYNC_CHANNEL", "\"release\"")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    kotlin {
        jvmToolchain(17)
    }
}

dependencies {
    implementation("com.google.zxing:core:3.5.3")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
