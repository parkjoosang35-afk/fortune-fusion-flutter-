// ✅ CRITICAL: Required imports for signing configuration
import java.util.Properties
import java.io.FileInputStream

// [6-7-3] Release 서명 연결: android/key.properties를 읽어와
// signingConfigs.release 에서 사용한다. (기존 key.properties/release-key.jks를
// 그대로 사용하며, 새 keystore는 생성하지 않는다.)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // [패키지명 통일, 2026-10-02] google_sign_in 패키지는 Dart 쪽
    // SocialAuthConfig.googleWebClientId(하드코딩된 Web Client ID)만으로
    // 동작하며 google-services.json을 전혀 읽지 않는다(firebase_core도
    // 사용하지 않음 — 이 앱은 Firebase 미사용). 과거 세션에서 이 플러그인과
    // google-services.json(package_name: com.guinjido.app.legacy)을 추가했으나
    // 실제 applicationId(com.guinjido.app)와 불일치해
    // processReleaseGoogleServices 태스크가 빌드를 실패시켰다. 불필요한
    // 플러그인이므로 제거한다(구글 로그인 기능에는 영향 없음).
}

// [패키지명 원복, 2026-11-25] Google Play Console에 "일회성 제품"
// 등록을 위해 com.android.vending.BILLING 권한을 추가하며 임시로
// applicationId를 com.guinjido.app으로 바꿨으나, Play Console에
// 이미 com.fortunefusion.fortune(versionCode 18/19)으로 내부테스트
// 트랙에 AAB가 업로드되어 있고 카카오 디벨로퍼스 콘솔에도 동일
// 패키지명으로 등록돼 있어(둘 다 변경 이력 없음) applicationId를
// com.fortunefusion.fortune으로 원복한다. 앱 표시 이름(label)은
// AndroidManifest.xml에서 "귀인지도"로 그대로 유지 — applicationId는
// 사용자에게 보이지 않는 내부 식별자이고 label과 무관하다.
// ⚠️ 트레이드오프: admin_web의 sintong.kr/.well-known/assetlinks.json이
// 이미 com.guinjido.app 기준으로 배포돼 있어(admin_web 읽기전용,
// 이번 세션에서 수정 불가), App Links autoVerify 자동 앱 열기가
// 당장은 동작하지 않고 기존 폴백(웹페이지 → "앱에서 열기" 버튼)
// 경로로 동작한다.
android {
    namespace = "com.fortunefusion.fortune"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // [Phase C-1] flutter_local_notifications 20.1.0이 예약 알림의 하위호환을
        // 위해 desugaring + Java 17을 요구함(패키지 android/build.gradle 참고).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fortunefusion.fortune"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // [Phase C-1] desugaring 사용 시 함께 권장되는 설정(패키지 README 참고).
        multiDexEnabled = true
    }

    // [6-7-3] Release 서명 연결: 기존 android/key.properties + android/release-key.jks 를 사용.
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // [6-7-3] 기존 debug 서명 대신 정식 release 서명 키를 사용한다.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // [Phase C-1] flutter_local_notifications 20.1.0 desugaring 요구사항
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}


