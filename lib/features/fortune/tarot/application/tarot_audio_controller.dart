import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [타로 섹션 전면 개편 §11 P5 사운드 시스템]
///
/// 카드 셔플/탭/리빌 임팩트/별가루 차임/저장 완료/UI 탭 6종의 짧은 SFX를
/// 재생하는 컨트롤러. 음소거 여부는 [SharedPreferences]에 저장되어 앱을
/// 다시 열어도 유지된다.
///
/// [겹침 재생 대응] 리빌 임팩트(강한 빛)와 별가루 차임(별가루 폭발)은
/// 시간상 매우 가깝게(약 40ms 간격) 연속 트리거된다. 단일 [AudioPlayer]를
/// 재사용하면 뒤 호출이 앞 재생을 끊어버리므로, 짧은 SFX 전용 플레이어를
/// 여러 개 준비해 순환 사용하는 소형 풀(pool)을 둔다.
///
/// [저사양 degrade 원칙] 사운드는 "있으면 좋고 없어도 무방"한 부가 요소다.
/// 오디오 자산 로드/재생 실패(디코딩 오류, 저사양 기기의 오디오 드라이버
/// 이슈 등)가 앱의 핵심 흐름(카드 뽑기/결과 표시)을 절대 막아서는 안 되므로,
/// 모든 재생 호출은 내부적으로 예외를 삼키고 조용히 무시한다.
class TarotAudioController extends ChangeNotifier {
  static const _mutedKey = 'tarot_audio_muted_v1';
  static const String _base = 'audio/tarot';
  static const int _poolSize = 3;

  final List<AudioPlayer> _pool = List.generate(
    _poolSize,
    (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  );
  int _poolCursor = 0;

  bool _muted = false;
  bool _ready = false;

  bool get muted => _muted;

  /// SharedPreferences에서 음소거 설정을 불러오기 전이면 false.
  /// 음소거 토글 UI가 로딩 중 잠깐 기본값을 보여줄 때 참고할 수 있다.
  bool get ready => _ready;

  TarotAudioController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_mutedKey) ?? false;
    } catch (_) {
      // 저장소 접근 실패 시 기본값(음소거 아님)을 유지한다.
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, _muted);
    } catch (_) {
      // 설정 저장 실패는 무시 - 이번 세션 동안만 음소거 상태가 유지된다.
    }
  }

  Future<void> _play(String assetFileName, {double volume = 0.6}) async {
    if (_muted) return;
    try {
      final player = _pool[_poolCursor];
      _poolCursor = (_poolCursor + 1) % _pool.length;
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('$_base/$assetFileName'));
    } catch (_) {
      // [저사양 degrade] 재생 실패는 조용히 무시 - 앱 동작에 영향 없음.
    }
  }

  /// ⑤ 카드 선택 화면 진입 - 덱 셔플 연출과 함께.
  void playShuffle() => _play('shuffle.mp3', volume: 0.5);

  /// ⑤ 카드 탭(선택) 순간.
  void playCardTap() => _play('card_tap.mp3', volume: 0.7);

  /// ⑥→⑦ 결과화면 리빌 오버레이 "강한 빛" 구간과 동기화되는 임팩트음.
  void playRevealImpact() => _play('reveal_impact.mp3', volume: 0.7);

  /// ⑥→⑦ 별가루 폭발 구간의 맑은 차임벨.
  void playStardustChime() => _play('stardust_chime.mp3', volume: 0.55);

  /// ⑦ "저장하기" 액션 완료 피드백.
  void playSaveConfirm() => _play('save_confirm.mp3', volume: 0.6);

  /// 공용 UI 탭(화면 전환 등) - 미묘한 강조용.
  void playUiTap() => _play('ui_tap.mp3', volume: 0.35);

  @override
  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    super.dispose();
  }
}
