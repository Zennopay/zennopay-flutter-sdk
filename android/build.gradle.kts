group = "in.zennopay.flutter"
version = "1.0"

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        // The native Zennopay Android SDK (in.zennopay:sdk) is on Maven Central.
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "in.zennopay.flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // ComponentActivity — the type the native SDK's presentCheckout entry
    // point requires.
    implementation("androidx.activity:activity-ktx:1.8.2")

    // Compose unit types (Dp / `.dp`) used to build the native SDK's
    // ZennopayAppearance. No Compose compiler is enabled — these are plain
    // value types, no @Composable code lives here.
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.ui:ui-unit")
    // FontFamily — referenced by the native SDK's ZennopayAppearance.Typography.
    implementation("androidx.compose.ui:ui-text")

    // The native Zennopay Android SDK that renders the PaymentSheet and exposes
    // `Zennopay.presentCheckout(...)`. Pulled transitively from Maven Central so
    // partners never add it by hand.
    implementation("in.zennopay:sdk:0.7.0")
}
