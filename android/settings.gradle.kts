pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // [카카오/구글 간편로그인] google-services.json(Firebase 콘솔에서 발급,
    // Google Sign-In OAuth 클라이언트 정보 포함)을 앱 빌드에 반영하기 위한
    // Google Services Gradle 플러그인. repositories(google())는 이미 위
    // pluginManagement 블록에 있어 별도 추가 불필요.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
