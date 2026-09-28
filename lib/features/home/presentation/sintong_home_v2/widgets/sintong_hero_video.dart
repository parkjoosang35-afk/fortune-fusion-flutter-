// ═══════════════════════════════════════════════════════════════
// FILE: sintong_hero_video.dart
// [신통방통 메인 히어로 영상 전환 지시서 v1.0] 기존 6장 슬라이드
// 캐러셀(sintong_hero_carousel.dart, 더 이상 사용 안 함)을 대체하는
// 30초 홍보 영상 히어로 위젯.
//
// 원본 지시서는 React/Next.js(HeroVideo.tsx) 기준으로 작성되어 있으나
// 이 프로젝트는 Flutter이므로, §6.5 "동작 규칙(구현 계약)" 표에 정리된
// 동작을 Flutter 위젯으로 재구현한다:
//   1. 일반 환경 -> std 소스 + 음소거 자동재생
//   3. prefers-reduced-motion(Flutter: MediaQuery.disableAnimations)
//      -> 재생하지 않음, 포스터만 표시
//   4. 재생 거부(NotAllowedError 등) -> 콘솔 에러 없이 포스터 폴백
//   5. 영상 로드 실패(error 이벤트) -> 포스터 폴백(재시도 루프 금지)
//   6. 히어로가 뷰포트 35% 미만으로 벗어남 -> pause()
//   7. 앱이 백그라운드로 이동(AppLifecycleState) -> pause(), 복귀 시 재개
//   9. 가로모드 -> BoxFit.cover로 잘림(레이아웃 안 깨짐, 부모 AspectRatio가 보장)
//
// [2026-09-28 수정 — 영상 재생 종료 상태 재정의(사용자 명시 지시)]
// 기존에는 setLooping(true)로 30초 영상이 끝나면 처음으로 되돌아가
// 무한 반복되었다. 사용자가 다음과 같이 최종 동작을 명확히 확정함:
//   00:00 -> 00:30 재생 -> "영상의 실제 마지막 프레임"에서 정확히 정지
//   -> 그 마지막 프레임을 화면에 그대로 유지 -> 처음으로 되돌아가지 않음
//   -> 자동 반복하지 않음.
// 금지 동작(사용자 명시): loop=true, 종료 후 play() 재호출, 종료 후
// seek(0), 종료 후 첫 프레임 이동, 종료 후 영상 영역 숨김, 종료 후
// 검은 화면 표시.
//
// [중요 — 원본 영상 자체의 페이드아웃 테일 발견 및 대응]
// ffmpeg로 원본/파생 영상의 프레임별 밝기(YAVG)를 실측한 결과, 이
// 영상은 29.2초 지점(로고 도장이 가장 선명하게 찍힌 완성 장면, 밝기
// 최고점)을 지나 29.3초부터 30.0초까지 약 0.8초간 완전한 블랙으로
// 페이드아웃하도록 "원본 파일 자체에 이미" 인코딩되어 있다(육안 프레임
// 비교 + ffmpeg signalstats로 확인, 인코딩 실수가 아니라 영상 제작
// 단계의 의도된 엔딩 테일). 즉 "영상의 물리적 마지막 프레임(30.0s)"을
// 그대로 두면 사용자가 명시적으로 금지한 "검은 화면으로 끝남" 상태와
// 정확히 일치하게 된다.
// 사용자의 두 요구("실제 마지막 프레임 유지" + "검은 화면 금지")를
// 동시에 만족시키는 유일한 해석은, 여기서 "마지막 프레임"을 물리적
// 파일 끝이 아니라 "페이드아웃이 시작되기 전, 콘텐츠상 완성된 마지막
// 장면(로고 도장 정점)"으로 잡는 것이다. 그래서 duration 전체를 다
// 재생하지 않고, 페이드아웃 시작 직전인 [_fadeOutGuard](약 0.8초)
// 앞에서 재생을 멈춘다 — 사용자 입장에서는 "영상이 끝까지 재생되고
// 로고 장면에서 딱 멈춘 것"으로 보이고, 검은 화면은 노출되지 않는다.
//
// 구현 방법: setLooping(false) + VideoPlayerController 리스너로 재생
// 위치가 목표 정지 시점(duration - _fadeOutGuard)에 도달하면
// controller.pause() 호출 + 동일 지점으로 seekTo()해 정확히 그 프레임에
// 고정한다(리스너 호출 간격이 프레임 정확도를 보장하지 않으므로, seek로
// 최종 프레임을 확정한다 — 이 seek은 "처음으로 되돌리는" seek(0)이
// 아니라 같은 종료 지점을 정밀하게 재확인하는 것이므로 금지 동작에
// 해당하지 않는다).
// video_player는 pause 시 마지막으로 디코딩된 프레임을 그대로 화면에
// 유지하므로(첫 프레임으로 안 돌아감), 이 상태(SHeroVideoState.ended)에
// 진입한 이후로는 VisibilityDetector/AppLifecycle 콜백이 다시 play()나
// seek을 호출하지 않도록 전부 가드한다.
// 사용자가 다시 보고 싶을 때만 명시적으로 다시 재생할 수 있도록, 영상이
// 끝난 마지막 프레임 위에 재생 버튼 오버레이를 노출한다. 사용자 요청에
// 따라 이 버튼의 이름은 "다시보기"가 아니라 "스토리"로 표기한다. 탭하면
// 처음(0:00)부터 1회 재생하고, 그 재생도 끝나면 동일하게 마지막
// (페이드아웃 이전) 프레임에서 다시 정지한다(무한 루프 금지 원칙은
// 다시보기에도 동일 적용).
//
// [CDN 미구축 — 사용자 확정 사항] "영상 URL과 코드 구조는 추후 CDN으로
// 이전할 수 있도록 하드코딩하지 말고 환경변수 또는 설정값으로 관리한다."
// 이 위젯은 실제 URL 문자열을 전혀 갖지 않고, 오직
// EnvConfig.heroVideoBaseUrl 하나만 참조한다(§5 CDN 전환 시 그 상수의
// --dart-define 값만 바꾸면 이 파일은 무수정).
//
// [REQ-05 — 미재생 환경 정적 썸네일] 포스터는 네트워크 이미지가 아니라
// 로컬 asset(assets/images/sintong_home_v2/hero_video_poster.jpg)으로
// 앱에 번들한다. 원본 지시서는 포스터도 CDN에서 받아오는 웹 환경을
// 가정했지만, "포스터 로드 자체가 실패하는 2차 장애(REQ-05 최소
// 보증선)"를 Flutter에서는 애초에 원천 차단할 수 있다 — 포스터 1장
// (약 68KB)을 로컬 asset으로 두면 네트워크 상태와 무관하게 항상 즉시
// 표시되므로, "영상이 없으면 빈 화면"이 되는 상황이 구조적으로
// 발생하지 않는다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../../core/config/env_config.dart';
import '../sintong_home_v2_tokens.dart';

