plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.smartvisionband"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.smartvisionband"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

subprojects {
    afterEvaluate {
        val subproject = this
        if (subproject.plugins.hasPlugin("com.android.library") || subproject.plugins.hasPlugin("com.android.application")) {
            val androidExtension = subproject.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            androidExtension?.compileSdkVersion(36)
        }
    }
}