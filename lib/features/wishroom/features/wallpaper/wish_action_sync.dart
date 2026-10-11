// [소원방 배경화면 v2.0 §4.1 "오가는 계약은 두 개뿐" — WishAction (네이티브 → 앱)]
// §6 "치성 — 홈에서 드리고 기록이 남는다" 순서표 2~5행을 Flutter 쪽에서 구현한다:
//   2. 앱: 다음 실행·허용된 백그라운드 작업에서 읽어 전송. 중복 방지 키로 같은
//      행동은 1건만.
//   3. 서버: 치성 기록 저장, 방 version 증가. 같은 키는 1건만 저장.
//   4. 앱 → 배경화면: 새 계획과 조작판 상태 갱신. 화면 경계에서 원자 교체.
//   5. 실패 시: 기록을 지우지 않고 지수 백오프로 재시도. 앱을 열지 않아도
//      다음 실행에 반드시 전송.
//
// [중요 — 조사 중 발견한 서버 제약] admin_web의 POST
// /wish-rooms/{id}/devotions는 멱등성(idempotency) 키 파라미터를 받지 않는다
// (요청 본문에 식별자를 넣어도 서버가 중복 검사에 쓰지 않음 — 일일 한도·30초
// 쿨타임만 검사). 그래서 "중복 방지 키로 같은 행동은 1건만"을 지금 당장
// 보장하려면, 서버 확장 전까지는 **클라이언트가 보낸 적 있는 키를 로컬에
// 기록**해 같은 WishAction을 두 번 보내지 않는 방식으로 막는다(아래
// [_sentKeysBox] 참고). 서버 측 진짜 멱등 처리는 별도 승인 항목으로
// 1단계 보고서에 명시한다.
//
// [추가 지시 — 배경화면 운영 비용 최소화 §5 "치성 기록은 안전하게 전송합니다"]
// 반영 사항:
//  - "완료한 치성만 전송" → kind는 네이티브 큐 적재 시점에 이미 "완료된 행동"
//    으로만 쌓인다(버튼 탭 = 즉시 완료, 취소 개념 없음 — 위젯 설계상 보장).
//  - "중복방지 키로 재시도 시 기록·보상이 중복되지 않게" → _sentKeys(로컬)로
//    서버 멱등키 부재를 보완(위 주석과 동일).
//  - "실패 시 무한 반복 금지, 재시도 간격·횟수와 중단 조건을 정의" →
//    [_maxAttempts]를 넘기면 그 action은 "영구 실패"로 간주해 큐에서 ack하고
//    로컬 실패 로그([_failedLogKey])에 1건만 남긴다(사용자에게 "치성이
//    기록되지 못했어요" 안내를 다음 조작판 진입 때 보여줄 수 있도록 — 무한정
//    재시도 타이머를 돌리며 배터리/네트워크를 소모하지 않는다).
//  - "대기·서버 확정·거절 상태를 구분 — 서버가 거절한 치성을 완료로 표시
//    금지" → [WishActionOutcome] 3분류(confirmed/rejectedPermanent/pending)로
//    구분한다. 429(DAILY_LIMIT/COOLDOWN)만 "정상적으로 더 보낼 수 없는 상태"로
//    보아 ack하고, 4xx(NOT_OWNER/INVALID_STATE/NOT_FOUND 등 서버가 "이 행동
//    자체를 거절"한 응답)는 **confirmed(완료)로 표시하지 않고** 별도
//    rejected 카운터에 남겨 재시도 대상에서 제외하되 "실패"로 집계한다.
//    네트워크 오류(타임아웃 등)만 pending으로 보아 재시도한다.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models.dart';
import '../../data/wr_api.dart';

/// 네이티브 WishActionQueue.Kind.wireValue와 1:1 대응.
enum WishActionKind { candle, wish, incense }

WishActionKind? _kindFromWire(String? v) => switch (v) {
      'candle' => WishActionKind.candle,
      'wish' => WishActionKind.wish,
      'incense' => WishActionKind.incense,
      _ => null,
    };

