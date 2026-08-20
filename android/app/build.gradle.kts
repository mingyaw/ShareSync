plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
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
    }

    kotlin {
        jvmToolchain(17)
    }
}

