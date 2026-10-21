import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sound_config.dart';

/// [신통방통 사운드 배치 개발 기획서 v1.0 — 2026-10-21 / shindang_DEV_HANDOVER]
/// 앱 전역에서 사용하는 단일 사운드 서비스. BGM 크로스페이드, 앰비언스,
/// 전환 표식음, 덕킹, UI SFX 재생을 모두 이 클래스 하나가 담당한다.
///
/// 설계 원칙(기획서 §0-§9 전반):
/// - 설정은 `assets/config/sound_routes.json`에서만 읽는다(하드코딩 금지).
/// - BGM 전환은 반드시 등파워(코사인/사인) 크로스페이드 2.2초(§6.1).
///   `outgoing.gain = cos(tπ/2)`, `incoming.gain = sin(tπ/2)` — 선형
///   페이드(`1-t`)는 중간에서 에너지가 꺼졌다 켜지는 것처럼 들려 금지.
/// - 같은 메뉴 재진입 시 BGM을 처음부터 다시 시작하지 않는다(§6.3).
/// - 전환 중 연타는 큐에 쌓지 않고 진행 중인 페이드를 즉시 취소, 새
///   목적지로 재계산한다(§6.3).
/// - 백그라운드 전환 시 즉시 정지, 복귀 시 페이드인(§8.3).
/// - [저사양 degrade 원칙 — TarotAudioController와 동일] 사운드는 "있으면
///   좋고 없어도 무방"한 부가 요소다. 자산 로드/재생 실패가 앱의 핵심
///   흐름을 절대 막아서는 안 되므로 모든 재생 호출은 예외를 삼킨다.
class SintongSoundService extends ChangeNotifier with WidgetsBindingObserver {
  static const _mutedKey = 'sintong_sound_muted_v1';
  static const _bgmBase = 'audio/bgm';
  static const _ambBase = 'audio/ambience';
  static const _sfxBase = 'audio/sfx';

  SoundConfig? _config;
  bool _muted = false;
  bool _ready = false;
  String? _currentRouteKey;
  // [콜드 스타트 경쟁 조건 수정 — 2026-11] `init()`은 비동기(에셋/설정
  // 로드)라 끝나기 전에 첫 화면(main)의 SoundRouteTrigger가
  // `playRoute('main')`을 호출하면 `_ready==false`라 조용히 무시되고,
  // `_currentRouteKey`만 'main'으로 기록된 채 끝났다. 이후 init()이 끝나도
  // "이미 current니까 재진입 금지"로 착각해 실제 BGM 재생이 영원히 한 번도
  // 일어나지 않는 경우가 있었다(최초 진입 BGM 무음 버그 후보). 이 플래그는
  // "_currentRouteKey가 실제로 오디오에 적용됐는지"를 별도로 추적한다.
  bool _routeApplied = false;

  // ── BGM: 두 개의 플레이어를 교대로 써서 크로스페이드를 구현한다 ──
  AudioPlayer? _bgmA;
  AudioPlayer? _bgmB;
  bool _usingA = true; // 현재 "전경(foreground)" 트랙이 A인지 B인지
  Timer? _crossfadeTimer;
  int _crossfadeToken = 0; // 전환 중 연타 시 기존 타이머를 무효화하기 위한 토큰

  // [크로스페이드 "팝(pop)" 버그 수정 — 2026-11, 대표님 피드백 "자연스럽게
  // 음악이 전환되어야 하는데"] 각 물리 플레이어(A/B)에 마지막으로 실제
  // 적용한 선형 볼륨을 추적한다. 2.2초 크로스페이드가 끝나기 전에 또
  // 다른 메뉴로 전환되면(연타/빠른 네비게이션), 기존 코드는 "outgoing"
  // 트랙이 이미 중간 볼륨(예: 0.45)에 머물러 있는데도 새 크로스페이드가
  // `cos(0)=1.0`(최대 볼륨)에서 다시 시작한다고 가정해 버렸다 — 그 결과
  // 트랙 볼륨이 순간적으로 확 튀었다가(pop) 다시 줄어드는 것처럼 들렸다.
  // 이 두 필드는 그 "진짜 현재 볼륨"을 기억해, 새 크로스페이드가 항상
  // 실제 볼륨에서 이어서 시작하도록(연속성 보장) 한다.
  double _volA = 0.0;
  double _volB = 0.0;

