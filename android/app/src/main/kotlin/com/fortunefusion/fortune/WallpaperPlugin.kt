package com.fortunefusion.fortune

import android.app.Activity
import android.app.WallpaperManager
import android.app.WallpaperInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * [소원방 v2.6 배경화면] Flutter ↔ 네이티브 플랫폼 브리지.
 * docs/WALLPAPER.md §1 "플랫폼 브리지" — Flutter의 `wallpaper_service.dart`가
 * MethodChannel("com.fortunefusion.fortune/wallpaper")로 이 플러그인을 호출한다.
 *
 * 지원 메서드:
 *  - setManifest(manifestJson): WishRoomWallpaperService가 그릴 레이어 명세를 저장.
 *  - isActive(): 지금 이 앱의 라이브 배경화면이 실제로 설정되어 있는지.
 *  - requestChangeLiveWallpaper(): §4.1 ACTION_CHANGE_LIVE_WALLPAPER로 시스템
 *    배경화면 선택/미리보기 화면을 띄운다(사용자가 최종 "설정"을 눌러야 적용됨).
 *  - setStaticWallpaper(target): §4.2 "홈만/잠금만" — 1.35초 시점 정지 프레임을
 *    setBitmap(FLAG_SYSTEM|FLAG_LOCK)으로 직접 설정한다(라이브 배경화면은
 *    홈/잠금을 따로 지정할 수 없다는 플랫폼 제약 때문 — Q5 확정 가정 그대로).
 *  - clear(): 배경화면 해제(§W4 DELETE 대응 — 실제로는 기본 배경화면으로 되돌림).
 *  - drainPendingActions(): §4.1 WishAction(네이티브→앱) 큐를 읽어온다(비우지 않음).
 *  - acknowledgeActions(ids): 서버 전송에 실제로 성공한 id만 큐에서 제거한다.
 */
class WallpaperPlugin(private val activity: Activity) : MethodCallHandler {

    private val context: Context get() = activity.applicationContext

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setManifest" -> {
                // [버그2 수정 — 검은 미리보기] apply()는 비동기 디스크 쓰기라
                // result.success(true)가 실제 반영 전에 반환될 수 있다. Flutter
                // 쪽(_applyAndroid)이 이 호출의 완료를 기다린 "직후" 곧바로
                // ACTION_CHANGE_LIVE_WALLPAPER Intent를 쏘므로, 여기서는 commit()으로
                // 동기 반영을 보장해 시스템 미리보기 Engine.onCreate()가 항상 최신
                // manifest_json을 읽도록 한다(값 하나만 쓰는 가벼운 작업이라
                // 메인 스레드 블로킹 영향은 무시할 수준).
                val json = call.argument<String>("manifestJson")
                val prefs = context.getSharedPreferences(WishRoomWallpaperService.PREFS_NAME, Context.MODE_PRIVATE)
                val ok = prefs.edit().putString(WishRoomWallpaperService.KEY_MANIFEST, json).commit()
                result.success(ok)
            }
            "isActive" -> {
                result.success(isThisLiveWallpaperActive())
            }
            "requestChangeLiveWallpaper" -> {
                try {
                    val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
                    intent.putExtra(
                        WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                        ComponentName(context, WishRoomWallpaperService::class.java),
                    )
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("WALLPAPER_INTENT_FAILED", e.message, null)
                }
            }
            "setStaticWallpaper" -> {
                val assetPath = call.argument<String>("assetBytesPath") // 네이티브 캐시에 저장된 절대경로(미리 PNG로 렌더해 전달)
                val target = call.argument<String>("target") ?: "BOTH" // HOME|LOCK|BOTH
                try {
                    val bmp = BitmapFactory.decodeFile(assetPath)
                    if (bmp == null) {
                        result.error("DECODE_FAILED", "정지 프레임 이미지를 읽지 못했습니다", null)
                        return
                    }
                    val wm = WallpaperManager.getInstance(context)
                    val flags = when (target) {
                        "HOME" -> WallpaperManager.FLAG_SYSTEM
                        "LOCK" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) WallpaperManager.FLAG_LOCK else WallpaperManager.FLAG_SYSTEM
                        else -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) (WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK) else WallpaperManager.FLAG_SYSTEM
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        wm.setBitmap(bmp, null, true, flags)
                    } else {
                        wm.setBitmap(bmp)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SET_BITMAP_FAILED", e.message, null)
                }
            }
            "clear" -> {
                try {
                    WallpaperManager.getInstance(context).clear()
                    val prefs = context.getSharedPreferences(WishRoomWallpaperService.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit().remove(WishRoomWallpaperService.KEY_MANIFEST).apply()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("CLEAR_FAILED", e.message, null)
                }
            }
            // [§4.1 WishAction 네이티브→앱] 조작판 위젯(WishRoomWidgetProvider)의
            // 치성 버튼 탭이 쌓아 둔 행동 기록을 그대로 JSON 문자열로 반환한다.
            // 큐 자체는 비우지 않는다(서버 전송 성공 여부를 네이티브는 모른다).
            "drainPendingActions" -> {
                try {
                    result.success(WishActionQueue.peekAll(context))
                } catch (e: Exception) {
                    result.error("DRAIN_FAILED", e.message, null)
                }
            }
            // 서버 전송에 실제로 성공한 id 목록만 큐에서 제거한다.
            "acknowledgeActions" -> {
                try {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    WishActionQueue.acknowledge(context, ids)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ACK_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isThisLiveWallpaperActive(): Boolean {
        return try {
            val wm = WallpaperManager.getInstance(context)
            val info: WallpaperInfo? = wm.wallpaperInfo
            info != null && info.packageName == context.packageName && info.serviceName == WishRoomWallpaperService::class.java.name
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        const val CHANNEL = "com.fortunefusion.fortune/wallpaper"
    }
}
