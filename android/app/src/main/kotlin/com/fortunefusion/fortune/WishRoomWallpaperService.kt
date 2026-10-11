package com.fortunefusion.fortune

import android.app.WallpaperColors
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder

/**
 * [소원방 v2.6 배경화면 — Android 실제 라이브 배경화면]
 * docs/WALLPAPER.md §4 "Android — 진짜 라이브 배경화면" 구현체.
 *
 * Flutter(WallpaperScreen/WallpaperService)가 PUT /me/wallpaper 로 설정을 서버에
 * 기록한 직후, WallpaperPlugin.setManifest()를 통해 이 서비스가 그릴 레이어
 * 명세(JSON, WpManifest)와 필요한 PNG/JPG 에셋 경로를 SharedPreferences(
 * "wr_wallpaper_prefs")에 저장한다. 이 서비스는 그 SharedPreferences를
 * 리스너로 구독해 다음 프레임부터 새 모습을 반영한다(§4.3 "동기화").
 *
 * 레이어 좌표는 전부 Flutter 쪽(room_layout.dart)이 계산한 390×844 기준 값을
 * 그대로 받아 쓰고(§3 "같은 좌표"), 이 서비스는 그 좌표를 화면 크기에 맞춰
 * 스케일링해서 그리기만 한다 — 배치 규칙을 다시 구현하지 않는다.
 */
class WishRoomWallpaperService : WallpaperService() {

    companion object {
        const val PREFS_NAME = "wr_wallpaper_prefs"
        const val KEY_MANIFEST = "manifest_json"
        const val KEY_ASSET_MAP = "asset_bitmap_paths" // assetKey -> 로컬 캐시 절대경로(JSON)
    }

    override fun onCreateEngine(): Engine = WpEngine()

