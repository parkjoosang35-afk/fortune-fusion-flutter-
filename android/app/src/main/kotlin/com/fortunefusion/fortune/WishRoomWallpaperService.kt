package com.fortunefusion.fortune

import android.app.ActivityManager
import android.app.WallpaperColors
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.RadialGradient
import android.graphics.Shader
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

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
        private var lastVisibleAt = System.currentTimeMillis()
        private val random = Random(7)

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
                lastVisibleAt = System.currentTimeMillis()
                handler.post(drawRunner)
            } else {
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

        /** §4 "4. fps": 30 visible / 24 idle(8초 무입력) / 15 isLowRamDevice. */
        private fun frameDelayMs(): Long {
            // 모션 줄이기(FR-W-34): 애니메이터 배율 0이면 사실상 정지(저빈도로만 갱신).
            val animatorScale = try {
                Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
            } catch (_: Throwable) {
                1f
            }
            if (animatorScale == 0f) return 1000L
            val am = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val lowRam = am?.isLowRamDevice == true
            if (lowRam) return (1000L / 15)
            val idleMs = System.currentTimeMillis() - lastVisibleAt
            val fps = if (idleMs > 8000) 24 else 30
            return (1000L / fps)
        }

        private fun bitmapOf(assetPath: String?): Bitmap? {
            if (assetPath.isNullOrEmpty()) return null
            bitmapCache[assetPath]?.let { return it }
            return try {
                // Flutter가 build 시 모든 asset을 `flutter_assets/<pubspec경로>`로 APK에
                // 번들한다(FlutterLoader 표준 레이아웃). asset_bitmap_paths로 넘어오는
                // 값은 pubspec 기준 상대경로(e.g. "assets/wishroom/rooms/room-free.jpg")다.
                val lookup = "flutter_assets/$assetPath"
                applicationContext.assets.open(lookup).use { BitmapFactory.decodeStream(it) }
            } catch (_: Exception) {
                null
            }.also { bitmapCache[assetPath] = it }
        }

        private fun draw() {
            val holder = surfaceHolder ?: return
            var canvas: Canvas? = null
            try {
                canvas = holder.lockCanvas()
                if (canvas != null) {
                    render(canvas)
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

        private fun render(canvas: Canvas) {
            val w = canvas.width.toFloat()
            val h = canvas.height.toFloat()
            canvas.drawColor(Color.parseColor("#12060E"))
            val m = manifest
            if (m == null) {
                // 매니페스트가 아직 없으면(최초 설정 직후 동기화 전) 짙은 배경만.
                return
            }
            // 390×844 기준 캔버스를 화면에 꽉 채우도록 cover 스케일.
            val baseW = 390f
            val baseH = 844f
            val scale = max(w / baseW, h / baseH)
            val offX = (w - baseW * scale) / 2f
            val offY = (h - baseH * scale) / 2f
            canvas.save()
            canvas.translate(offX, offY)
            canvas.scale(scale, scale)

            val t = (System.currentTimeMillis() - startTime) / 1000.0

            // ── L1 방 일러스트 + 밝기 ──
            bitmapOf(m.roomAsset)?.let { bmp ->
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                paint.colorFilter = brightnessFilter(m.brightness)
                val srcRatio = bmp.width.toFloat() / bmp.height.toFloat()
                val dstRatio = baseW / baseH
                val dw: Float; val dh: Float
                if (srcRatio > dstRatio) { dh = baseH; dw = baseH * srcRatio } else { dw = baseW; dh = baseW / srcRatio }
                val dx = (baseW - dw) / 2f; val dy = (baseH - dh) / 2f
                canvas.drawBitmap(bmp, null, android.graphics.RectF(dx, dy, dx + dw, dy + dh), paint)
            }

            // ── 밴드별 별빛(간이: 정적 반짝 점) ──
            val starCount = when (m.band) { "B4" -> 90; "B3" -> 80; "B2" -> 70; else -> 60 }
            val starPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FFFFF6D0") }
            val starRnd = Random(13)
            for (i in 0 until min(starCount, 40)) { // 성능 예산 고려해 화면엔 최대 40개만 실제로 그림
                val sx = 16f + starRnd.nextFloat() * 356f
                val sy = 40f + (i * 23f) % 180f
                val phase = sin(t * 1.2 + i) * 0.5 + 0.5
                starPaint.alpha = (120 + phase * 135).toInt().coerceIn(0, 255)
                canvas.drawCircle(sx, sy, 1.6f + (i % 3) * 0.8f, starPaint)
            }

            // ── 장식(decorations) — 매달린 것은 sway, 나머지 고정 ──
            val decoPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            for (d in m.decorations) {
                bitmapOf(d.asset)?.let { bmp ->
                    canvas.save()
                    val sway = sin(t * 1.4 + d.x) * 2.2 // 매달린 장식 느낌의 미세한 흔들림(도)
                    canvas.translate(d.x, d.y)
                    canvas.rotate((d.rotateDeg + sway).toFloat())
                    val rect = android.graphics.RectF(-d.s / 2, -d.s, d.s / 2, 0f)
                    canvas.drawBitmap(bmp, null, rect, decoPaint)
                    canvas.restore()
                }
            }

            // ── 금빛 오라(Lv9+) ──
            if (m.auraGold) {
                val auraPaint = Paint(Paint.ANTI_ALIAS_FLAG)
                val cx = baseW / 2f; val cy = baseH * 0.3f
                auraPaint.shader = RadialGradient(cx, cy, 220f, Color.parseColor("#52FFDC96"), Color.TRANSPARENT, Shader.TileMode.CLAMP)
                canvas.drawRect(0f, 0f, baseW, baseH, auraPaint)
            }

            // ── 촛불(candle) — 흔들리는 불꽃 + 광원 ──
            m.candle?.let { c ->
                val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
                val flick = 1f + 0.08f * sin(t * 2.4).toFloat()
                val glowR = 150f * flick * (0.6f + 0.4f * m.brightness)
                glowPaint.shader = RadialGradient(c.x, c.y - c.s * 0.4f, glowR, intArrayOf(Color.parseColor("#CCFFF0BE"), Color.parseColor("#66FFD98A"), Color.TRANSPARENT), floatArrayOf(0f, 0.4f, 1f), Shader.TileMode.CLAMP)
                canvas.drawCircle(c.x, c.y - c.s * 0.4f, glowR, glowPaint)
                bitmapOf(c.asset)?.let { bmp ->
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                    val rect = android.graphics.RectF(c.x - c.s / 2, c.y - c.s, c.x + c.s / 2, c.y)
                    canvas.drawBitmap(bmp, null, rect, paint)
                }
            }

            // ── 캐릭터(character) — 숨쉬는 느낌의 미세한 스케일 ──
            m.character?.let { ch ->
                bitmapOf(ch.asset)?.let { bmp ->
                    canvas.save()
                    val breathe = 1f + 0.01f * sin(t * 1.5).toFloat()
                    canvas.translate(ch.x, ch.y)
                    canvas.scale(breathe, breathe, 0f, 0f)
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                    val rect = android.graphics.RectF(-ch.s / 2, -ch.s, ch.s / 2, 0f)
                    canvas.drawBitmap(bmp, null, rect, paint)
                    canvas.restore()
                }
            }

            // ── 감쇠 비네트 ──
            if (m.brightness < 1f) {
                val vignette = Paint(Paint.ANTI_ALIAS_FLAG)
                val alpha = ((1f - m.brightness) * 1.2f).coerceIn(0f, 1f)
                vignette.shader = RadialGradient(baseW / 2f, baseH * 0.4f, baseH * 0.8f, Color.TRANSPARENT, Color.argb((alpha * 160).toInt(), 5, 2, 8), Shader.TileMode.CLAMP)
                canvas.drawRect(0f, 0f, baseW, baseH, vignette)
            }

            // ── 이루어진 소원방 — 은은한 금빛 리본 느낌(상단 바) ──
            if (m.fulfilled) {
                val ribbon = Paint(Paint.ANTI_ALIAS_FLAG)
                ribbon.shader = LinearGradient(0f, 0f, baseW, 0f, Color.parseColor("#F5CF6A"), Color.parseColor("#FF8FB1"), Shader.TileMode.CLAMP)
                ribbon.alpha = (120 + 60 * sin(t * 1.1)).toInt().coerceIn(60, 180)
                canvas.drawRect(0f, 0f, baseW, 6f, ribbon)
            }

            canvas.restore()
        }

        private fun brightnessFilter(b: Float): PorterDuffColorFilter? {
            // 간단한 밝기 다운틴트 — 정확한 ColorMatrix 대신 PorterDuff DARKEN으로
            // 감쇠(decay) 느낌만 근사한다(네이티브 엔진은 미리보기와 완전히 동일한
            // 픽셀을 요구하지 않음 — WALLPAPER.md는 "수식" 일치를 요구하지 Canvas
            // API 결과물의 완전한 동일성을 요구하지 않는다).
            if (b >= 0.98f) return null
            val v = (b.coerceIn(0.15f, 1f) * 255).toInt()
            return PorterDuffColorFilter(Color.argb(255 - v, 0, 0, 0), PorterDuff.Mode.DARKEN)
        }
    }
}
