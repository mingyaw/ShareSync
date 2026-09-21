plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.sharesync.android"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.sharesync.android"
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        buildConfigField("boolean", "SHARESYNC_QR_PINNED_HTTPS", "false")
        buildConfigField("String", "SHARESYNC_CHANNEL", "\"release\"")
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            buildConfigField("String", "SHARESYNC_CHANNEL", "\"debug\"")
            buildConfigField("boolean", "SHARESYNC_QR_PINNED_HTTPS", "false")
        }
        create("beta") {
            initWith(getByName("debug"))
            applicationIdSuffix = ".beta"
            versionNameSuffix = "-beta"
            matchingFallbacks += listOf("debug")
            buildConfigField("String", "SHARESYNC_CHANNEL", "\"beta\"")
            buildConfigField("boolean", "SHARESYNC_QR_PINNED_HTTPS", "true")
        }
        getByName("release") {
            isDebuggable = false
            isMinifyEnabled = false
            buildConfigField("String", "SHARESYNC_CHANNEL", "\"release\"")
            buildConfigField("boolean", "SHARESYNC_QR_PINNED_HTTPS", "true")
        }
    }

    buildFeatures {
        buildConfig = true
        compose = true
    }

    kotlin {
        jvmToolchain(17)
    }
}

dependencies {
    implementation("com.google.zxing:core:3.5.3")
    implementation("androidx.activity:activity:1.10.1")
    implementation(platform("androidx.compose:compose-bom:2025.04.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
