// [소원방 v2.6 배경화면] docs/WALLPAPER.md §1 "플랫폼 브리지" — `wallpaper_service.dart`.
// WallpaperScreen(화면)과 `android/.../WallpaperPlugin.kt`(네이티브) 사이의
// MethodChannel 래퍼. 여기서 하는 일은 오직 "호출"뿐이고, 레이어 좌표 계산은
// wallpaper_manifest.dart(buildNativeManifestJson)가, 실제 Canvas 그리기는
// WishRoomWallpaperService.kt가 담당한다(책임 분리).
//
// [v2.0 §8 "화면·문구·오류 수정" — 오류 코드 체계] 과거엔 모든 네이티브 실패를
// 조용히 false/null로만 반환해, 화면에서 원인을 구분할 수 없었다("앱이 선택기를
// 열 수 없음"과 "서버가 특정 HTTP 메서드를 거부함"을 같은 토스트로 묶던 문제의
// 네이티브 쪽 절반). 이제 각 호출 실패를 [WpErrorCode]로 구분해 [lastErrorCode]에
// 남기고, 개발 로그에는 원인 코드를, 사용자에게는 내부 경로·코드를 노출하지 않는
// 재시도 안내 문구만 보여준다(사용자 문구는 [WpErrorCode.userMessage] 참고).
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models.dart';
import 'wallpaper_manifest.dart';

/// v2.0 §8 지원 오류 구분표. 문자열 값은 지시서가 요구하는 개발 로그용
/// 식별자(PLUGIN_NOT_REGISTERED 등)와 그대로 일치시킨다 — QA/개발팀이
/// 로그에서 검색할 때 지시서 문서와 1:1로 대응되어야 하기 때문이다.
enum WpErrorCode {
  /// MethodChannel에 네이티브 핸들러가 등록되지 않음(플러그인 미등록·엔진 교체 등).
  pluginNotRegistered,
  /// 네이티브가 해당 메서드 자체를 처리하지 못함(알려지지 않은 호출·플랫폼 미지원).
  methodNotSupported,
  /// 방 스냅샷(manifest)을 네이티브에 반영하지 못함 — 다음 프레임이 최신 상태가 아닐 수 있음.
  snapshotInvalid,
  /// 미리보기/정지 프레임용 자산(캡처 바이트 등)을 준비하지 못함.
  assetMissing,
  /// 네이티브 Bitmap 디코딩·합성·WallpaperManager 적용 자체가 실패함.
  renderFailed,
  /// 시스템 배경화면 선택기(Activity)를 열 수 없음 — Activity 부재·Intent 해석 실패 등.
  pickerUnavailable,
}

extension WpErrorCodeX on WpErrorCode {
  /// 개발 로그·QA 리포트에서 검색할 식별자. 지시서 §8 표기와 동일한 대문자 스네이크케이스.
  String get devCode => switch (this) {
        WpErrorCode.pluginNotRegistered => 'PLUGIN_NOT_REGISTERED',
        WpErrorCode.methodNotSupported => 'METHOD_NOT_SUPPORTED',
        WpErrorCode.snapshotInvalid => 'SNAPSHOT_INVALID',
        WpErrorCode.assetMissing => 'ASSET_MISSING',
        WpErrorCode.renderFailed => 'RENDER_FAILED',
        WpErrorCode.pickerUnavailable => 'PICKER_UNAVAILABLE',
      };

  /// 사용자에게 보여줄 재시도 안내. 내부 경로·코드·토큰은 절대 포함하지 않는다.
  String get userMessage => switch (this) {
        WpErrorCode.pluginNotRegistered => '지금은 배경화면 기능을 사용할 수 없어요. 앱을 최신 버전으로 업데이트한 뒤 다시 시도해주세요.',
        WpErrorCode.methodNotSupported => '이 기기에서는 이 방식이 지원되지 않아요. 잠시 후 다시 시도해주세요.',
        WpErrorCode.snapshotInvalid => '소원방 정보를 준비하지 못했어요. 다시 시도해주세요.',
        WpErrorCode.assetMissing => '미리보기 이미지를 만들지 못했어요. 다시 시도해주세요.',
        WpErrorCode.renderFailed => '배경화면을 적용하지 못했어요. 다시 시도해주세요.',
        WpErrorCode.pickerUnavailable => '기기에서 배경화면 설정 화면을 열 수 없어요.',
      };
}

class WallpaperService {
  WallpaperService._();
  static const _channel = MethodChannel('com.fortunefusion.fortune/wallpaper');

  /// 가장 마지막 네이티브 호출에서 발생한 실패 원인. 성공하면 각 메서드가
  /// 호출 시작 시점에 null로 재설정한다 — 화면은 호출 직후 이 값을 읽어
  /// 구체적인 사용자 안내를 고를 수 있다(§8 "모든 실패를 같은 토스트로 묶지 말 것").
  static WpErrorCode? lastErrorCode;

  static void _logError(WpErrorCode code, Object error) {
    lastErrorCode = code;
    if (kDebugMode) {
      // 개발 로그는 지시서 §8이 요구하는 식별자 그대로 남긴다. 토큰·소원
      // 내용은 여기 어떤 인자에도 포함되지 않으므로 그대로 출력해도 안전하다.
      debugPrint('[Wallpaper] ${code.devCode}: $error');
    }
  }

