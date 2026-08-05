import 'package:flutter/scheduler.dart';

import 'tarot_perf_config.dart';

/// [타로 섹션 전면 개편 §11 P6] 저사양 기기 자동 감지.
///
/// [TarotPerfConfig]는 이미 "어떤 값을 넘길지"를 결정하는 정책 계층을
/// 갖추고 있었지만(§5-4, 1차 구현은 수동 전환), 실제로 프레임이 얼마나
/// 걸리는지 관측해서 자동으로 tier를 낮추는 로직은 없었다. 이 클래스는
/// 새로운 렌더링 로직을 추가하지 않고, [SchedulerBinding]의 프레임
/// 타이밍 콜백을 관측해 `TarotPerfConfig.setTier()`를 호출하는 얇은
/// 관측 계층이다.
///
/// [설계 원칙]
/// - 다운그레이드만 자동으로 수행한다(업그레이드는 하지 않음). 프레임이
///   순간적으로 좋아졌다고 화려한 연출을 다시 켜면 사용자가 "왜 갑자기
///   화려해졌다 수수해졌다 하지?"라고 느낄 수 있어, 한 세션 안에서는
///   한 번 낮아진 단계를 유지하는 편이 더 안정적인 체감을 준다.
/// - 타로 화면이 실제로 열려 있을 때만 관측한다(`start()`/`stop()`으로
///   구간을 명시) - 앱 전역에서 상시 수집하면 타로와 무관한 다른 화면의
///   지연(네트워크 대기 등)까지 오염되어 판단이 부정확해진다.
/// - 워밍업 구간(첫 `_warmupFrames`장)은 판단에서 제외한다 - 화면 진입
///   직후의 셰이더 컴파일/레이아웃 계산 등 일시적 지연을 저사양으로
///   오판하지 않기 위함이다.
class TarotPerfMonitor {
  TarotPerfMonitor._();

  static const int _warmupFrames = 20;
  static const int _windowSize = 60;
  // 30fps(33.3ms/frame) 밑으로 지속되면 medium, 20fps(50ms/frame) 밑으로
  // 지속되면 low로 다운그레이드한다.
  static const Duration _mediumThreshold = Duration(milliseconds: 33);
  static const Duration _lowThreshold = Duration(milliseconds: 50);

  static bool _active = false;
  static int _frameCount = 0;
  static final List<Duration> _window = [];

  // [참조 카운트] 타로 화면들은 [TarotThemeScope]를 통해 각자
  // enter()/exit()를 호출한다. 네비게이션 스택에는 여러 타로 화면이
  // 동시에 마운트되어 있을 수 있으므로(카테고리 상세 위에 카드선택을
  // push하는 등), 단순 bool 플래그 대신 카운터로 "마지막 화면이 나갈
  // 때"만 실제로 관측을 멈춘다.
  static int _refCount = 0;

  static bool get isActive => _active;

  /// 타로 화면 진입(`initState`) 시 호출. 이미 다른 타로 화면이 열려
  /// 있어 관측 중이면 카운터만 올리고 아무 것도 하지 않는다.
  static void enter() {
    _refCount++;
    if (_active) return;
    _active = true;
    _frameCount = 0;
    _window.clear();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// 타로 화면 이탈(`dispose`) 시 호출. 마지막 타로 화면까지 모두
  /// 닫히면(카운터 0) 리스너를 해제해 불필요한 관측을 멈춘다.
  static void exit() {
    if (_refCount > 0) _refCount--;
    if (_refCount > 0) return;
    _stopListening();
  }

  static void _stopListening() {
    if (!_active) return;
    _active = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameCount++;
      if (_frameCount <= _warmupFrames) continue;

      final totalSpan = timing.totalSpan;
      _window.add(totalSpan);
      if (_window.length > _windowSize) {
        _window.removeAt(0);
      }
      if (_window.length < _windowSize) continue;

      _evaluateWindow();
    }
  }

  static void _evaluateWindow() {
    // 이미 최저 단계면 더 낮출 곳이 없으니 관측을 계속할 필요가 없다.
    if (TarotPerfConfig.tier == TarotVisualTier.low) {
      _stopListening();
      return;
    }

    final avgMicros =
        _window.fold<int>(0, (sum, d) => sum + d.inMicroseconds) /
        _window.length;
    final avg = Duration(microseconds: avgMicros.round());

    if (avg >= _lowThreshold) {
      TarotPerfConfig.setTier(TarotVisualTier.low);
      _stopListening();
    } else if (avg >= _mediumThreshold &&
        TarotPerfConfig.tier == TarotVisualTier.high) {
      TarotPerfConfig.setTier(TarotVisualTier.medium);
      // medium으로 낮춘 뒤에도 계속 무거우면 low까지 낮출 수 있도록
      // 관측은 유지한다(윈도우만 초기화해 다음 판단을 새로 시작).
      _window.clear();
    }
  }
}
