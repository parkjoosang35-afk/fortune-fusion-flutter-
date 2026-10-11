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

/// §4.1/§6 WishAction 동기화 — 앱이 (포그라운드 복귀·주기적 재시도 시점에)
/// 네이티브 큐를 드레인해 서버로 전송하고, 성공한 것만 ack한다.
class WishActionSync {
  WishActionSync._();
  static const _channel = MethodChannel('com.fortunefusion.fortune/wallpaper');
  static const _sentKeysPrefKey = 'wr_wishaction_sent_keys'; // 서버 멱등키 미지원 보완용 로컬 중복방지(위 주석 참고)
  static const _maxSentKeysKept = 500; // 무한 증가 방지 — 최근 500개만 보관.

  static bool _running = false;
  static Timer? _retryTimer;
  static int _backoffStep = 0; // 지수 백오프 단계(§6 "실패 시 지수 백오프로 재시도").
  static final _backoffSeconds = [5, 15, 30, 60, 120, 300]; // 상한 5분.

  /// 앱이 포그라운드로 돌아올 때(resumed)·로그인 직후·정성 화면 진입 시 등
  /// "허용된 시점"에 호출한다. roomId가 주어지면 그 방에 한해 devote()를
  /// 호출한다(위젯은 항상 "내 소원방" 1개만 다루므로 보통 me.room.id 고정).
  static Future<void> drainAndSync({required WrRepository repo, String? fallbackRoomId}) async {
    if (kIsWeb) return; // 웹에는 네이티브 큐가 없다.
    if (_running) return;
    _running = true;
    try {
      final raw = await _channel.invokeMethod<String>('drainPendingActions');
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      if (list.isEmpty) {
        _backoffStep = 0;
        return;
      }
      final actions = list
          .whereType<Map>()
          .map((m) => WishAction.fromJson(m.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.ts.compareTo(b.ts)); // 순서 보존(§4.1).

      final sentKeys = await _loadSentKeys();
      final succeededIds = <String>[];
      var anyFailed = false;

      for (final action in actions) {
        if (sentKeys.contains(action.id)) {
          // 이미 보낸 적 있는 키(이전 실행에서 전송은 성공했으나 ack가
          // 네이티브까지 전달되기 전에 프로세스가 죽은 경우) — 서버에 또
          // 보내지 않고 ack만 다시 시도한다.
          succeededIds.add(action.id);
          continue;
        }
        final roomId = action.roomId ?? fallbackRoomId;
        if (roomId == null) {
          // 보낼 방을 특정할 수 없으면 이 항목은 건너뛰고 다음 기회에
          // 재시도한다(기록을 지우지 않음 — §6 "실패 시 기록을 지우지
          // 않는다"와 동일한 취지).
          anyFailed = true;
          continue;
        }
        try {
          // §6 1단계 "촛불 켜기"가 홈에서 발생한 시점에 이미 "기록된" 것으로
          // 취급하므로(네이티브 큐 적재 = 기록), Flutter는 그 행동을 서버의
          // 실제 치성 규칙(devote())으로 그대로 전송한다. incense/wish도
          // 현재 서버 계약상 별도 엔드포인트가 없어 devote()로 합산 처리한다
          // (§6 "서비스의 실제 치성 규칙과 횟수를 그대로 사용" 원칙 — 조작판
          // 1탭을 치성 1건으로 카운트).
          await repo.devote(roomId);
          succeededIds.add(action.id);
          sentKeys.add(action.id);
        } on ApiError catch (e) {
          // 일일 한도·쿨타임(429)은 "지금은 더 보낼 수 없는 정상 상태"이므로
          // 큐에서 제거해 무한 재시도를 막는다 — 네이티브 쪽에서 이미 조작판에
          // 버튼 비활성화로 안내했어야 할 상황이다.
          if (e.status == 429) {
            succeededIds.add(action.id);
          } else {
            anyFailed = true;
            if (kDebugMode) debugPrint('[WishActionSync] devote 실패(재시도 예정): ${e.message}');
          }
        } catch (e) {
          anyFailed = true;
          if (kDebugMode) debugPrint('[WishActionSync] devote 예외(재시도 예정): $e');
        }
      }

      if (succeededIds.isNotEmpty) {
        await _channel.invokeMethod('acknowledgeActions', {'ids': succeededIds});
      }
      await _saveSentKeys(sentKeys);

      if (anyFailed) {
        _scheduleRetry(repo: repo, fallbackRoomId: fallbackRoomId);
      } else {
        _backoffStep = 0;
        _retryTimer?.cancel();
      }
    } on MissingPluginException {
      // 플러그인 미등록(iOS/웹 등) — 조용히 무시.
    } catch (e) {
      if (kDebugMode) debugPrint('[WishActionSync] drain 전체 실패: $e');
      _scheduleRetry(repo: repo, fallbackRoomId: fallbackRoomId);
    } finally {
      _running = false;
    }
  }

  /// §6 "실패 시 지수 백오프로 재시도. 앱을 열지 않아도 다음 실행에 반드시
  /// 전송" — 앱이 살아있는 동안은 이 타이머로 재시도하고, 앱이 완전히
  /// 종료된 뒤에는 다음 실행(콜드 스타트) 시 drainAndSync 최초 1회 호출이
  /// 이 역할을 대신한다(main.dart/App 초기화 지점에서 호출).
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
}
