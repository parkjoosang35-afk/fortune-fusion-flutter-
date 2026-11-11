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
    // google-services.json(package_name: com.sintongbantong.app)을 추가했으나
    // 실제 applicationId(com.fortunefusion.fortune)와 불일치해
    // processReleaseGoogleServices 태스크가 빌드를 실패시켰다. 불필요한
    // 플러그인이므로 제거한다(구글 로그인 기능에는 영향 없음).
}

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

// ─────────────────────────────────────────────────────────────────────────────
// [앱 표시 이름 고정 — 아이콘 아래 이름이 항상 '신통방통']
//
// 배경: 빌드 도구(샌드박스 서명/리네임 단계)가 android/app/src/main/
// AndroidManifest.xml 의 android:label 문자열을 프로젝트 메타 이름
// ("My App", "Fortune Fusion" 등)으로 덮어쓰는 일이 반복됐다. 그 결과
// 실기기 홈 화면 아이콘 밑 이름이 매번 바뀌었다(대표 신고, 커밋 b7943d2 /
// a9bc42a 에서 두 번 재발).
//
// 대책(2중 방어):
//  1) 매니페스트는 리터럴 대신 @string/app_name 을 참조한다.
//     → 매니페스트가 덮어써져도 strings.xml 의 app_name 이 살아있으면 이름 유지.
//  2) 빌드(리소스 병합) 직전에 실행되는 훅에서 strings.xml 의 app_name 과
//     매니페스트의 label 을 '신통방통'으로 강제 재작성한다.
//     → strings.xml 까지 덮어써진 경우에도 복구된다.
//
// 이 태스크는 assembleBundle 의 모든 변형(assembleRelease/assembleDebug 등)
// 이 의존하므로 APK/AAB 어느 쪽으로 빌드해도 항상 먼저 실행된다.
// ─────────────────────────────────────────────────────────────────────────────
val appDisplayName = "신통방통"

val ensureAppLabel by tasks.registering {
    description = "빌드 도구가 되돌린 앱 표시 이름을 '신통방통'으로 강제 복구한다."
    group = "flutter"

    val manifestFile = layout.projectDirectory.file("src/main/AndroidManifest.xml").asFile
    val stringsFile = layout.projectDirectory.file("src/main/res/values/strings.xml").asFile
    val desiredName = appDisplayName

    // 입력/출력 선언 대신 항상 실행한다(설정 단계 비용이 거의 없고,
    // 빌드 도구가 언제 파일을 건드릴지 예측할 수 없기 때문).
    outputs.upToDateWhen { false }

    doLast {
        // 1) strings.xml 의 app_name 보정
        if (stringsFile.exists()) {
            var xml = stringsFile.readText()
            val appNameRegex = Regex("""<string name="app_name">.*?</string>""")
            xml = if (appNameRegex.containsMatchIn(xml)) {
                appNameRegex.replace(xml, """<string name="app_name">$desiredName</string>""")
            } else {
                xml.replaceFirst(
                    "<resources>",
                    "<resources>\n    <string name=\"app_name\">$desiredName</string>"
                )
            }
            stringsFile.writeText(xml)
        }

        // 2) 매니페스트의 android:label → @string/app_name 로 보정
        if (manifestFile.exists()) {
            var manifest = manifestFile.readText()
            // 리터럴 label(어떤 값이든)을 리소스 참조로 치환.
            // 이미 @string/ 참조면 그대로 둔다.
            val labelRegex = Regex("android:label=\"(?!@string/)[^\"]*\"")
            manifest = labelRegex.replace(manifest, "android:label=\"@string/app_name\"")
            manifestFile.writeText(manifest)
        }

        logger.lifecycle("[ensureAppLabel] 앱 표시 이름을 '$desiredName' 으로 고정했습니다.")
    }
}

// 리소스/매니페스트 병합 이전에 반드시 실행되도록 연결
tasks.matching {
    it.name.startsWith("preBuild") ||
        it.name.startsWith("merge") && it.name.endsWith("Resources") ||
        it.name == "processDebugMainManifest" ||
        it.name == "processReleaseMainManifest" ||
        it.name == "processDebugManifest" ||
        it.name == "processReleaseManifest"
}.configureEach {
    dependsOn(ensureAppLabel)
}

dependencies {
    // [Phase C-1] flutter_local_notifications 20.1.0 desugaring 요구사항
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}


