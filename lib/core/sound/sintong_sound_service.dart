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

  // ── BGM: 두 개의 플레이어를 교대로 써서 크로스페이드를 구현한다 ──
  AudioPlayer? _bgmA;
  AudioPlayer? _bgmB;
  bool _usingA = true; // 현재 "전경(foreground)" 트랙이 A인지 B인지
  Timer? _crossfadeTimer;
  int _crossfadeToken = 0; // 전환 중 연타 시 기존 타이머를 무효화하기 위한 토큰

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
      await _resumeForegroundAfterUnmute();
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
      return;
    }
    if (_currentRouteKey == routeKey) return; // 재진입 — 재시작 금지

    final route = _config!.routes[routeKey];
    if (route == null) {
      _currentRouteKey = routeKey;
      return;
    }
    _currentRouteKey = routeKey;

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
      // [납품본 안내] 기획서 §9.2는 `transition_bell`을 참조하지만, 2026-10-21
      // 핸드오버 패키지(28종)에는 이 파일이 포함되어 있지 않다. 자산이 없으면
      // AssetSource 로드가 실패해 아래 play() 호출이 예외를 던지는데, 이는
      // try/catch로 조용히 무시된다 — 즉 마커 파일이 추가되기 전까지는
      // 전환 표식음 없이 크로스페이드만 들린다(§8 완료 보고에 명시).
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

    final outgoing = _usingA ? _bgmA : _bgmB;
    final incoming = _usingA ? _bgmB : _bgmA;
    _usingA = !_usingA;

    try {
      await incoming?.setVolume(0.0);
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
        // [등파워 크로스페이드 — §6.1 그대로] 선형(1-t) 절대 금지.
        final outGain = math.cos(t * math.pi / 2) * _effectiveBgmGain();
        final inGain = math.sin(t * math.pi / 2) * _effectiveBgmGain();
        try {
          await outgoing?.setVolume(outGain.clamp(0.0, 1.0));
          await incoming?.setVolume(inGain.clamp(0.0, 1.0));
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
        await fg?.setVolume(_effectiveBgmGain().clamp(0.0, 1.0));
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
        await fg?.setVolume((_effectiveBgmGain() * t).clamp(0.0, 1.0));
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
