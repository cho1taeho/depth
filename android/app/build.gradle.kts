// android/settings.gradle.kts


// --------------------------------------------------

// android/build.gradle.kts (Project-Level)

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.4.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.10")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --------------------------------------------------

// android/app/build.gradle.kts (Module-Level)

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

defaultTasks("assembleDebug")

android {
    namespace = "com.example.depth"
    compileSdk = 35


    defaultConfig {
        applicationId = "com.example.depth"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
    }

}

dependencies {
    implementation("com.google.ar:core:1.40.0")
}

flutter {
    source = "../.."
}
