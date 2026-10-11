package com.fortunefusion.fortune

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * [소원방 배경화면 v2.0 §4.1 "오가는 계약은 두 개뿐" — WishAction (네이티브 → 앱)]
 *
 * 기획서 원문: "홈에서 한 행동(촛불 켜기·소원 빌기·향) / 전달 방식: 한 줄씩
 * 덧붙이는 기록(순서 보존) — 앱이 다음 실행에 읽어 전송".
 *
 * 이 큐는 WishRoomWidgetProvider(조작판 위젯)의 치성 버튼 탭처럼, 네이티브
 * 코드(앱 프로세스가 포그라운드에 없을 수도 있는 상태)에서 발생한 "홈에서
 * 한 행동"을 기록한다. Flutter 앱은 WallpaperPlugin.drainPendingActions()로
 * 이 큐를 소비하고, 전송에 성공한 뒤에만 비운다(§6 "순서" 표 2~5행 — 실패
 * 시 기록을 지우지 않고 지수 백오프로 재시도, 중복 방지 키로 같은 행동은
 * 1건만).
 *
 * [동시성] 위젯 탭(RemoteViews PendingIntent → BroadcastReceiver, 메인
 * 프로세스에서 실행)과 Flutter 쪽 drain 호출이 같은 SharedPreferences
 * 파일을 동시에 건드릴 수 있으므로, 전체 읽기-수정-쓰기를 synchronized
 * 블록으로 감싼다. commit()(동기)을 사용해 WallpaperPlugin.setManifest()와
 * 동일한 이유로 "쓰다 만 상태"가 노출되지 않게 한다.
 */
object WishActionQueue {
    private const val PREFS_NAME = "wr_wishaction_prefs"
    private const val KEY_QUEUE = "pending_actions_json" // JSONArray of {id,type,ts}
    private val lock = Any()

    /** 홈에서 발생한 행동 종류. 기획서 §4.1 예시 그대로: 촛불 켜기·소원 빌기·향. */
    enum class Kind(val wireValue: String) {
        CANDLE("candle"), // 조작판 치성 버튼 — §6 "1~5단계"를 위젯 제약상 1탭으로 압축(설계 결정, 보고서 기재 대상)
        WISH("wish"),
        INCENSE("incense"),
    }

    /**
     * 행동 1건을 큐 끝에 덧붙인다(순서 보존). [idempotencyKey]를 지정하지
     * 않으면 UUID로 새로 발급한다 — 이 키가 서버 전송 시 중복 방지 키로
     * 그대로 쓰인다(§6 "중복 방지 키로 같은 행동은 1건만").
     */
    fun append(context: Context, kind: Kind, roomId: String?, idempotencyKey: String = UUID.randomUUID().toString()) {
        synchronized(lock) {
            val prefs = prefs(context)
            val arr = readArray(prefs)
            val entry = JSONObject().apply {
                put("id", idempotencyKey)
                put("type", kind.wireValue)
                put("roomId", roomId ?: JSONObject.NULL)
                put("ts", System.currentTimeMillis())
            }
            arr.put(entry)
            prefs.edit().putString(KEY_QUEUE, arr.toString()).commit()
        }
    }

    /**
     * 큐에 쌓인 전체 항목을 JSON 문자열(배열)로 반환하고, 큐 자체는 비우지
     * 않는다. Flutter 쪽은 서버 전송에 실제로 성공한 항목의 id만
     * [acknowledge]로 넘겨 제거해야 한다 — "실패 시 기록을 지우지 않는다"는
     * §6 보장 규칙을 네이티브가 먼저 비워버리면 지킬 수 없기 때문이다.
     */
    fun peekAll(context: Context): String {
        synchronized(lock) {
            return readArray(prefs(context)).toString()
        }
    }

    /** 서버 전송에 성공한 [ids]만 큐에서 제거한다(나머지는 다음 시도를 위해 남긴다). */
    fun acknowledge(context: Context, ids: List<String>) {
        if (ids.isEmpty()) return
        synchronized(lock) {
            val prefs = prefs(context)
            val arr = readArray(prefs)
            val kept = JSONArray()
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                if (o.optString("id") !in ids) kept.put(o)
            }
            prefs.edit().putString(KEY_QUEUE, kept.toString()).commit()
        }
    }

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun readArray(prefs: SharedPreferences): JSONArray {
        val raw = prefs.getString(KEY_QUEUE, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }
}
