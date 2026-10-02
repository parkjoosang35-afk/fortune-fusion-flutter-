package com.sintongbantong.app

import org.json.JSONArray
import org.json.JSONObject

/**
 * [소원방 v2.6 배경화면] 네이티브 Live Wallpaper가 그릴 "레이어 명세".
 *
 * Flutter 쪽(WPManifestJson, wallpaper_service.dart)이 WishRoom + 장착 아이템의
 * 실제 좌표(features/room/room_layout.dart의 RoomLayout, 390×844 캔버스 기준)를
 * 전부 계산해서 평평한 레이어 리스트로 내려준다. 네이티브 엔진은 "같은 좌표"를
 * 그대로 그리기만 할 뿐, 배치 규칙(어느 레벨에 어떤 아이템이 어디 놓이는지)을
 * 다시 구현하지 않는다 — docs/WALLPAPER.md §3 "같은 좌표" 원칙.
 *
 * 좌표계: 기준 캔버스 390×844 (x,y,s 모두 이 기준) — 렌더러가 화면 크기에 맞게 스케일.
 */
data class WpLayer(val asset: String, val x: Float, val y: Float, val s: Float, val rotateDeg: Float = 0f)

data class WpManifest(
    val version: Int,
    val theme: String,
    val roomAsset: String,
    val brightness: Float,
    val band: String, // B1~B4 — 별빛/반딧불 개수 결정
    val fulfilled: Boolean,
    val candle: WpLayer?,
    val character: WpLayer?,
    val decorations: List<WpLayer>,
    val auraGold: Boolean,
) {
    companion object {
        fun parse(json: String?): WpManifest? {
            if (json.isNullOrEmpty()) return null
            return try {
                val o = JSONObject(json)
                fun layer(key: String): WpLayer? {
                    val l = o.optJSONObject(key) ?: return null
                    return WpLayer(
                        l.optString("asset"), l.optDouble("x").toFloat(), l.optDouble("y").toFloat(),
                        l.optDouble("s").toFloat(), l.optDouble("rotateDeg", 0.0).toFloat(),
                    )
                }
                val decoArr: JSONArray = o.optJSONArray("decorations") ?: JSONArray()
                val decos = (0 until decoArr.length()).mapNotNull { i ->
                    val l = decoArr.optJSONObject(i) ?: return@mapNotNull null
                    WpLayer(
                        l.optString("asset"), l.optDouble("x").toFloat(), l.optDouble("y").toFloat(),
                        l.optDouble("s").toFloat(), l.optDouble("rotateDeg", 0.0).toFloat(),
                    )
                }
                WpManifest(
                    version = o.optInt("version", 1),
                    theme = o.optString("theme", "free"),
                    roomAsset = o.optString("roomAsset"),
                    brightness = o.optDouble("brightness", 1.0).toFloat(),
                    band = o.optString("band", "B1"),
                    fulfilled = o.optBoolean("fulfilled", false),
                    candle = layer("candle"),
                    character = layer("character"),
                    decorations = decos,
                    auraGold = o.optBoolean("auraGold", false),
                )
            } catch (_: Exception) {
                null
            }
        }
    }
}