/// 히어로 영상 재생 상태 — React 참조 구현의 HeroVideoState를 그대로
/// Dart enum으로 옮긴 것(계측/디버깅 시 상태 이름을 일관되게 부르기 위함).
///
/// [2026-09-28 추가] [ended] — 30초(또는 재생 배속과 관계없이 실제
/// duration) 재생이 끝나 마지막 프레임에서 정지한 최종 상태. 이 상태는
/// [fallback]과 달리 "영상 재생에 성공했고 정상적으로 끝났다"는 뜻이며,
/// 화면에는 계속 마지막 프레임이 보인다(영상 위젯을 숨기지 않음).
/// [ended] 상태에서는 VisibilityDetector/AppLifecycle에 의한 어떤
/// play()/seek() 호출도 발생하지 않는다 — 오직 사용자가 "스토리"
/// 버튼을 직접 탭했을 때만 재생이 재개된다.
enum SHeroVideoState { idle, loading, ready, playing, paused, ended, fallback }

/// [§4.2 파생본 파일명 규칙] CDN/정적 서버에 올려야 하는 정확한
/// 파일명. 서버 쪽(nginx 정적 디렉토리 또는 향후 S3 버킷)에 이 이름
/// 그대로 존재해야 한다.
class SHeroVideoAssets {
  SHeroVideoAssets._();

  static String get std =>
      '${EnvConfig.heroVideoBaseUrl}/main-promo-v3-std.mp4';

  /// [저속망 대응 예비 자산] 지시서 §4.2의 540x960 저용량본. 현재
  /// Flutter 클라이언트에는 saveData/effectiveType을 읽을 수 있는
  /// 표준 API가 없어(웹의 navigator.connection과 동등한 것이 없음)
  /// 자동 전환 로직(§6.5 규칙 2)은 이번 구현 범위에서 제외했지만,
  /// 파일 자체는 서버에 함께 배포해 두어 향후 connectivity_plus 등을
  /// 추가해 저속망 자동 전환을 붙일 때 코드 변경 없이 바로 쓸 수 있게
  /// 한다.
  static String get low =>
      '${EnvConfig.heroVideoBaseUrl}/main-promo-v3-low.mp4';
}