class WishAction {
  final String id; // 멱등키(UUID) — WishActionQueue.append()이 발급.
  final WishActionKind kind;
  final String? roomId;
  final int ts;
  const WishAction({required this.id, required this.kind, required this.roomId, required this.ts});

  factory WishAction.fromJson(Map<String, dynamic> j) => WishAction(
        id: j['id'] as String,
        kind: _kindFromWire(j['type'] as String?) ?? WishActionKind.candle,
        roomId: j['roomId'] as String?,
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}

/// 서버가 이 WishAction을 어떻게 처리했는지 3분류(비용/치성기록 최소화
/// 지시 §5 "대기·서버 확정·거절 상태를 구분"). [pending]만 재시도 대상이고,
/// [confirmed]·[rejectedPermanent]는 모두 네이티브 큐에서 제거(ack)한다 —
/// 단, rejectedPermanent는 "완료"가 아니라 "더 보낼 수 없어 포기"로 집계해
/// UI가 둘을 혼동해 "성공했다"고 보여주지 않게 한다.
enum WishActionOutcome { confirmed, rejectedPermanent, pending }

/// 1회 drainAndSync() 호출 결과 요약 — 조작판/배경화면 쪽에 "치성이 기록되지
/// 못했어요" 같은 안내를 보여줄 때 참조할 수 있도록 호출자에게 반환한다.
class WishActionSyncResult {
  final int confirmedCount;
  final int rejectedCount; // 서버가 거절(완료 아님) — 영구 실패로 ack됨.
  final int pendingCount; // 아직 전송 못함(네트워크 오류 등) — 큐에 남아 재시도.
  final int abandonedCount; // 재시도 상한 도달로 포기(영구 실패로 ack됨).
  const WishActionSyncResult({
    this.confirmedCount = 0,
    this.rejectedCount = 0,
    this.pendingCount = 0,
    this.abandonedCount = 0,
  });
}

/// §4.1/§6 WishAction 동기화 — 앱이 (포그라운드 복귀·주기적 재시도 시점에)
/// 네이티브 큐를 소비해 서버로 전송하고, 서버가 확정/거절한 것만 ack한다.
class WishActionSync {
  WishActionSync._();
  static const _channel = MethodChannel('com.fortunefusion.fortune/wallpaper');
  static const _sentKeysPrefKey = 'wr_wishaction_sent_keys'; // 서버 멱등키 미지원 보완용 로컬 중복방지(위 주석 참고)
  static const _maxSentKeysKept = 500; // 무한 증가 방지 — 최근 500개만 보관.
  static const _attemptCountsPrefKey = 'wr_wishaction_attempt_counts'; // {id: 시도횟수} — 중단조건 판정용.
  static const _failedLogKey = 'wr_wishaction_failed_log'; // 영구 실패 로그(최근 20건) — UI 안내용, 소원 본문 등 개인정보 미포함.

  /// [비용 최소화 §5 "재시도 간격·횟수와 중단 조건을 정의"] 같은 WishAction을
  /// 이 횟수만큼 시도해도 실패(네트워크 오류 등 pending)하면 더 이상 배터리·
  /// 네트워크를 쓰지 않고 포기한다 — 무한 반복 금지.
  static const _maxAttempts = 6; // _backoffSeconds 길이와 맞춤(마지막 재시도까지 전부 소진).
  static const _maxFailedLogKept = 20;

  static bool _running = false;
  static Timer? _retryTimer;
  static int _backoffStep = 0; // 지수 백오프 단계(§6 "실패 시 지수 백오프로 재시도").
  static final _backoffSeconds = [5, 15, 30, 60, 120, 300]; // 상한 5분 — 중단조건: 전체 합(약 10분35초) 내 _maxAttempts 소진 시 포기.