  /// 현재 방 상태로 네이티브 라이브 배경화면이 그릴 레이어 명세를 갱신한다.
  /// §4.3 "동기화" — 앱 복귀/정성/레벨업 등으로 room이 바뀔 때마다 호출해두면
  /// 서비스가 SharedPreferences 리스너로 다음 프레임부터 자동 반영한다.
  static Future<void> syncManifest(WishRoom room, List<WrItem> items) async {
    lastErrorCode = null;
    if (kIsWeb || !Platform.isAndroid) return; // 웹 프리뷰/iOS에서는 네이티브 서비스가 없다.
    try {
      final json = buildNativeManifestJson(room, items);
      final ok = await _channel.invokeMethod<bool>('setManifest', {'manifestJson': json});
      if (ok != true) _logError(WpErrorCode.snapshotInvalid, 'setManifest returned false');
    } on MissingPluginException catch (e) {
      _logError(WpErrorCode.pluginNotRegistered, e);
    } on PlatformException catch (e) {
      _logError(WpErrorCode.snapshotInvalid, e);
    } catch (e) {
      _logError(WpErrorCode.snapshotInvalid, e);
    }
  }

  /// §4.1 — 시스템 "라이브 배경화면 선택/미리보기" 화면을 띄운다. 사용자가
  /// 그 화면에서 최종 "설정"을 눌러야 실제로 적용된다(OS 표준 플로우).
  /// 반환값은 "선택기를 여는 데 성공했는가"일 뿐, "배경화면이 적용됐는가"가
  /// 아니다(§3 동선 4 — 선택기 호출 성공과 적용 성공은 다른 상태).
  static Future<bool> requestChangeLiveWallpaper() async {
    lastErrorCode = null;
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('requestChangeLiveWallpaper');
      if (ok != true) _logError(WpErrorCode.pickerUnavailable, 'requestChangeLiveWallpaper returned false');
      return ok ?? false;
    } on MissingPluginException catch (e) {
      _logError(WpErrorCode.pluginNotRegistered, e);
      return false;
    } on PlatformException catch (e) {
      // 네이티브가 WALLPAPER_INTENT_FAILED로 보내는 경우 = Activity 부재·Intent
      // 해석 실패(§5.2) — 선택기를 열 수 없는 상황이므로 PICKER_UNAVAILABLE로 구분.
      _logError(e.code == 'WALLPAPER_INTENT_FAILED' ? WpErrorCode.pickerUnavailable : WpErrorCode.methodNotSupported, e);
      return false;
    } catch (e) {
      _logError(WpErrorCode.pickerUnavailable, e);
      return false;
    }
  }

  /// §4.2 — "홈만/잠금만"은 라이브 배경화면이 지원하지 않는 조합이라, 1.35초
  /// 시점 정지 프레임을 WallpaperManager.setBitmap(FLAG_SYSTEM|FLAG_LOCK)으로
  /// 직접 설정한다(Q5 확정 가정). [capturedPngBytes]는 화면이
  /// RepaintBoundary로 캡처한 PNG 바이트.
  ///
  /// [v2.0 §3 버튼 정책 변경 이후] 이 메서드는 더 이상 WallpaperScreen 기본
  /// 동선에서 호출되지 않는다("지원되지 않는 잠금 화면 단독 설정을 보장하거나
  /// 정지 이미지로 몰래 대체하지 않는다"). 네이티브 능력 자체는 남겨두되,
  /// 화면의 "정지 이미지 저장" 보조 메뉴는 이 메서드 대신 갤러리 저장
  /// (image_gallery_saver.dart)을 사용한다 — 배경화면 설정이 아니라 단순
  /// 이미지 저장이라는 점을 코드 경로로도 분리하기 위함.
  static Future<bool> setStaticWallpaper(Uint8List capturedPngBytes, {required String target}) async {
    lastErrorCode = null;
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wr_wallpaper_static_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(capturedPngBytes);
      final ok = await _channel.invokeMethod<bool>('setStaticWallpaper', {'assetBytesPath': file.path, 'target': target});
      if (ok != true) _logError(WpErrorCode.renderFailed, 'setStaticWallpaper returned false');
      return ok ?? false;
    } on MissingPluginException catch (e) {
      _logError(WpErrorCode.pluginNotRegistered, e);
      return false;
    } on PlatformException catch (e) {
      _logError(e.code == 'DECODE_FAILED' ? WpErrorCode.assetMissing : WpErrorCode.renderFailed, e);
      return false;
    } catch (e) {
      _logError(WpErrorCode.renderFailed, e);
      return false;
    }
  }

  /// §W4 — 배경화면 해제. 실제 OS 배경화면도 기본값으로 되돌린다.
  static Future<void> clearNative() async {
    lastErrorCode = null;
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clear');
    } on MissingPluginException catch (e) {
      _logError(WpErrorCode.pluginNotRegistered, e);
    } catch (e) {
      _logError(WpErrorCode.methodNotSupported, e);
    }
  }

  /// 지금 이 앱의 라이브 배경화면이 실제로 시스템에 설정되어 있는지.
  /// §3 동선 5/§5.1 getWallpaperStatus 계약 — 선택기를 연 "직후"가 아니라
  /// 앱이 다시 보이게 됐을 때(resumed) 이 값을 확인해야 진짜 적용 여부를 안다.
  static Future<bool> isLiveWallpaperActive() async {
    lastErrorCode = null;
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('isActive');
      return ok ?? false;
    } on MissingPluginException catch (e) {
      _logError(WpErrorCode.pluginNotRegistered, e);
      return false;
    } catch (e) {
      _logError(WpErrorCode.methodNotSupported, e);
      return false;
    }
  }
}