  // ── 앰비언스: 단일 루프 플레이어 ──
  AudioPlayer? _ambPlayer;
  String? _currentAmbFile;
  double _ambBaseVolume = 0.0; // 현재 라우트의 목표 앰비언스 볼륨(덕킹 적용 전)

  // ── 전환 표식음: 전용 1채널 ──
  AudioPlayer? _markerPlayer;

  // ── SFX: 고정 채널 풀 + 탭 전용 1채널(동시 재생 제한 §7.3) ──
  final List<AudioPlayer> _sfxPool = [];
  int _sfxCursor = 0;
  AudioPlayer? _tapPlayer; // 01/02/03/04(tap류) 전용 — 새 탭 시 이전 탭 즉시 컷
  final Map<String, DateTime> _lastTriggerAt = {};
  final List<_ActiveVoice> _activeVoices = [];

  // ── 덕킹 상태 ──
  double _bgmDuckDb = 0.0;
  double _ambDuckDb = 0.0;
  Timer? _duckTimer;
  int _duckToken = 0;

  double _bgmBaseVolume = 1.0;

  bool get muted => _muted;
  bool get ready => _ready;
  String? get currentRouteKey => _currentRouteKey;
  bool get hasConfig => _config != null;

  /// 각 SFX 파일의 재생 길이(기획서 §4.3 표 그대로) — 동시 발음 수 제한(§7.3)
  /// 판정에 쓴다. 실제 디코딩 duration을 매번 조회하지 않고 고정값을 쓰는
  /// 이유는 "채널 풀 객체 재사용"과 마찬가지로 지연을 만들지 않기 위함이다.
  static const Map<String, Duration> _sfxDurations = {
    '01_tap': Duration(milliseconds: 120),
    '02_tap_soft': Duration(milliseconds: 110),
    '03_tap_primary': Duration(milliseconds: 200),
    '04_tab': Duration(milliseconds: 160),
    '05_toggle_on': Duration(milliseconds: 240),
    '06_toggle_off': Duration(milliseconds: 220),
    '07_page_in': Duration(milliseconds: 420),
    '08_page_back': Duration(milliseconds: 380),
    '09_menu_open': Duration(milliseconds: 220),
    '10_card_flip': Duration(milliseconds: 140),
    '11_success': Duration(milliseconds: 850),
    '12_error': Duration(milliseconds: 500),
    '13_notify': Duration(milliseconds: 1100),
    '14_reward': Duration(milliseconds: 1050),
    '15_coin': Duration(milliseconds: 360),
    '16_wish_submit': Duration(milliseconds: 1300),
    '17_loading_done': Duration(milliseconds: 600),
  };

  /// "탭류"로 분류되어 전용 1채널을 쓰는 이벤트(§7.3 "탭 소리는 채널 1개
  /// 전용으로 쓰고, 새 탭이 오면 이전 탭을 즉시 컷한다").
  static const Set<String> _tapFamily = {
    '01_tap',
    '02_tap_soft',
    '03_tap_primary',
    '04_tab',
  };