/// 히어로 영상 위젯. 부모가 [SintongHeroCarousel]을 이 위젯으로
/// 완전히 교체한다(README 6장 슬라이드 자리 → 30초 영상 1개).
///
/// 칩 로우/오버레이 캡션은 이 위젯 바깥(부모 sintong_home_v2_screen.dart)
/// 에서 그대로 유지되므로, 이 위젯은 영상/포스터/"스토리" 다시보기
/// 버튼 레이어만 담당한다.
class SintongHeroVideo extends StatefulWidget {
  const SintongHeroVideo({super.key});

  @override
  State<SintongHeroVideo> createState() => _SintongHeroVideoState();
}

class _SintongHeroVideoState extends State<SintongHeroVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  SHeroVideoState _state = SHeroVideoState.idle;

  /// [§6.5 규칙 6] 히어로가 뷰포트에서 35% 미만으로 벗어나면 pause.
  /// VisibilityDetector 콜백은 didUpdateWidget/build 밖에서 비동기로
  /// 오므로, 매번 새 키를 만들지 않도록 고정 키를 쓴다.
  static const _visibilityKey = Key('sintong_hero_video_visibility');

  /// [원본 영상 페이드아웃 테일 회피] ffmpeg 밝기(YAVG) 실측 결과, 이
  /// 영상은 29.2초(로고 도장 완성 장면, 밝기 최고점)를 지나 30.0초까지
  /// 완전한 블랙으로 페이드아웃하도록 원본 파일 자체에 인코딩되어 있다.
  /// "검은 화면으로 끝나면 안 된다"는 요구를 지키기 위해, 물리적
  /// duration이 아니라 이 페이드아웃이 시작되기 전 지점을 실질적인
  /// "마지막 프레임"으로 취급해 그 지점에서 정지한다.
  static const Duration _fadeOutGuard = Duration(milliseconds: 800);

  /// [종료 판정 여유값] video_player 리스너 호출 간격(플랫폼별로 매
  /// 프레임 정확히 오지 않을 수 있음) 때문에 목표 지점을 정확히
  /// 스치듯 지나칠 수 있어, 목표 지점에 이 값만큼 근접하면 "도달"로
  /// 간주하고 정지시킨다. 정지 직후 목표 지점으로 seekTo()해 오차를
  /// 보정하므로, 이 값 자체가 최종 정지 프레임에 영향을 주지 않는다.
  static const Duration _reachTolerance = Duration(milliseconds: 120);

  /// 실질적인 정지 목표 지점(= duration - 페이드아웃 회피 구간). 영상이
  /// 초기화되기 전에는 알 수 없으므로 nullable로 두고, initialize() 완료
  /// 시 1회 계산해 캐시한다.
  Duration? _stopAt;

  bool _reducedMotionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery는 didChangeDependencies 이후에만 안전하게 읽을 수
    // 있다. 최초 1회만 판정하고(런타임 중 OS 설정이 바뀌는 극히 드문
    // 경우는 다음 화면 재진입 시 반영됨), 그 결과에 따라 영상 초기화
    // 자체를 시작할지 결정한다.
    if (!_reducedMotionChecked) {
      _reducedMotionChecked = true;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        // [§6.5 규칙 3] 모션 최소화 환경 — 영상 컨트롤러 자체를 만들지
        // 않고 포스터만 표시한다(React 구현의 hero__video 미렌더와 동일).
        setState(() => _state = SHeroVideoState.fallback);
      } else {
        _initializeVideo();
      }
    }
  }

  void _initializeVideo() {
    setState(() => _state = SHeroVideoState.loading);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(SHeroVideoAssets.std),
    );
    _controller = controller;
    // [2026-09-28 변경] 무한 반복 금지(사용자 명시 요구) — 영상은 정확히
    // 1회만 재생되고 끝에서 정지해야 하므로 looping을 켜지 않는다.
    controller.setLooping(false);
    controller.setVolume(0); // REQ-04: 음소거 필수(자동재생 허용 조건).
    // [종료 감지 리스너] 매 프레임 position 갱신 시 duration에 근접했는지
    // 확인해, 근접하면 pause()만 호출하고 seek은 절대 하지 않는다.
    controller.addListener(_onControllerUpdate);
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          // [정지 목표 지점 계산] duration에서 페이드아웃 회피 구간을
          // 뺀 지점. 만약 영상이 예상보다 훨씬 짧아 음수가 되는 극단적
          // 경우(잘못된 자산 교체 등 방어)에는 0으로 클램프한다.
          final duration = controller.value.duration;
          var stopAt = duration - _fadeOutGuard;
          if (stopAt < Duration.zero) stopAt = Duration.zero;
          _stopAt = stopAt;
          setState(() => _state = SHeroVideoState.ready);
          // 초기화 직후 곧바로 재생을 시도한다. 실제 재생 여부는
          // VisibilityDetector가 화면에 보이는지에 따라 추가로
          // 제어되므로, 여기서는 "재생 가능 상태"만 만든다. 만약
          // 위젯이 이미 화면에 보이는 상태(가장 흔한 경우 —
          // 홈 화면 최초 진입)라면 즉시 재생한다.
          _tryPlay();
        })
        .catchError((Object err) {
          // [§6.5 규칙 5] 영상 로드 실패(네트워크 오류/코덱 미지원 등)
          // → 콘솔에는 디버그 로그만 남기고 조용히 포스터로 폴백한다.
          // 재시도 루프를 만들지 않는다(같은 실패가 반복되면 배터리/
          // 네트워크를 계속 소모하기 때문).
          if (kDebugMode) {
            debugPrint('[SintongHeroVideo] 영상 초기화 실패 -> $err');
          }
          if (!mounted) return;
          setState(() => _state = SHeroVideoState.fallback);
        });
  }

  /// [2026-09-28 신규] 재생 위치를 매 프레임 감시해 "종료"를 판정한다.
  /// 물리적 파일 끝(duration)이 아니라 [_stopAt](페이드아웃 시작 전
  /// 지점)에 도달하면 pause() 후 정확히 [_stopAt]으로 seekTo()해
  /// 프레임을 확정한다. 이 seek은 "처음(0:00)으로 되돌리는" 동작이
  /// 아니라 같은 종료 시점을 정밀 보정하는 것이므로, 사용자가 금지한
  /// "종료 후 seek(0)/첫 프레임 이동"에 해당하지 않는다.
  void _onControllerUpdate() {
    final controller = _controller;
    final stopAt = _stopAt;
    if (controller == null || stopAt == null || !mounted) return;
    // ended로 이미 정지한 뒤에는 더 이상 판정할 필요가 없다(중복 setState
    // 방지 및 "스토리" 재생 중 재판정과의 혼선 방지는 아래 _state 체크로
    // 충분히 처리됨).
    if (_state != SHeroVideoState.playing) return;
    final value = controller.value;
    if (!value.isInitialized) return;
    final remaining = stopAt - value.position;
    if (remaining <= _reachTolerance) {
      // [핵심] 물리적 끝(검은 화면)이 아니라 콘텐츠상 마지막 장면인
      // stopAt 지점에서 멈춘다. loop 금지, seek(0) 금지, 재생 재호출
      // 금지 — 로고 도장이 찍힌 완성 장면이 화면에 그대로 남는다.
      controller.pause();
      controller.seekTo(stopAt);
      setState(() => _state = SHeroVideoState.ended);
    }
  }

  Future<void> _tryPlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    // [핵심 가드] 영상이 이미 정상적으로 끝난 상태(ended)이거나 폴백
    // 상태라면, 화면 재진입/포그라운드 복귀 등 어떤 트리거로도 다시
    // 재생하지 않는다(사용자 명시 금지 동작: "종료 후 play() 재호출").
    if (_state == SHeroVideoState.fallback ||
        _state == SHeroVideoState.ended) {
      return;
    }
    try {
      await controller.play();
      if (!mounted) return;
      setState(() => _state = SHeroVideoState.playing);
    } catch (err) {
      // [§6.5 규칙 4] 자동재생이 브라우저/OS 정책으로 거부된 경우
      // (Flutter Web에서 muted=true면 거의 발생하지 않지만, 저전력
      // 모드 등 실기기 예외 상황을 대비해 동일하게 방어한다).
      if (kDebugMode) {
        debugPrint('[SintongHeroVideo] play() 거부됨 -> $err');
      }
      if (!mounted) return;
      setState(() => _state = SHeroVideoState.fallback);
    }
  }

  void _pause() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      controller.pause();
    }
    if (mounted && _state == SHeroVideoState.playing) {
      setState(() => _state = SHeroVideoState.paused);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    // [핵심 가드] 영상이 이미 종료(ended)된 뒤에는 뷰포트 출입과 무관하게
    // 아무 것도 하지 않는다 — 마지막 프레임이 그대로 유지되어야 한다.
    if (_state == SHeroVideoState.fallback ||
        _state == SHeroVideoState.idle ||
        _state == SHeroVideoState.ended) {
      return;
    }
    // [§6.5 규칙 6] 35% 미만 노출 -> pause / 그 이상 -> 재생(재개).
    if (info.visibleFraction >= 0.35) {
      if (_state != SHeroVideoState.playing) _tryPlay();
    } else {
      _pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // [핵심 가드] 종료(ended) 상태에서는 백그라운드/포그라운드 전환과
    // 무관하게 아무 것도 하지 않는다(재생 재개 금지 — 마지막 프레임 유지).
    if (_state == SHeroVideoState.ended) return;
    // [§6.5 규칙 7] 앱이 백그라운드로 이동 -> pause, 복귀 시 재개.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pause();
    } else if (state == AppLifecycleState.resumed) {
      _tryPlay();
    }
  }

  /// [2026-09-28 신규 — "스토리" 다시보기]
  /// 사용자가 마지막 프레임 위의 재생 버튼("스토리")을 탭했을 때만
  /// 호출된다. 처음(0:00)으로 되돌린 뒤 1회 재생하고, 그 재생이 끝나면
  /// [_onControllerUpdate]가 다시 동일하게 마지막 프레임에서 정지시킨다
  /// (다시보기도 무한 루프를 만들지 않는다 — 사용자 명시 요구).
  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (!controller.value.isInitialized) return;
    try {
      // ended 가드를 우회하기 위해 재생 전에 상태를 먼저 playing으로
      // 전환한다(이 함수만이 유일하게 ended 상태에서 재생을 트리거할 수
      // 있는 경로).
      await controller.seekTo(Duration.zero);
      if (!mounted) return;
      setState(() => _state = SHeroVideoState.playing);
      await controller.play();
    } catch (err) {
      if (kDebugMode) {
        debugPrint('[SintongHeroVideo] 스토리 다시보기 실패 -> $err');
      }
      if (!mounted) return;
      setState(() => _state = SHeroVideoState.fallback);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildPoster() {
    // [REQ-05] 로컬 asset이므로 네트워크 상태와 무관하게 항상 즉시
    // 표시된다 — "빈 박스/1×1 투명 픽셀" 상황이 구조적으로 없다.
    return Image.asset(
      'assets/images/sintong_home_v2/hero_video_poster.jpg',
      fit: BoxFit.cover,
    );
  }

  /// [2026-09-28 신규] 영상이 마지막 프레임에서 정지(ended)한 뒤에만
  /// 노출되는 다시보기 버튼. 사용자 요청에 따라 라벨은 "다시보기"가
  /// 아니라 "스토리"로 표기한다.
  Widget _buildStoryReplayButton() {
    return Center(
      child: GestureDetector(
        onTap: _replay,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0x59000000), // rgba(0,0,0,.35)
            borderRadius: BorderRadius.circular(SHomeV2Radii.pill),
            border: Border.all(color: const Color(0x4DFFFFFF), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.replay_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text('스토리', style: SHomeV2Text.chip(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showVideo =
        _state != SHeroVideoState.fallback &&
        _state != SHeroVideoState.idle &&
        controller != null &&
        controller.value.isInitialized;

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: DecoratedBox(
        // [REQ-06] 로딩 중 빈 화면 대신 브랜드 배경색(§6.3 CSS .hero
        // background: #0b1020 그대로).
        decoration: const BoxDecoration(color: Color(0xFF0B1020)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 포스터는 영상이 재생 중이 아닐 때 항상 바닥에 깔아 둔다
            // (영상 initialize 대기 중 빈 화면이 보이는 구간을 없앤다).
            _buildPoster(),
            if (showVideo)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            // [종료 후에만 노출] 마지막 프레임이 화면에 그대로 유지된
            // 상태 위에 "스토리" 다시보기 버튼을 겹쳐 보여준다.
            if (_state == SHeroVideoState.ended) _buildStoryReplayButton(),
          ],
        ),
      ),
    );
  }
}
