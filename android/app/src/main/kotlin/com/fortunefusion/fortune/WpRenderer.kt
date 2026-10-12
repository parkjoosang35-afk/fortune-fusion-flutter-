package com.fortunefusion.fortune

import android.content.Context
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
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * [소원방 배경화면 v2.0 §9 "공통 데이터 계약 — 애니메이션: 종류·주기·진폭·
 * 위상·시작점"] WishRoomWallpaperService(라이브 배경화면)와
 * WishRoomWidgetProvider(조작판 위젯 썸네일)가 **같은 그리기 코드**를
 * 공유하도록 render()를 여기로 추출했다. 위젯 썸네일을 별도 로직으로 다시
 * 그리면 "같은 방인데 위젯과 배경화면의 그림이 미묘하게 다르다"는 불일치가
 * 생기기 쉽다 — 이 파일 하나만 두 소비자가 그대로 호출한다(배치 규칙을
 * 두 번 구현하지 않는다는 §4.1 원칙을 네이티브 내부에도 적용).
 *
 * [위젯 썸네일 용도로 쓸 때의 차이] 위젯은 RemoteViews 정적 Bitmap만 받을 수
 * 있으므로(§4.4 "위젯에서 쓸 수 있는 제스처는 터치와 세로 스와이프뿐" —
 * 애니메이션 Surface 자체가 없음), [t]=고정 시점(보통 0.0)으로 1회 렌더한
 * 정지 이미지를 사용한다. 촛불이 흔들리는 느낌은 주지 못하지만, 이는
 * "조작판 위젯은 기본 진입점이고, 배경화면 직접 터치가 보너스"라는 §4.4
 * 설계와 같은 맥락에서 — 위젯은 정보 전달(진행 상태·바로가기)이 주 역할이며
 * 상시 움직이는 "무대"는 배경화면 쪽 책임이다(§1 결론 "방이 사는 무대를
 * 하나 늘리는 작업"). 이 구분은 1단계 보고서에 설계 결정으로 기재한다.
 */
object WpRenderer {
    private const val BASE_W = 390f
    private const val BASE_H = 844f

    /**
     * [m]을 [w]×[h] 크기의 새 Bitmap에 그려 반환한다. [t]는 초 단위 애니메이션
     * 시점(라이브 배경화면은 실시간 경과 시간, 위젯 썸네일은 보통 0.0 고정).
     * [bitmapOf]는 호출자가 캐시를 관리할 수 있도록 외부에서 주입한다.
     */
    fun renderToBitmap(
        context: Context,
        m: WpManifest,
        w: Int,
        h: Int,
        t: Double,
        bitmapOf: (String?) -> Bitmap?,
    ): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        render(canvas, w.toFloat(), h.toFloat(), m, t, tReal = t, bitmapOf = bitmapOf)
        return bmp
    }

    /** 기존 WishRoomWallpaperService.WpEngine.render()와 동일한 로직(이식). */
    fun render(
        canvas: Canvas,
        w: Float,
        h: Float,
        m: WpManifest,
        t: Double,
        tReal: Double,
        bitmapOf: (String?) -> Bitmap?,
    ) {
        canvas.drawColor(Color.parseColor("#12060E"))
        val scale = max(w / BASE_W, h / BASE_H)
        val offX = (w - BASE_W * scale) / 2f
        val offY = (h - BASE_H * scale) / 2f
        canvas.save()
        canvas.translate(offX, offY)
        canvas.scale(scale, scale)

        // ── L1 방 일러스트 + 밝기 ──
        bitmapOf(m.roomAsset)?.let { bmpRoom ->
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.colorFilter = brightnessFilter(m.brightness)
            val srcRatio = bmpRoom.width.toFloat() / bmpRoom.height.toFloat()
            val dstRatio = BASE_W / BASE_H
            val dw: Float
            val dh: Float
            if (srcRatio > dstRatio) { dh = BASE_H; dw = BASE_H * srcRatio } else { dw = BASE_W; dh = BASE_W / srcRatio }
            val dx = (BASE_W - dw) / 2f
            val dy = (BASE_H - dh) / 2f
            canvas.drawBitmap(bmpRoom, null, android.graphics.RectF(dx, dy, dx + dw, dy + dh), paint)
        }

        // ── 밴드별 별빛(간이: 정적 반짝 점) ──
        val starCount = when (m.band) { "B4" -> 90; "B3" -> 80; "B2" -> 70; else -> 60 }
        val starPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FFFFF6D0") }
        val starRnd = kotlin.random.Random(13)
        for (i in 0 until min(starCount, 40)) {
            val sx = 16f + starRnd.nextFloat() * 356f
            val sy = 40f + (i * 23f) % 180f
            val phase = sin(t * 1.2 + i) * 0.5 + 0.5
            starPaint.alpha = (120 + phase * 135).toInt().coerceIn(0, 255)
            canvas.drawCircle(sx, sy, 1.6f + (i % 3) * 0.8f, starPaint)
        }

        // ── 장식(decorations) ──
        val decoPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        for (d in m.decorations) {
            bitmapOf(d.asset)?.let { bmpDeco ->
                canvas.save()
                val sway = sin(t * 1.4 + d.x) * 2.2
                canvas.translate(d.x, d.y)
                canvas.rotate((d.rotateDeg + sway).toFloat())
                val rect = android.graphics.RectF(-d.s / 2, -d.s, d.s / 2, 0f)
                canvas.drawBitmap(bmpDeco, null, rect, decoPaint)
                canvas.restore()
            }
        }

        // ── 금빛 오라(Lv9+) ──
        if (m.auraGold) {
            val auraPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            val cx = BASE_W / 2f
            val cy = BASE_H * 0.3f
            auraPaint.shader = RadialGradient(cx, cy, 220f, Color.parseColor("#52FFDC96"), Color.TRANSPARENT, Shader.TileMode.CLAMP)
            canvas.drawRect(0f, 0f, BASE_W, BASE_H, auraPaint)
        }

        // ── 촛불(candle) — §6.1 주기 900ms(각속도 2π/0.9s≈6.981 rad/s). tReal 사용(frozen에도 계속 흔들림). ──
        m.candle?.let { c ->
            val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            val flick = 1f + 0.08f * sin(tReal * 6.981).toFloat()
            val glowR = 150f * flick * (0.6f + 0.4f * m.brightness)
            glowPaint.shader = RadialGradient(c.x, c.y - c.s * 0.4f, glowR, intArrayOf(Color.parseColor("#CCFFF0BE"), Color.parseColor("#66FFD98A"), Color.TRANSPARENT), floatArrayOf(0f, 0.4f, 1f), Shader.TileMode.CLAMP)
            canvas.drawCircle(c.x, c.y - c.s * 0.4f, glowR, glowPaint)
            bitmapOf(c.asset)?.let { bmpCandle ->
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                val rect = android.graphics.RectF(c.x - c.s / 2, c.y - c.s, c.x + c.s / 2, c.y)
                canvas.drawBitmap(bmpCandle, null, rect, paint)
            }
        }

        // [버그수정 — "배경화면이 정지 이미지처럼 보임"] room_scene.dart L6 끝부분의
        // 상시 온기 글로우(AnimatedBuilder(animation: flick, ...))는 촛불 장착 여부와
        // 무관하게 항상 (204,330) 기준으로 그려지는데, 이 글로우가 네이티브에서는
        // m.candle?.let{} 안에만 있어 기본 양초(c_basic, 레이어 없음)일 때 통째로
        // 사라져 있었다 — 대부분의 신규 사용자(기본 장비) 화면이 거의 완전한
        // 정지 화면으로 보이던 핵심 원인. tReal 기반으로 항상 그린다(§4.3 저전력
        // 때도 촛불과 같은 취급 — "정지 장면 + 촛불만"의 "촛불"에 해당하는 효과).
        run {
            val flick = 1f + 0.03f * sin(tReal * 6.981).toFloat()
            val baseS = 300f
            val gs = baseS * flick
            val glowC = Color.parseColor("#FFD98A")
            val op = (0.4f + 0.6f * min(1f, m.brightness)).coerceIn(0f, 1f)
            val warmPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            warmPaint.shader = RadialGradient(
                204f, 330f, gs / 2f,
                intArrayOf(
                    withAlpha(Color.parseColor("#FFF0BE"), 0.80f),
                    withAlpha(glowC, 0.40f),
                    withAlpha(glowC, 0.08f),
                    Color.TRANSPARENT,
                ),
                floatArrayOf(0f, 0.22f, 0.48f, 0.66f),
                Shader.TileMode.CLAMP,
            )
            warmPaint.alpha = (op * 255).toInt().coerceIn(0, 255)
            canvas.drawCircle(204f, 330f, gs / 2f, warmPaint)
        }

        // ── L7 상시 파티클 — room_scene.dart _AmbientPainter 1:1 이식(빛먼지16·
        // 꽃잎7(Lv2+)·반딧불2(Lv4+)). frozen일 때는 [t]=0 고정이라 자연히 멈춘다. ──
        run {
            val rnd = kotlin.random.Random(5)
            val motePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FFFFF6D0") }
            for (i in 0 until 16) {
                val d = 7 + i % 5
                val ph = ((t + rnd.nextDouble() * 10.0) % d) / d
                val cx = BASE_W * (0.08 + rnd.nextDouble() * 0.84) + (if (i % 2 == 1) 1 else -1) * 20.0 * ph
                val cy = 360.0 + (i * 37) % 280 - 260.0 * ph
                motePaint.alpha = (sin(ph * Math.PI) * 0.9 * 255).toInt().coerceIn(0, 255)
                canvas.drawCircle(cx.toFloat(), cy.toFloat(), (1.4 + (i % 3) * 0.7).toFloat(), motePaint)
            }
            if (m.level >= 2) {
                val petalPaint = Paint(Paint.ANTI_ALIAS_FLAG)
                val n = 7
                for (i in 0 until n) {
                    val d = 12 + (i % 4) * 2.4
                    val ph = ((t + rnd.nextDouble() * 16.0) % d) / d
                    canvas.save()
                    val px = BASE_W * rnd.nextDouble() + (rnd.nextDouble() - 0.5) * 120.0 * ph
                    val py = -20.0 + (BASE_H + 40.0) * ph
                    canvas.translate(px.toFloat(), py.toFloat())
                    canvas.rotate((ph * 6.28 * 1.5).toFloat())
                    petalPaint.color = withAlpha(Color.parseColor("#F7A9C4"), sin(ph * Math.PI).toFloat().coerceIn(0f, 1f))
                    canvas.drawOval(android.graphics.RectF(-5.5f, -4f, 5.5f, 4f), petalPaint)
                    canvas.restore()
                }
            }
            if (m.level >= 4) {
                val fireflyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#FFF4B0")
                    maskFilter = android.graphics.BlurMaskFilter(5f, android.graphics.BlurMaskFilter.Blur.NORMAL)
                }
                val spots = listOf(Triple(300.0, 420.0, 11.0), Triple(70.0, 250.0, 14.0))
                for ((fx, fy, fd) in spots) {
                    val ph = (t % fd) / fd * 6.28
                    canvas.drawCircle((fx + 30.0 * sin(ph)).toFloat(), (fy + 20.0 * cos(ph * 1.3)).toFloat(), 3f, fireflyPaint)
                }
            }
        }

        // ── 캐릭터(character) — §6.1 호흡 주기 3.6s(각속도 2π/3.6s≈1.745 rad/s). ──
        m.character?.let { ch ->
            bitmapOf(ch.asset)?.let { bmpChar ->
                canvas.save()
                val breathe = 1f + 0.008f * sin(t * 1.745).toFloat()
                canvas.translate(ch.x, ch.y)
                canvas.scale(breathe, breathe, 0f, 0f)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                val rect = android.graphics.RectF(-ch.s / 2, -ch.s, ch.s / 2, 0f)
                canvas.drawBitmap(bmpChar, null, rect, paint)
                canvas.restore()
            }
        }

        // ── 감쇠 비네트 ──
        if (m.brightness < 1f) {
            val vignette = Paint(Paint.ANTI_ALIAS_FLAG)
            val alpha = ((1f - m.brightness) * 1.2f).coerceIn(0f, 1f)
            vignette.shader = RadialGradient(BASE_W / 2f, BASE_H * 0.4f, BASE_H * 0.8f, Color.TRANSPARENT, Color.argb((alpha * 160).toInt(), 5, 2, 8), Shader.TileMode.CLAMP)
            canvas.drawRect(0f, 0f, BASE_W, BASE_H, vignette)
        }

        // ── 이루어진 소원방 — 금빛 리본 상단 바 ──
        if (m.fulfilled) {
            val ribbon = Paint(Paint.ANTI_ALIAS_FLAG)
            ribbon.shader = LinearGradient(0f, 0f, BASE_W, 0f, Color.parseColor("#F5CF6A"), Color.parseColor("#FF8FB1"), Shader.TileMode.CLAMP)
            ribbon.alpha = (120 + 60 * sin(t * 1.1)).toInt().coerceIn(60, 180)
            canvas.drawRect(0f, 0f, BASE_W, 6f, ribbon)
        }

        canvas.restore()
    }

    /** [a]（0~1）를 적용한 ARGB 색상값 — RadialGradient 색상 배열에 직접 쓰기 위한 헬퍼. */
    private fun withAlpha(color: Int, a: Float): Int {
        val alpha = (a.coerceIn(0f, 1f) * 255).toInt()
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    private fun brightnessFilter(b: Float): PorterDuffColorFilter? {
        if (b >= 0.98f) return null
        val v = (b.coerceIn(0.15f, 1f) * 255).toInt()
        return PorterDuffColorFilter(Color.argb(255 - v, 0, 0, 0), PorterDuff.Mode.DARKEN)
    }

    /** Flutter 에셋(flutter_assets/<pubspec경로>)에서 Bitmap을 디코딩한다(캐시 없음 — 호출자가 필요 시 캐시). */
    fun decodeFlutterAsset(context: Context, assetPath: String?): Bitmap? {
        if (assetPath.isNullOrEmpty()) return null
        return try {
            context.applicationContext.assets.open("flutter_assets/$assetPath").use { BitmapFactory.decodeStream(it) }
        } catch (_: Exception) {
            null
        }
    }
}