  Future<void> init() async {
    if (_ready) return;
    try {
      _config = await SoundConfig.load();
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_mutedKey) ?? false;
    } catch (_) {
      // [저사양 degrade] 설정 로드 실패 시 사운드 기능을 조용히 비활성화.
      _config = null;
    }
    if (_config != null) {
      try {
        _bgmA = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
        _bgmB = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
        _ambPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
        _markerPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        _tapPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        final poolSize = math.max(1, _config!.limits.channelPoolSize - 1);
        _sfxPool.addAll(
          List.generate(
            poolSize,
            (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
          ),
        );
        WidgetsBinding.instance.addObserver(this);
      } catch (_) {
        // 플레이어 초기화 실패 — 이후 모든 재생 호출은 _config null 체크와
        // 무관하게 각 메서드 내부 try/catch로 보호되므로 앱 동작에 영향 없다.
      }
    }
    _ready = true;
    // [콜드 스타트 경쟁 조건 수정] init() 완료 시점에 이미 "현재 라우트"가
    // 기록돼 있지만 아직 오디오에 반영되지 않았다면(= init()보다
    // playRoute()가 먼저 호출된 경우), 지금 그 라우트를 뒤늦게라도
    // 적용한다. 재진입 금지 로직과 충돌하지 않도록 _currentRouteKey를
    // 잠시 비웠다가 playRoute()로 다시 설정하는 방식을 쓴다.
    if (!_routeApplied && _currentRouteKey != null && !_muted) {
      final pending = _currentRouteKey!;
      _currentRouteKey = null;
      unawaited(playRoute(pending));
    }
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────
  // 음소거
  // ──────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    _muted = !_muted;
    notifyListeners();
    if (_muted) {
      await _bgmA?.pause();
      await _bgmB?.pause();
      await _ambPlayer?.pause();
    } else if (_currentRouteKey != null) {
      if (_routeApplied) {
        // 음소거 전에 이미 재생 중이던 트랙이 있다 — 그냥 재개.
        await _resumeForegroundAfterUnmute();
      } else {
        // [콜드 스타트/음소거 경쟁 조건] 처음부터 음소거 상태로 앱을
        // 열었거나, 아직 한 번도 실제로 재생되지 못한 라우트라면
        // resume()할 대상 자체가 없다 — playRoute로 새로 시작해야 한다.
        final pending = _currentRouteKey!;
        _currentRouteKey = null;
        await playRoute(pending);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, _muted);
    } catch (_) {}
  }

