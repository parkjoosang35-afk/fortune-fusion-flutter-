// [소원방 v2.6 배경화면] docs/WALLPAPER.md §1 "플랫폼 브리지" — `wallpaper_service.dart`.
// WallpaperScreen(화면)과 `android/.../WallpaperPlugin.kt`(네이티브) 사이의
// MethodChannel 래퍼. 여기서 하는 일은 오직 "호출"뿐이고, 레이어 좌표 계산은
// wallpaper_manifest.dart(buildNativeManifestJson)가, 실제 Canvas 그리기는
// WishRoomWallpaperService.kt가 담당한다(책임 분리).
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models.dart';
import 'wallpaper_manifest.dart';

class WallpaperService {
  WallpaperService._();
  static const _channel = MethodChannel('com.fortunefusion.fortune/wallpaper');

  /// 현재 방 상태로 네이티브 라이브 배경화면이 그릴 레이어 명세를 갱신한다.
  /// §4.3 "동기화" — 앱 복귀/정성/레벨업 등으로 room이 바뀔 때마다 호출해두면
  /// 서비스가 SharedPreferences 리스너로 다음 프레임부터 자동 반영한다.
  static Future<void> syncManifest(WishRoom room, List<WrItem> items) async {
    if (kIsWeb || !Platform.isAndroid) return; // 웹 프리뷰/iOS에서는 네이티브 서비스가 없다.
    try {
      final json = buildNativeManifestJson(room, items);
      await _channel.invokeMethod('setManifest', {'manifestJson': json});
    } catch (_) {
      // 플랫폼 채널 실패(웹 프리뷰 등)는 조용히 무시 — 화면 자체는 API 기준으로 동작.
    }
  }

  /// §4.1 — 시스템 "라이브 배경화면 선택/미리보기" 화면을 띄운다. 사용자가
  /// 그 화면에서 최종 "설정"을 눌러야 실제로 적용된다(OS 표준 플로우).
  static Future<bool> requestChangeLiveWallpaper() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('requestChangeLiveWallpaper');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// §4.2 — "홈만/잠금만"은 라이브 배경화면이 지원하지 않는 조합이라, 1.35초
  /// 시점 정지 프레임을 WallpaperManager.setBitmap(FLAG_SYSTEM|FLAG_LOCK)으로
  /// 직접 설정한다(Q5 확정 가정). [capturedPngBytes]는 화면이
  /// RepaintBoundary로 캡처한 PNG 바이트.
  static Future<bool> setStaticWallpaper(Uint8List capturedPngBytes, {required String target}) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wr_wallpaper_static_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(capturedPngBytes);
      final ok = await _channel.invokeMethod<bool>('setStaticWallpaper', {'assetBytesPath': file.path, 'target': target});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// §W4 — 배경화면 해제. 실제 OS 배경화면도 기본값으로 되돌린다.
  static Future<void> clearNative() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clear');
    } catch (_) {}
  }

  /// 지금 이 앱의 라이브 배경화면이 실제로 시스템에 설정되어 있는지.
  static Future<bool> isLiveWallpaperActive() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('isActive');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
