import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §7 항목8 "Sound Effect:
/// 있음(열림·폭발·카운트)" 옵션을 채택해 구현한 SFX 컨트롤러.
///
/// `tarot_audio_controller.dart`와 동일한 원칙을 따른다:
/// - [저사양 degrade 원칙] 사운드는 부가 요소. 재생 실패가 앱의 핵심 흐름
///   (상자 열기/보상 표시)을 절대 막아서는 안 되므로 모든 재생 호출은
///   내부적으로 예외를 삼키고 조용히 무시한다.
/// - 짧은 SFX 전용 [AudioPlayer] 풀을 두어 연속 트리거(예: burst 진입과
///   동시에 카운트업이 겹칠 수 있는 경우)에도 재생이 끊기지 않게 한다.
///
/// [뮤트 없음] 이 기능은 별도의 뮤트 토글 UI 요구사항이 없으므로(§3 화면
/// 명세에 뮤트 버튼이 없음), 시스템/앱 전역 무음 설정을 그대로 따르되
/// 컨트롤러 자체는 항상 재생을 시도한다.
class PouchBoxAudioController {
  PouchBoxAudioController._();
  static final PouchBoxAudioController instance = PouchBoxAudioController._();

  static const String _base = 'audio/pouch_box';
  static const int _poolSize = 2;

  final List<AudioPlayer> _pool = List.generate(
    _poolSize,
    (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  );
  int _poolCursor = 0;

  Future<void> _play(String assetFileName, {double volume = 0.6}) async {
    try {
      final player = _pool[_poolCursor];
      _poolCursor = (_poolCursor + 1) % _pool.length;
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('$_base/$assetFileName'));
    } catch (e) {
      // [저사양 degrade] 재생 실패는 조용히 무시 - 앱 동작에 영향 없음.
      if (kDebugMode) {
        debugPrint('PouchBoxAudioController: play failed ($assetFileName) $e');
      }
    }
  }

  /// opening(1.1s) 상자 흔들림 시작과 함께.
  void playOpenShake() => _play('open_shake.mp3', volume: 0.55);

  /// burst 진입(실제 상자가 터지는 순간) — 잭팟이면 별도 팬페어로 대체.
  void playBurst({required bool isJackpot}) {
    if (isJackpot) {
      _play('jackpot.mp3', volume: 0.75);
    } else {
      _play('burst.mp3', volume: 0.6);
    }
  }

  /// result 화면 진입, 카운트업(900ms) 시작과 함께.
  void playCountUp() => _play('count_up.mp3', volume: 0.5);

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
  }
}