  Future<void> _resumeForegroundAfterUnmute() async {
    try {
      final fg = _usingA ? _bgmA : _bgmB;
      await fg?.resume();
      if (_currentAmbFile != null) {
        await _ambPlayer?.resume();
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────
  // dB ↔ 선형 볼륨 변환 (audioplayers volume은 0.0~1.0 선형)
  // ──────────────────────────────────────────────────────────────

  static double _dbToLinear(double db) => math.pow(10, db / 20).toDouble();

  // ──────────────────────────────────────────────────────────────
  // BGM · 앰비언스 라우팅 (§5, §6, §9.2 routes)
  // ──────────────────────────────────────────────────────────────

  /// 화면 진입 시 호출한다. [routeKey]는 `sound_routes.json`의 routes 키
  /// (main/saju/guide/tarot/wish/face/palm/shrine) 중 하나.
  ///
  /// 같은 라우트로 재호출되면(§6.3 "같은 메뉴 재진입 시 재시작 금지")
  /// 아무 것도 하지 않는다. 다른 라우트로 전환 중 다시 호출되면(§6.3
  /// "전환 중 연타") 기존 크로스페이드를 즉시 취소하고 새 목적지로
  /// 재계산한다.
  Future<void> playRoute(String routeKey) async {
    if (!_ready || _config == null || _muted) {
      _currentRouteKey = routeKey; // 설정이 없어도 "현재 화면" 자체는 추적
      _routeApplied = false; // 아직 오디오에 반영되지 않음 — init()/언뮤트 후 재시도 대상
      return;
    }
    if (_currentRouteKey == routeKey && _routeApplied) return; // 재진입 — 재시작 금지

    final route = _config!.routes[routeKey];
    if (route == null) {
      _currentRouteKey = routeKey;
      return;
    }
    _currentRouteKey = routeKey;
    _routeApplied = true;

    // 전환 표식음(§6.2) — 터치 +0.3초 지점, 1.6초 재생 분량이지만 2.2초
    // 크로스페이드 안에 완전히 담긴다.
    unawaited(_playMarkerDelayed());

    unawaited(_crossfadeBgmTo('$_bgmBase/${route.bgm}.mp3'));
    unawaited(_switchAmbienceTo(route));
  }

  Future<void> _playMarkerDelayed() async {
    final marker = _config?.marker;
    if (marker == null) return;
    try {
      await Future<void>.delayed(
        Duration(milliseconds: (marker.atSeconds * 1000).round()),
      );
      if (_muted) return;
      await _markerPlayer?.setVolume(_dbToLinear(marker.gainDb));
      // [v1.2 핸드오버, 2026-10-21] 누락됐던 `18_transition_bell.mp3`가
      // 추가 납품되어 이제 8개 메뉴 전환 모두 이 전환 표식음이 재생된다
      // (터치 +0.3초, -24dB, 1.6초 — 2.2초 크로스페이드 안에 완전히 담김).
      await _markerPlayer?.play(AssetSource('$_sfxBase/${marker.file}.mp3'));
    } catch (_) {
      // 파일 부재/디코딩 실패 — 조용히 무시 (크로스페이드 자체에는 영향 없음).
    }
  }

  Future<void> _crossfadeBgmTo(String assetPath) async {
    final cfg = _config;
    if (cfg == null) return;
    final token = ++_crossfadeToken; // 새 호출이 들어오면 이전 타이머 무효화
    _crossfadeTimer?.cancel();

    // [중요] 토글 전에 현재 포그라운드가 A인지 먼저 캡처해 둔다 — 아래서
    // outgoing/incoming 각각의 "실제 현재 볼륨"을 조회할 때 어느 쪽이
    // 어느 트랙인지 구분하기 위해 필요하다.
    final outgoingWasA = _usingA;
    final outgoing = outgoingWasA ? _bgmA : _bgmB;
    final incoming = outgoingWasA ? _bgmB : _bgmA;
    _usingA = !_usingA;

    // [크로스페이드 "팝" 버그 수정] outgoing 트랙이 "지금 실제로 얼마나
    // 크게 들리고 있는지"를 가져온다. 전환 중 연타가 없는 일반적인
    // 경우라면 이 값은 이미 목표 게인(=effectiveBgmGain, cos(0)=1과 동일)
    // 이므로 기존 동작과 완전히 동일하게 들린다. 하지만 이전 크로스페이드가
    // 중간에 취소되고 재호출된 경우(예: 0.7배 음량으로 아직 페이드 중)에는
    // 이 값이 목표보다 작은 중간값이라, 아래 식이 "그 지점에서 이어서"
    // 자연스럽게 0으로 내려가도록 보장한다 — 더 이상 순간적으로
    // 커졌다가(pop) 줄어드는 일이 없다.
    final startOutVol = outgoingWasA ? _volA : _volB;

    try {
      await incoming?.setVolume(0.0);
      if (outgoingWasA) {
        _volB = 0.0;
      } else {
        _volA = 0.0;
      }
      await incoming?.play(AssetSource(assetPath));
    } catch (_) {
      return; // [저사양 degrade] 재생 실패 시 크로스페이드를 시도하지 않는다.
    }

    final xf = cfg.crossfadeSeconds;
    const tickMs = 33; // ~30fps면 귀로 끊김을 느끼지 못하는 충분한 해상도
    final totalTicks = math.max(1, (xf * 1000 / tickMs).round());
    var tick = 0;

    _crossfadeTimer = Timer.periodic(
      const Duration(milliseconds: tickMs),
      (timer) async {
        if (token != _crossfadeToken) {
          timer.cancel(); // 전환 중 연타로 무효화됨 — 이 타이머는 더 이상 유효하지 않다.
          return;
        }
        tick++;
        final t = math.min(1.0, tick / totalTicks);
        final targetGain = _effectiveBgmGain();
        // [등파워 크로스페이드 — §6.1 유지, 단 outgoing은 연속성 보정]
        // incoming은 항상 0에서 시작하므로 기존 sin(tπ/2) 그대로.
        // outgoing은 "목표 게인에서부터"가 아니라 "현재 실제 볼륨에서부터"
        // cos 곡선을 그려 t=1에 정확히 0으로 수렴시킨다(선형 페이드
        // 금지 원칙은 유지 — 여전히 코사인 곡률로 감쇠한다).
        final outGain = startOutVol * math.cos(t * math.pi / 2);
        final inGain = math.sin(t * math.pi / 2) * targetGain;
        try {
          await outgoing?.setVolume(outGain.clamp(0.0, 1.0));
          await incoming?.setVolume(inGain.clamp(0.0, 1.0));
          if (outgoingWasA) {
            _volA = outGain.clamp(0.0, 1.0);
            _volB = inGain.clamp(0.0, 1.0);
          } else {
            _volB = outGain.clamp(0.0, 1.0);
            _volA = inGain.clamp(0.0, 1.0);
          }
        } catch (_) {}
        if (t >= 1.0) {
          timer.cancel();
          try {
            await outgoing?.stop(); // §6.4 "이전 트랙 정지·해제"
          } catch (_) {}
        }
      },
    );
  }

  double _effectiveBgmGain() => _bgmBaseVolume * _dbToLinear(_bgmDuckDb);

  Future<void> _switchAmbienceTo(SoundRoute route) async {
    try {
      if (route.amb == null) {
        _currentAmbFile = null;
        _ambBaseVolume = 0.0;
        await _ambPlayer?.stop();
        return;
      }
      if (_currentAmbFile == route.amb) return; // 동일 앰비언스 유지
      _currentAmbFile = route.amb;
      _ambBaseVolume = _dbToLinear(route.ambGainDb ?? -20);
      await _ambPlayer?.setVolume(_effectiveAmbGain());
      await _ambPlayer?.play(AssetSource('$_ambBase/${route.amb}.mp3'));
    } catch (_) {}
  }

  double _effectiveAmbGain() => _ambBaseVolume * _dbToLinear(_ambDuckDb);

  // ──────────────────────────────────────────────────────────────
  // 덕킹 (§7.1) — "무엇이 주인공인지 정하는 것"
  // ──────────────────────────────────────────────────────────────

  /// 결과 공개(reveal)/보상(reward)처럼 "한 순간 줄였다가 스스로 복귀하는"
  /// 일회성 덕킹. 호출만 하면 attack 시간 동안 줄고, release 시간 동안
  /// 저절로 되돌아온다 — 결과 화면 코드는 공개 애니메이션 시작 시 이
  /// 한 줄만 호출하면 된다.
  ///
  /// [REQ — 신통방통 사운드 배치 기획서 §5.2 핵심 원칙] "결과 공개 순간"의
  /// 1.2~1.5초 무음은 이 앱에서 가장 중요한 사운드 설계다 — 14_reward가
  /// 훨씬 크게 느껴지도록 음악을 비켜준다.
  Future<void> duckMomentary(String profileKey) async {
    final profile = _config?.duck[profileKey];
    if (profile == null || _muted) return;
    final token = ++_duckToken;
    _duckTimer?.cancel();
    await _rampDuck(profile.bgmDb, profile.ambDb, profile.attackMs, token);
    if (token != _duckToken) return;
    await Future<void>.delayed(Duration.zero);
    _duckTimer = Timer(Duration(milliseconds: profile.attackMs), () async {
      if (token != _duckToken) return;
      await _rampDuck(0, 0, profile.releaseMs, token);
    });
  }

  /// 안내 보이스처럼 "시작~끝"이 명확한 이벤트용 지속 덕킹. 보이스 재생
  /// 시작 시 [duckVoiceStart], 종료 시 [duckVoiceEnd]를 짝으로 호출한다.
  /// (기획서 §11.2 — 안내 보이스는 현재 미도입이라 호출부가 아직 없지만,
  /// 향후 추가될 때 바로 쓸 수 있도록 API만 준비해 둔다.)
  Future<void> duckVoiceStart() async {
    final profile = _config?.duck['voice'];
    if (profile == null || _muted) return;
    final token = ++_duckToken;
    await _rampDuck(profile.bgmDb, profile.ambDb, profile.attackMs, token);
  }

  Future<void> duckVoiceEnd() async {
    final profile = _config?.duck['voice'];
    if (profile == null) return;
    final token = ++_duckToken;
    await _rampDuck(0, 0, profile.releaseMs, token);
  }

  Future<void> _rampDuck(
    double targetBgmDb,
    double targetAmbDb,
    int durationMs,
    int token,
  ) async {
    final startBgm = _bgmDuckDb;
    final startAmb = _ambDuckDb;
    const tickMs = 20;
    final totalTicks = math.max(1, (durationMs / tickMs).round());
    final completer = Completer<void>();
    var tick = 0;
    Timer.periodic(const Duration(milliseconds: tickMs), (timer) async {
      if (token != _duckToken) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      tick++;
      final t = math.min(1.0, tick / totalTicks);
      _bgmDuckDb = startBgm + (targetBgmDb - startBgm) * t;
      _ambDuckDb = startAmb + (targetAmbDb - startAmb) * t;
      try {
        final fg = _usingA ? _bgmA : _bgmB;
        final fgVol = _effectiveBgmGain().clamp(0.0, 1.0);
        await fg?.setVolume(fgVol);
        // [크로스페이드 연속성 유지] 덕킹도 실제 재생 볼륨을 바꾸므로,
        // 다음 번 playRoute() 호출이 "진짜 현재 볼륨"에서 이어받을 수
        // 있도록 _volA/_volB를 함께 갱신한다 — 안 하면 덕킹 중 화면을
        // 전환했을 때 크로스페이드가 다시 팝(pop) 튀는 문제가 재발한다.
        if (_usingA) {
          _volA = fgVol;
        } else {
          _volB = fgVol;
        }
        if (_currentAmbFile != null) {
          await _ambPlayer?.setVolume(_effectiveAmbGain().clamp(0.0, 1.0));
        }
      } catch (_) {}
      if (t >= 1.0) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  // ──────────────────────────────────────────────────────────────
  // UI SFX (§4.3, §7.3, §8)
  // ──────────────────────────────────────────────────────────────

  /// 이벤트 ID → 파일명(확장자 제외) 매핑(§8.1/§8.2 그대로).
  static const Map<String, String> _eventToFile = {
    'btn.tap': '01_tap',
    'list.item.tap': '02_tap_soft',
    'cta.primary': '03_tap_primary',
    'tab.switch': '04_tab',
    'toggle.on': '05_toggle_on',
    'toggle.off': '06_toggle_off',
    'nav.push': '07_page_in',
    'nav.pop': '08_page_back',
    'drawer.open': '09_menu_open',
    'tarot.card.flip': '10_card_flip',
    'request.success': '11_success',
    'request.error': '12_error',
    'push.received': '13_notify',
    'reward.reveal': '14_reward',
    'point.earn': '15_coin',
    'wish.submit': '16_wish_submit',
    'load.complete': '17_loading_done',
  };

  /// 레벨 표(§4.3 RMS 열 근사치, dB).
  static const Map<String, double> _fileGainDb = {
    '01_tap': -22.0,
    '02_tap_soft': -22.7,
    '03_tap_primary': -22.1,
    '04_tab': -22.0,
    '05_toggle_on': -22.0,
    '06_toggle_off': -22.0,
    '07_page_in': -22.0,
    '08_page_back': -22.0,
    '09_menu_open': -22.7,
    '10_card_flip': -22.0,
    '11_success': -22.0,
    '12_error': -22.0,
    '13_notify': -22.0,
    '14_reward': -22.0,
    '15_coin': -22.0,
    '16_wish_submit': -22.0,
    '17_loading_done': -23.8,
  };

  /// 이벤트 ID(§8.1/§8.2 표의 ID)로 SFX를 재생한다. 화면별 호출부는 이
  /// 메서드 하나만 알면 된다 — 파일명은 내부 매핑이 담당한다.
  Future<void> playEvent(String eventId) async {
    final file = _eventToFile[eventId];
    if (file == null) return;
    await _playSfxFile(file);
  }

  Future<void> _playSfxFile(String fileBaseName) async {
    if (!_ready || _config == null || _muted) return;
    final limits = _config!.limits;

    // §7.3 "동일 파일 재호출 간격 80ms 미만이면 무시한다(연타 방지)."
    final now = DateTime.now();
    final last = _lastTriggerAt[fileBaseName];
    if (last != null &&
        now.difference(last).inMilliseconds < limits.minRetriggerMs) {
      return;
    }
    _lastTriggerAt[fileBaseName] = now;

    // 자연 종료된 보이스를 목록에서 정리한다.
    _activeVoices.removeWhere((v) => now.isAfter(v.endsAt));

    // §7.3 "동시 발음 수 상한 4개. 초과 시 가장 오래된 소리를 30ms
    // 페이드아웃 후 해제."
    if (_activeVoices.length >= limits.maxVoices) {
      final oldest = _activeVoices.removeAt(0);
      unawaited(_fadeOutAndStop(oldest.player, const Duration(milliseconds: 30)));
    }

    try {
      final gainDb = _fileGainDb[fileBaseName] ?? -22.0;
      final isTap = _tapFamily.contains(fileBaseName);
      final player = isTap ? _tapPlayer : _sfxPool[_sfxCursor];
      if (!isTap) {
        _sfxCursor = (_sfxCursor + 1) % math.max(1, _sfxPool.length);
      } else {
        // §7.3 "탭 소리는 채널 1개 전용으로 쓰고, 새 탭이 오면 이전 탭을
        // 즉시 컷한다(겹침 자체를 막는다)."
        await _tapPlayer?.stop();
      }
      if (player == null) return;
      await player.setVolume(_dbToLinear(gainDb).clamp(0.0, 1.0));
      await player.play(AssetSource('$_sfxBase/$fileBaseName.mp3'));
      final duration = _sfxDurations[fileBaseName] ?? const Duration(milliseconds: 500);
      _activeVoices.add(_ActiveVoice(player, now.add(duration)));
    } catch (_) {
      // [저사양 degrade] 조용히 무시.
    }
  }

  Future<void> _fadeOutAndStop(AudioPlayer player, Duration duration) async {
    const steps = 3;
    final stepMs = duration.inMilliseconds ~/ steps;
    try {
      for (var i = steps - 1; i >= 0; i--) {
        await player.setVolume(i / steps);
        await Future<void>.delayed(Duration(milliseconds: stepMs));
      }
      await player.stop();
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────
  // 앱 라이프사이클 (§8.3 "백그라운드로 갈 때 즉시 정지, 복귀 시 페이드인")
  // ──────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _pauseForBackground();
        break;
      case AppLifecycleState.resumed:
        _fadeInOnResume();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _pauseForBackground() async {
    try {
      await _bgmA?.pause();
      await _bgmB?.pause();
      await _ambPlayer?.pause();
    } catch (_) {}
  }

  Future<void> _fadeInOnResume() async {
    if (_muted || _currentRouteKey == null) return;
    try {
      final fg = _usingA ? _bgmA : _bgmB;
      await fg?.resume();
      if (_currentAmbFile != null) {
        await _ambPlayer?.resume();
      }
      // 복귀 시 0→목표 볼륨으로 짧게 페이드인(기획서 §8.3 요건의 취지 반영).
      const fadeMs = 500;
      const tickMs = 25;
      final totalTicks = fadeMs ~/ tickMs;
      for (var i = 1; i <= totalTicks; i++) {
        final t = i / totalTicks;
        final fgVol = (_effectiveBgmGain() * t).clamp(0.0, 1.0);
        await fg?.setVolume(fgVol);
        // [크로스페이드 연속성 유지] 백그라운드 복귀 페이드인도 실제
        // 볼륨을 바꾸므로 _volA/_volB를 동기화한다(위 덕킹과 동일 이유).
        if (_usingA) {
          _volA = fgVol;
        } else {
          _volB = fgVol;
        }
        if (_currentAmbFile != null) {
          await _ambPlayer?.setVolume((_effectiveAmbGain() * t).clamp(0.0, 1.0));
        }
        await Future<void>.delayed(const Duration(milliseconds: tickMs));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _crossfadeTimer?.cancel();
    _duckTimer?.cancel();
    _bgmA?.dispose();
    _bgmB?.dispose();
    _ambPlayer?.dispose();
    _markerPlayer?.dispose();
    _tapPlayer?.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
    super.dispose();
  }
}

class _ActiveVoice {
  _ActiveVoice(this.player, this.endsAt);
  final AudioPlayer player;
  final DateTime endsAt;
}
