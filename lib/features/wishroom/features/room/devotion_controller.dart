// §6.1 정성 들이기 — 연출 타임라인 컨트롤러 (웹 MainRoomScreen.devote() 1:1)
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/motion/wr_motion.dart';
import '../../data/models.dart';
import '../../data/wr_api.dart';

enum DevotionPhase { idle, shake, flame, dust, petal, light }

class DevotionController extends ChangeNotifier {
  final WrRepository repo;
  DevotionController(this.repo);

  DevotionPhase phase = DevotionPhase.idle;
  final _timers = <Timer>[];

  // RoomScene 입력값
  double get flameBoost => switch (phase) { DevotionPhase.flame || DevotionPhase.dust => DevotionTimeline.flameBoost, DevotionPhase.idle => 1.0, _ => 1.15 };
  double get lightBoost => switch (phase) { DevotionPhase.light => DevotionTimeline.lightBoost, DevotionPhase.petal => .08, _ => 0 };
  Behavior get behavior => switch (phase) { DevotionPhase.shake || DevotionPhase.flame => Behavior.pray, DevotionPhase.light => Behavior.gaze, _ => Behavior.idle };
  bool get busy => phase != DevotionPhase.idle;

  /// onDust/onPetal: 파티클 필드에 burst/petals 주입 · onDone: 상태 반영 + 레벨업/보너스 처리
  Future<void> devote(String roomId, {
    required VoidCallback onDust, required VoidCallback onPetal,
    required void Function(DevotionResult) onDone, required void Function(ApiError) onError,
  }) async {
    if (busy) return;
    _set(DevotionPhase.shake);
    late DevotionResult res;
    try { res = await repo.devote(roomId); }
    on ApiError catch (e) { _set(DevotionPhase.idle); onError(e); return; } // COOLDOWN(retryAfter) · DAILY_LIMIT
    _at(DevotionTimeline.flame, () => _set(DevotionPhase.flame));
    _at(DevotionTimeline.dust, () { _set(DevotionPhase.dust); onDust(); });
    _at(DevotionTimeline.petal, () { _set(DevotionPhase.petal); onPetal(); });
    _at(DevotionTimeline.light, () => _set(DevotionPhase.light));
    _at(DevotionTimeline.end, () { _set(DevotionPhase.idle); onDone(res); });
  }

  void _at(Duration d, VoidCallback f) => _timers.add(Timer(d, f));
  void _set(DevotionPhase p) { phase = p; notifyListeners(); }
  @override void dispose() { for (final t in _timers) { t.cancel(); } super.dispose(); }
}
