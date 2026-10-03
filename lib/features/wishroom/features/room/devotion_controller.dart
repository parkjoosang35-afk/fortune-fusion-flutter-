// §6.1 정성 들이기 — 연출 타임라인 컨트롤러 (docs/screens/A_인트로_작성_메인.md
// `devote()` 타임라인 표 0.0~2.9초 1:1, 웹 MainRoomScreen.devote() 포팅).
//
// 호출부(MainRoomScreen._onDevote)는 각 단계 콜백 안에서 setState()를 호출해\
// RoomScene(boost/shake)와 오버레이 FX를 함께 다시 그린다 — 그래서 이 컨트롤러는
// ChangeNotifier 리스너에 의존하지 않고도(=addListener 없이도) 매 단계가 즉시
// 화면에 반영된다(phase 변경 → 콜백 호출 → 콜백의 setState 순서가 보장되므로).
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/motion/wr_motion.dart';
import '../../data/models.dart';
import '../../data/wr_api.dart';

enum DevotionPhase { idle, shake, boost1, burst2, petal, boost2, quote }

class DevotionController extends ChangeNotifier {
  final WrRepository repo;
  DevotionController(this.repo);

  DevotionPhase phase = DevotionPhase.idle;
  final _timers = <Timer>[];

  /// RoomScene.boost 입력(0·1·2) — t0.3(boost1)부터 1, t1.7(boost2)부터 2.
  double get roomBoost => switch (phase) {
        DevotionPhase.boost1 || DevotionPhase.burst2 || DevotionPhase.petal => 1,
        DevotionPhase.boost2 || DevotionPhase.quote => 2,
        _ => 0,
      };
  /// RoomScene.shake — t0.0 순간에만 true(shakeCtrl이 420ms 1회 재생).
  bool get shaking => phase == DevotionPhase.shake;
  bool get busy => phase != DevotionPhase.idle;

  /// onShakeBurst(t0.0): 화면 shake+금빛 wash+촛불 링3개+금빛버스트26+꽃잎버스트10.
  /// onItemBurst(t0.7, gain): 버스트18+빛나선26+`+1 {verb}` · gain!=null이면 기운 보너스 pill+칩.
  /// onPetalButterfly(t1.1): 꽃잎22+나비4.
  /// onWashDone(t1.7): boost2+화면 wash2s+`RITUAL.done` 캡션.
  /// onQuote(t2.3): 말씀 카드(RITUAL.quotes 랜덤 1개).
  /// onDone(t2.9): 연출 끝 — 레벨업 오버레이 또는 보상 시트.
  Future<void> devote(String roomId, {
    required VoidCallback onShakeBurst,
    required void Function(DevotionGain? gain) onItemBurst,
    required VoidCallback onPetalButterfly,
    required VoidCallback onWashDone,
    required VoidCallback onQuote,
    required void Function(DevotionResult) onDone,
    required void Function(ApiError) onError,
  }) async {
    if (busy) return;
    _set(DevotionPhase.shake);
    onShakeBurst();
    late DevotionResult res;
    try {
      res = await repo.devote(roomId);
    } on ApiError catch (e) {
      _set(DevotionPhase.idle);
      onError(e);
      return;
    }
    _at(DevotionTimeline.boost1, () => _set(DevotionPhase.boost1));
    _at(DevotionTimeline.burst2, () { _set(DevotionPhase.burst2); onItemBurst(res.gain); });
    _at(DevotionTimeline.petal, () { _set(DevotionPhase.petal); onPetalButterfly(); });
    _at(DevotionTimeline.boost2, () { _set(DevotionPhase.boost2); onWashDone(); });
    _at(DevotionTimeline.quote, () { _set(DevotionPhase.quote); onQuote(); });
    _at(DevotionTimeline.end, () { _set(DevotionPhase.idle); onDone(res); });
  }

  void _at(Duration d, VoidCallback f) => _timers.add(Timer(d, f));
  void _set(DevotionPhase p) { phase = p; notifyListeners(); }
  @override void dispose() { for (final t in _timers) { t.cancel(); } super.dispose(); }
}