  /// 앱이 포그라운드로 돌아올 때(resumed)·로그인 직후·정성 화면 진입 시 등
  /// "허용된 시점"에 호출한다. roomId가 주어지면 그 방에 한해 devote()를
  /// 호출한다(위젯은 항상 "내 소원방" 1개만 다루므로 보통 me.room.id 고정).
  ///
  /// [비용 최소화 §3 "홈 화면을 켤 때마다 서버를 조회하지 마세요"] 이 함수는
  /// 네이티브 "로컬" 큐를 읽을 뿐 서버를 조회하지 않는다 — 큐가 비어있으면
  /// (평소 대부분의 호출) 네트워크 요청이 전혀 발생하지 않는다. 서버 호출은
  /// 큐에 실제로 쌓인 WishAction이 있을 때만(= 홈에서 치성을 실제로 했을
  /// 때만) devote() 1회로 발생한다.
  static Future<WishActionSyncResult> drainAndSync({required WrRepository repo, String? fallbackRoomId}) async {
    if (kIsWeb) return const WishActionSyncResult();
    if (_running) return const WishActionSyncResult();
    _running = true;
    var confirmed = 0, rejected = 0, pending = 0, abandoned = 0;
    try {
      final raw = await _channel.invokeMethod<String>('drainPendingActions');
      if (raw == null || raw.isEmpty) return const WishActionSyncResult();
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      if (list.isEmpty) {
        _backoffStep = 0;
        return const WishActionSyncResult();
      }
      final actions = list
          .whereType<Map>()
          .map((m) => WishAction.fromJson(m.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.ts.compareTo(b.ts)); // 순서 보존(§4.1).

      final sentKeys = await _loadSentKeys();
      final attemptCounts = await _loadAttemptCounts();
      final failedLog = await _loadFailedLog();
      final ackIds = <String>[]; // confirmed + rejectedPermanent + abandoned 모두 ack(네이티브 큐에서 제거) 대상.
      var anyPending = false;

      for (final action in actions) {
        if (sentKeys.contains(action.id)) {
          // 이미 서버가 확정한 적 있는 키(이전 실행에서 전송은 성공했으나
          // ack가 네이티브까지 전달되기 전에 프로세스가 죽은 경우) — 서버에
          // 또 보내지 않고 ack만 다시 시도한다.
          ackIds.add(action.id);
          confirmed++;
          continue;
        }
        final roomId = action.roomId ?? fallbackRoomId;
        if (roomId == null) {
          // 보낼 방을 특정할 수 없으면 이 항목은 건너뛰고 다음 기회에
          // 재시도한다(기록을 지우지 않음 — §6 "실패 시 기록을 지우지
          // 않는다"와 동일한 취지). 단, 이것도 시도 횟수에 포함해 영구히
          // roomId를 못 구하는 상황이 무한 재시도로 이어지지 않게 한다.
          final outcome = _recordAttempt(attemptCounts, action.id);
          if (outcome == WishActionOutcome.pending) {
            anyPending = true;
            pending++;
          } else {
            ackIds.add(action.id);
            abandoned++;
            _appendFailedLog(failedLog, action, 'ROOM_ID_UNKNOWN');
          }
          continue;
        }
        try {
          // §6 1단계 "촛불 켜기"가 홈에서 발생한 시점에 이미 "완료된 행동"
          // 으로 취급하므로(네이티브 큐 적재 = 완료 기록), Flutter는 그
          // 행동을 서버의 실제 치성 규칙(devote())으로 그대로 전송해
          // "확정"받는다. incense/wish도 현재 서버 계약상 별도 엔드포인트가
          // 없어 devote()로 합산 처리한다(§6 "서비스의 실제 치성 규칙과
          // 횟수를 그대로 사용" 원칙 — 조작판 1탭을 치성 1건으로 카운트).
          await repo.devote(roomId);
          ackIds.add(action.id);
          sentKeys.add(action.id);
          attemptCounts.remove(action.id);
          confirmed++;
        } on ApiError catch (e) {
          if (e.status == 429) {
            // 일일 한도·쿨타임(429)은 "지금은 더 보낼 수 없는 정상 상태"
            // (서버가 "거절"한 게 아니라 "지금은 안 됨") — 완료로도 표시하지
            // 않지만 재시도도 하지 않는다(네이티브 쪽에서 이미 조작판에 버튼
            // 비활성화로 안내했어야 할 상황). 큐에서 제거해 무한 재시도를 막는다.
            ackIds.add(action.id);
            attemptCounts.remove(action.id);
            rejected++;
          } else if (e.status >= 400 && e.status < 500) {
            // [비용 최소화 §5 "서버가 거절한 치성을 완료로 표시하지 않는다"]
            // NOT_OWNER(403)·INVALID_STATE(409)·NOT_FOUND(404) 등 서버가 이
            // 행동 자체를 영구히 거절한 4xx — 네트워크 재시도로 해결되지
            // 않으므로 즉시 영구 실패 처리(confirmed로 올리지 않음).
            ackIds.add(action.id);
            attemptCounts.remove(action.id);
            rejected++;
            _appendFailedLog(failedLog, action, e.code);
            if (kDebugMode) debugPrint('[WishActionSync] devote 거절(영구): ${e.code}');
          } else {
            // 5xx 등 서버 쪽 일시 오류 — pending으로 보아 재시도.
            final outcome = _recordAttempt(attemptCounts, action.id);
            if (outcome == WishActionOutcome.pending) {
              anyPending = true;
              pending++;
              if (kDebugMode) debugPrint('[WishActionSync] devote 실패(재시도 예정): ${e.message}');
            } else {
              ackIds.add(action.id);
              abandoned++;
              _appendFailedLog(failedLog, action, 'MAX_ATTEMPTS_${e.code}');
            }
          }
        } catch (e) {
          // 네트워크 타임아웃 등 — pending(서버 응답 자체를 못 받음).
          final outcome = _recordAttempt(attemptCounts, action.id);
          if (outcome == WishActionOutcome.pending) {
            anyPending = true;
            pending++;
            if (kDebugMode) debugPrint('[WishActionSync] devote 예외(재시도 예정): $e');
          } else {
            ackIds.add(action.id);
            abandoned++;
            _appendFailedLog(failedLog, action, 'MAX_ATTEMPTS_EXCEPTION');
          }
        }
      }

      if (ackIds.isNotEmpty) {
        await _channel.invokeMethod('acknowledgeActions', {'ids': ackIds});
      }
      await _saveSentKeys(sentKeys);
      await _saveAttemptCounts(attemptCounts);
      if (abandoned > 0 || rejected > 0) await _saveFailedLog(failedLog);

      if (anyPending) {
        _scheduleRetry(repo: repo, fallbackRoomId: fallbackRoomId);
      } else {
        // [비용 최소화 §5 "중단 조건"] pending이 하나도 없으면(전부
        // confirmed/rejected/abandoned로 종결) 재시도 타이머를 완전히
        // 멈춘다 — 다음 WishAction이 새로 쌓이기 전까지 타이머가 계속
        // 돌며 배터리를 쓰는 일이 없다.
        _backoffStep = 0;
        _retryTimer?.cancel();
        _retryTimer = null;
      }
      return WishActionSyncResult(confirmedCount: confirmed, rejectedCount: rejected, pendingCount: pending, abandonedCount: abandoned);
    } on MissingPluginException {
      // 플러그인 미등록(iOS/웹 등) — 조용히 무시.
      return const WishActionSyncResult();
    } catch (e) {
      if (kDebugMode) debugPrint('[WishActionSync] drain 전체 실패: $e');
      _scheduleRetry(repo: repo, fallbackRoomId: fallbackRoomId);
      return const WishActionSyncResult();
    } finally {
      _running = false;
    }
  }

  /// [id]의 시도 횟수를 1 증가시키고, [_maxAttempts]를 넘었으면
  /// [WishActionOutcome.rejectedPermanent]를, 아니면 [WishActionOutcome.pending]을
  /// 반환한다. 호출자가 pending이면 attemptCounts에 남겨두고, 아니면
  /// attemptCounts에서 제거해야 한다(포기했으므로 더 셀 필요 없음).
  static WishActionOutcome _recordAttempt(Map<String, int> attemptCounts, String id) {
    final next = (attemptCounts[id] ?? 0) + 1;
    if (next >= _maxAttempts) {
      attemptCounts.remove(id);
      return WishActionOutcome.rejectedPermanent;
    }
    attemptCounts[id] = next;
    return WishActionOutcome.pending;
  }

  static void _appendFailedLog(List<Map<String, dynamic>> log, WishAction action, String reasonCode) {
    // [비용 최소화 §7 "개인 소원 본문을 로그에 포함하지 마세요"] 여기 담는
    // 필드는 id(UUID)·kind·reasonCode·ts뿐이다 — 소원 문구·방 내용은 네이티브
    // 큐에도, 이 로그에도 애초에 담기지 않는다(WishAction 자체가 "행동
    // 종류+시각"만 담는 구조).
    log.add({'id': action.id, 'kind': action.kind.name, 'reasonCode': reasonCode, 'ts': action.ts});
    if (log.length > _maxFailedLogKept) {
      log.removeRange(0, log.length - _maxFailedLogKept);
    }
  }

  /// 최근 영구 실패(거절·포기) 기록을 읽는다 — 조작판/배경화면 화면이 "치성이
  /// 기록되지 못했어요" 안내를 보여줄 때 참고할 수 있다. 소원 본문은 담겨
  /// 있지 않다(위 [_appendFailedLog] 참고).
  static Future<List<Map<String, dynamic>>> recentFailures() => _loadFailedLog();

  /// §6 "실패 시 지수 백오프로 재시도. 앱을 열지 않아도 다음 실행에 반드시
  /// 전송" — 앱이 살아있는 동안은 이 타이머로 재시도하고, 앱이 완전히
  /// 종료된 뒤에는 다음 실행(콜드 스타트) 시 drainAndSync 최초 1회 호출이
  /// 이 역할을 대신한다(main.dart/App 초기화 지점에서 호출).
  ///
  /// [비용 최소화 §5 중단 조건] _backoffSeconds를 전부 소진(= 개별 action은
  /// _maxAttempts에서 이미 포기)한 뒤에도 또 다른 pending이 남아있을 때만
  /// 마지막 간격(5분)으로 계속 재시도한다 — 네트워크가 완전히 끊긴 기기에서
  /// 조작판을 반복 사용해도 요청 주기는 5분을 넘지 않도록 상한을 둔다.
  static void _scheduleRetry({required WrRepository repo, String? fallbackRoomId}) {
    _retryTimer?.cancel();
    final idx = _backoffStep.clamp(0, _backoffSeconds.length - 1);
    final delay = Duration(seconds: _backoffSeconds[idx]);
    _backoffStep = (_backoffStep + 1).clamp(0, _backoffSeconds.length - 1);
    _retryTimer = Timer(delay, () => drainAndSync(repo: repo, fallbackRoomId: fallbackRoomId));
  }

  static Future<Set<String>> _loadSentKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_sentKeysPrefKey) ?? const [];
    return list.toSet();
  }

  static Future<void> _saveSentKeys(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = keys.length > _maxSentKeysKept
        ? keys.skip(keys.length - _maxSentKeysKept).toList()
        : keys.toList();
    await prefs.setStringList(_sentKeysPrefKey, trimmed);
  }

  static Future<Map<String, int>> _loadAttemptCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_attemptCountsPrefKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveAttemptCounts(Map<String, int> counts) async {
    final prefs = await SharedPreferences.getInstance();
    if (counts.isEmpty) {
      await prefs.remove(_attemptCountsPrefKey);
    } else {
      await prefs.setString(_attemptCountsPrefKey, jsonEncode(counts));
    }
  }

  static Future<List<Map<String, dynamic>>> _loadFailedLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_failedLogKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveFailedLog(List<Map<String, dynamic>> log) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_failedLogKey, jsonEncode(log));
  }
}
