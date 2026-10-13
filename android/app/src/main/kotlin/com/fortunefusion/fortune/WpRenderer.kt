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
     * [v2.7 오버레이 터치 영역] 홈 화면 터치를 판정하는 기준 좌표(390×844)
     * 영역 목록. 실제 배경화면 서비스가 화면 좌표를 [mapTouchToBase]로
     * 기준 좌표로 바꾼 뒤 이 영역과 비교한다 — 렌더와 터치가 "같은 좌표"
     * 원칙(§3)을 공유해 영역이 어긋나지 않는다.
     *  - clock/bubble/card: 신통방통 앱 바로 열기.
     *  - devotion: 치성(WishActionQueue 기록 + 캐릭터 기도 연출).
     */
    data class WpZone(val id: String, val left: Float, val top: Float, val right: Float, val bottom: Float)

    fun overlayZones(): List<WpZone> = listOf(
        WpZone("clock", 110f, 20f, 280f, 132f),
        WpZone("bubble", 20f, 386f, 250f, 446f),
        WpZone("card", 16f, 702f, 262f, 792f),
        WpZone("devotion", 276f, 700f, 368f, 794f),
    )

    /** 화면 좌표 [x],[y]를 기준 캔버스(390×844) 좌표로 환산한다. */
    fun mapTouchToBase(w: Float, h: Float, x: Float, y: Float): Pair<Float, Float> {
        val scale = max(w / BASE_W, h / BASE_H)
        val offX = (w - BASE_W * scale) / 2f
        val offY = (h - BASE_H * scale) / 2f
        return Pair((x - offX) / scale, (y - offY) / scale)
    }

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
        // [v2.7 오버레이] 위젯 썸네일 등 기존 호출자는 기본값(null/false)이라
        // 시그니처 변경 영향 없이 HUD 없이 그려진다.
        clock: String? = null,
        dateLabel: String? = null,
        bubble: String? = null,
        devotionLabel: String? = null,
        praying: Boolean = false,
        prayerT: Double = 0.0,
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
        // [v2.7 기도 연출] 치성 탭 뒤 2.6초 동안 캐릭터가 절제된 큰절을 흉내
        // 낸다(살짝 내려앉았다 올라오는 곡선) + 머리 위 금빛 후광 링.
        m.character?.let { ch ->
            bitmapOf(ch.asset)?.let { bmpChar ->
                val bowPhase = if (praying) sin(Math.PI * min(1.0, prayerT / 2.6)).toFloat() else 0f
                canvas.save()
                val breathe = 1f + 0.008f * sin(t * 1.745).toFloat()
                canvas.translate(ch.x, ch.y + 10f * bowPhase)
                canvas.scale(breathe * (1f - 0.02f * bowPhase), breathe, 0f, 0f)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                val rect = android.graphics.RectF(-ch.s / 2, -ch.s, ch.s / 2, 0f)
                canvas.drawBitmap(bmpChar, null, rect, paint)
                canvas.restore()
                if (bowPhase > 0.01f) {
                    val halo = Paint(Paint.ANTI_ALIAS_FLAG)
                    halo.shader = RadialGradient(ch.x, ch.y - ch.s - 10f, 60f + 30f * bowPhase, withAlpha(Color.parseColor("#FFE9A8"), 0.55f * bowPhase), Color.TRANSPARENT, Shader.TileMode.CLAMP)
                    canvas.drawCircle(ch.x, ch.y - ch.s - 10f, 60f + 30f * bowPhase, halo)
                }
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

        // ── v2.7 HUD 오버레이 — 시계·날짜·말풍선·소원카드·치성 버튼 ──
        // [사용자 피드백] 참고 이미지(소원방 홈) 1:1 지향. 절제된 크기로
        // 방 일러스트를 가리지 않게 위에만 얹는다. 터치 영역은
        // overlayZones()가 렌더와 같은 좌표로 관리한다.
        if (m.overlay) {
            val hudPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            if (clock != null) {
                val shadow = Paint(Paint.ANTI_ALIAS_FLAG)
                shadow.color = Color.argb(150, 0, 0, 0)
                shadow.textSize = 36f
                shadow.textAlign = Paint.Align.CENTER
                shadow.isFakeBoldText = true
                canvas.drawText(clock, BASE_W / 2f + 1.5f, 67.5f, shadow)
                val timePaint = Paint(Paint.ANTI_ALIAS_FLAG)
                timePaint.color = Color.WHITE
                timePaint.textSize = 36f
                timePaint.textAlign = Paint.Align.CENTER
                timePaint.isFakeBoldText = true
                canvas.drawText(clock, BASE_W / 2f, 66f, timePaint)
                if (dateLabel != null) {
                    val dShadow = Paint(Paint.ANTI_ALIAS_FLAG)
                    dShadow.color = Color.argb(150, 0, 0, 0)
                    dShadow.textSize = 13f
                    dShadow.textAlign = Paint.Align.CENTER
                    canvas.drawText(dateLabel, BASE_W / 2f + 1f, 95f, dShadow)
                    val datePaint = Paint(Paint.ANTI_ALIAS_FLAG)
                    datePaint.color = Color.parseColor("#F2ECE2")
                    datePaint.textSize = 13f
                    datePaint.textAlign = Paint.Align.CENTER
                    canvas.drawText(dateLabel, BASE_W / 2f, 94f, datePaint)
                }
            }
            if (bubble != null) {
                val textPaint = Paint(Paint.ANTI_ALIAS_FLAG)
                textPaint.color = Color.parseColor("#4A3223")
                textPaint.textSize = 13f
                val tw = textPaint.measureText(bubble)
                val bl = (BASE_W - tw - 28f) / 2f
                hudPaint.color = withAlpha(Color.WHITE, 0.94f)
                canvas.drawRoundRect(android.graphics.RectF(bl, 396f, bl + tw + 28f, 440f), 21f, 21f, hudPaint)
                canvas.drawText(bubble, bl + 14f, 423f, textPaint)
            }
            // 소원 카드(좌하단) — 탭하면 앱 진입.
            val cardRect = android.graphics.RectF(16f, 702f, 262f, 792f)
            hudPaint.color = withAlpha(Color.parseColor("#FFF4D8"), 0.95f)
            canvas.drawRoundRect(cardRect, 18f, 18f, hudPaint)
            val border = Paint(Paint.ANTI_ALIAS_FLAG)
            border.style = Paint.Style.STROKE
            border.strokeWidth = 1.2f
            border.color = withAlpha(Color.parseColor("#E9C46A"), 0.8f)
            canvas.drawRoundRect(cardRect, 18f, 18f, border)
            hudPaint.color = withAlpha(Color.parseColor("#E9C46A"), 0.28f)
            canvas.drawCircle(52f, 747f, 21f, hudPaint)
            val sealText = Paint(Paint.ANTI_ALIAS_FLAG)
            sealText.color = Color.parseColor("#B8860B")
            sealText.textSize = 24f
            sealText.textAlign = Paint.Align.CENTER
            sealText.isFakeBoldText = true
            canvas.drawText("財", 52f, 756f, sealText)
            val cardText = Paint(Paint.ANTI_ALIAS_FLAG)
            cardText.color = Color.parseColor("#4A3223")
            cardText.textSize = 14f
            val wish = m.wishText?.takeIf { it.isNotEmpty() } ?: "소원을 빌러 오세요"
            canvas.drawText(if (wish.length > 16) wish.take(16) + "…" else wish, 88f, 742f, cardText)
            val subText = Paint(Paint.ANTI_ALIAS_FLAG)
            subText.color = Color.parseColor("#8A7350")
            subText.textSize = 11f
            canvas.drawText("터치해서 소원방 열기", 88f, 766f, subText)
            // 치성 버튼(우하단) — 탭하면 기록 + 기도 연출.
            val btn = Paint(Paint.ANTI_ALIAS_FLAG)
            btn.color = withAlpha(Color.parseColor("#FF7FA8"), if (praying) 0.95f else 0.88f)
            canvas.drawCircle(322f, 747f, 44f, btn)
            val btnText = Paint(Paint.ANTI_ALIAS_FLAG)
            btnText.color = Color.WHITE
            btnText.textSize = 14f
            btnText.textAlign = Paint.Align.CENTER
            btnText.isFakeBoldText = true
            canvas.drawText("치성", 322f, 744f, btnText)
            if (devotionLabel != null) {
                val cnt = Paint(Paint.ANTI_ALIAS_FLAG)
                cnt.color = withAlpha(Color.WHITE, 0.9f)
                cnt.textSize = 11f
                cnt.textAlign = Paint.Align.CENTER
                canvas.drawText(devotionLabel, 322f, 762f, cnt)
            }
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
