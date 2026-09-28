// ═══════════════════════════════════════════════════════════════
// FILE: sintong_hero_video.dart
// [신통방통 메인 히어로 영상 전환 지시서 v1.0] 기존 6장 슬라이드
// 캐러셀(sintong_hero_carousel.dart, 더 이상 사용 안 함)을 대체하는
// 30초 홍보 영상 히어로 위젯.
//
// 원본 지시서는 React/Next.js(HeroVideo.tsx) 기준으로 작성되어 있으나
// 이 프로젝트는 Flutter이므로, §6.5 "동작 규칙(구현 계약)" 표에 정리된
// 동작을 Flutter 위젯으로 재구현한다:
//   1. 일반 환경 -> std 소스 + 음소거 자동재생 + 루프
//   3. prefers-reduced-motion(Flutter: MediaQuery.disableAnimations)
//      -> 재생하지 않음, 포스터만 표시
//   4. 재생 거부(NotAllowedError 등) -> 콘솔 에러 없이 포스터 폴백
//   5. 영상 로드 실패(error 이벤트) -> 포스터 폴백(재시도 루프 금지)
//   6. 히어로가 뷰포트 35% 미만으로 벗어남 -> pause()
//   7. 앱이 백그라운드로 이동(AppLifecycleState) -> pause(), 복귀 시 재개
//   9. 가로모드 -> BoxFit.cover로 잘림(레이아웃 안 깨짐, 부모 AspectRatio가 보장)
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

/// 히어로 영상 재생 상태 — React 참조 구현의 HeroVideoState를 그대로
/// Dart enum으로 옮긴 것(계측/디버깅 시 상태 이름을 일관되게 부르기 위함).
enum SHeroVideoState { idle, loading, ready, playing, paused, fallback }

/// [§4.2 파생본 파일명 규�칙] CDN/정적 서버에 올려야 하는 정확한
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
/// 에서 그대로 유지되므로, 이 위젯은 영상/포스터 레이어만 담당한다.
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
    controller.setLooping(true);
    controller.setVolume(0); // REQ-04: 음소거 필수(자동재생 허용 조건).
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
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

  Future<void> _tryPlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_state == SHeroVideoState.fallback) return;
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
    if (_state == SHeroVideoState.fallback ||
        _state == SHeroVideoState.idle) {
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
    // [§6.5 규칙 7] 앱이 백그라운드로 이동 -> pause, 복귀 시 재개.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pause();
    } else if (state == AppLifecycleState.resumed) {
      _tryPlay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          ],
        ),
      ),
    );
  }
}