    inner class WpEngine : Engine() {
        private val handler = Handler(Looper.getMainLooper())
        private var visible = false
        private var destroyed = false
        private val bitmapCache = HashMap<String, Bitmap?>()
        private var manifest: WpManifest? = null
        private var startTime = System.currentTimeMillis()
        /** 마지막으로 "보이기 시작한" 시각(§4.3 "5분 이상 30fps 유지" 판정 기준). */
        private var visibleSince = System.currentTimeMillis()
        /** 이번 프레임을 "정지 장면 + 촛불만"으로 그릴지(§4.3 배터리15%↓·절전모드). */
        private var renderFrozen = false

        private val prefs: SharedPreferences by lazy {
            applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
        private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { p, key ->
            if (key == KEY_MANIFEST || key == KEY_ASSET_MAP) {
                manifest = WpManifest.parse(p.getString(KEY_MANIFEST, null))
                bitmapCache.clear()
            }
        }

        private val drawRunner = object : Runnable {
            override fun run() {
                draw()
                if (visible && !destroyed) {
                    handler.postDelayed(this, frameDelayMs())
                }
            }
        }

        override fun onCreate(surfaceHolder: SurfaceHolder) {
            super.onCreate(surfaceHolder)
            manifest = WpManifest.parse(prefs.getString(KEY_MANIFEST, null))
            prefs.registerOnSharedPreferenceChangeListener(prefsListener)
        }

        override fun onVisibilityChanged(v: Boolean) {
            visible = v
            if (v) {
                // §4.3 "홈 화면으로 돌아오면 다음 프레임 안에 재개한다" — 보이기
                // 시작한 시각을 지금으로 재설정해 "5분 경과" 판정을 0부터 다시
                // 센다(화면을 벗어났다 돌아온 것은 새로운 가시 구간이다).
                visibleSince = System.currentTimeMillis()
                handler.post(drawRunner) // 지연 없이 즉시 1프레임 — "복귀 첫 프레임이 늦으면 멈췄다고 보인다".
            } else {
                // §4.3 "다른 앱을 쓰는 동안과 화면이 꺼져 있을 때는 렌더 루프를
                // 완전히 멈춘다(0fps)" — postDelayed 예약 자체를 끊는다.
                handler.removeCallbacks(drawRunner)
            }
        }

        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            super.onSurfaceChanged(holder, format, width, height)
            if (visible) draw()
        }

        override fun onDestroy() {
            super.onDestroy()
            destroyed = true
            handler.removeCallbacks(drawRunner)
            prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
            bitmapCache.values.forEach { it?.recycle() }
            bitmapCache.clear()
        }

        override fun onComputeColors(): WallpaperColors? {
            return try {
                super.onComputeColors()
            } catch (_: Throwable) {
                null
            }
        }

        /**
         * [v2.0 배경화면 기획서 §4.3 "수명주기와 배터리" 1:1 반영]
         *
         *  - 홈 화면이 보일 때만 최대 30fps.
         *  - 안 보일 때(0fps)는 onVisibilityChanged(false)에서 postDelayed 자체를
         *    끊으므로 이 함수는 호출되지 않는다 — 이 함수는 "보이는 동안"의
         *    fps만 결정한다.
         *  - 5분 이상 30fps를 유지하면 20fps로 낮춘다.
         *  - 배터리 15% 이하·절전 모드에서는 "정지 장면에 촛불만" 남긴다 —
         *    이 조건은 render()가 참조하는 [renderFrozen] 플래그로 전달하고,
         *    프레임 자체는 1fps로 거의 멈춘 것처럼 낮춘다(완전한 0fps는 "안
         *    보일 때"로 기획서가 한정하므로, 보이는 동안은 1fps로 "정지"를
         *    흉내내되 draw()는 계속 호출해 renderFrozen 레이아웃을 그린다).
         *
         * [수정 전] "8초 무입력 → 24fps"는 이 기획서 어디에도 없는 독자 추가
         * 사양이었다 — 사용자 지적대로 기획서 기준으로 교체한다. "무입력"
         * 개념 자체도 기획서에 없다(배경화면은 터치 입력을 상시 받지 않음).
         */
        private fun frameDelayMs(): Long {
            renderFrozen = false

            // 모션 줄이기(시스템 접근성 설정) — 애니메이터 배율 0이면 정지에 준해 처리.
            val animatorScale = try {
                Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
            } catch (_: Throwable) {
                1f
            }
            if (animatorScale == 0f) {
                renderFrozen = true
                return 1000L
            }

            // §4.3 "배터리 15% 이하·절전 모드에서는 정지 장면에 촛불만 남긴다".
            if (isBatteryLowOrPowerSave()) {
                renderFrozen = true
                return 1000L
            }

            // §4.3 "5분 이상 30fps를 유지하면 20fps로 낮춘다".
            val visibleMs = System.currentTimeMillis() - visibleSince
            val fps = if (visibleMs > 5 * 60 * 1000L) 20 else 30
            return (1000L / fps)
        }

        /** 배터리 15% 이하이거나 시스템 절전 모드가 켜져 있는지(§4.3). */
        private fun isBatteryLowOrPowerSave(): Boolean {
            return try {
                val bm = applicationContext.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                val pct = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 100
                if (pct in 0..15) return true
                val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                pm?.isPowerSaveMode == true
            } catch (_: Throwable) {
                false
            }
        }

        private fun bitmapOf(assetPath: String?): Bitmap? {
            if (assetPath.isNullOrEmpty()) return null
            bitmapCache[assetPath]?.let { return it }
            // [리팩토링 — WpRenderer 공용화] asset 디코딩 로직은 WpRenderer.decodeFlutterAsset()로
            // 추출되었다(위젯 썸네일과 동일 코드를 공유하기 위함). 이 서비스는 디코딩
            // 결과의 캐시(bitmapCache)만 관리한다 — 디코딩 자체는 더 이상 중복 구현하지 않는다.
            return WpRenderer.decodeFlutterAsset(applicationContext, assetPath).also { bitmapCache[assetPath] = it }
        }

        private fun draw() {
            val holder = surfaceHolder ?: return
            var canvas: Canvas? = null
            try {
                canvas = holder.lockCanvas()
                if (canvas != null) {
                    render(canvas, renderFrozen)
                }
            } catch (_: Exception) {
                // 서피스가 사라지는 순간(화면 전환) 예외가 날 수 있다 — 조용히 무시.
            } finally {
                if (canvas != null) {
                    try {
                        holder.unlockCanvasAndPost(canvas)
                    } catch (_: Exception) {
                    }
                }
            }
        }

        /**
         * [리팩토링 — WpRenderer 공용화] 실제 그리기 로직은 전부 WpRenderer.render()로
         * 추출되었다(위젯 썸네일과 라이브 배경화면이 "같은 그리기 코드"를 공유하도록 —
         * WpRenderer.kt 상단 주석 참조). 이 함수는 (1) frozen 판정에 따른 t/tReal 계산,
         * (2) manifest 부재 시 짙은 배경만 그리는 예외 처리만 담당한다.
         *
         * [v2.0 §4.3] [frozen]=true일 때는 "정지 장면에 촛불만" 남긴다 — WpRenderer가
         * 받는 [t]를 0.0 고정값으로 넘겨 별빛·장식·오라·캐릭터 호흡 등 모든 주기
         * 모션을 멈추고, 촛불만은 별도 인자 [tReal]로 계속 흔들리게 한다.
         */
        private fun render(canvas: Canvas, frozen: Boolean) {
            val m = manifest
            if (m == null) {
                // 매니페스트가 아직 없으면(최초 설정 직후 동기화 전) 짙은 배경만.
                canvas.drawColor(Color.parseColor("#12060E"))
                return
            }
            val tReal = (System.currentTimeMillis() - startTime) / 1000.0
            // frozen 상태에서는 촛불을 뺀 모든 주기 모션을 t=0 고정값으로 그려
            // "정지 장면"을 만든다(§4.3). 촛불은 tReal을 그대로 써서 계속 흔들린다.
            val t = if (frozen) 0.0 else tReal
            WpRenderer.render(canvas, canvas.width.toFloat(), canvas.height.toFloat(), m, t, tReal) { assetPath -> bitmapOf(assetPath) }
        }
    }
}
