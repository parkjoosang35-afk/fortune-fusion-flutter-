// ═══════════════════════════════════════════════════════════════
// FILE: onboarding_video_screen.dart
// [온보딩 영상 적용] "신통방통 온보딩 영상 적용 가이드 (개발자 핸드오프).pdf"
// 스펙 1:1 구현.
//
// 앱 최초 실행 시(또는 회원가입 직후) 5대 핵심 기능(귀인지도/정통사주/
// 타로/소원방/관상·손금)을 소개하는 27.58초 분량 영상(9:16, H.264,
// 자막·BGM 내장)을 전체화면으로 1회 자동 재생한다.
//
// [가이드 §4~6 요구사항 반영]
// - 트리거: 앱 최초 설치 후 첫 실행 시 또는 신규 회원가입 완료 직후,
//   메인 화면 진입 전에 표시(스플래시 → 이 화면 → 기존 IntroPagerScreen
//   순서로 배선. 라우팅은 이 화면의 호출부(SplashScreen) 참고).
// - 재노출 방지: SharedPreferences 키 `has_seen_onboarding_v1`
//   (가이드 §6 예시 그대로, 버전 넘버 포함 — 추후 영상 교체 시 v2로 올려
//   기존 유저에게도 재노출 가능).
// - 전체화면 자동 재생, loop 없이 1회만, 종료 시 자동으로 다음 화면 전환.
// - 우측 상단 "건너뛰기" 버튼 항상 노출.
// - 자동재생 정책 대응: 기본 음소거(muted) 상태로 시작, 우측 하단에
//   음소거 해제 아이콘 노출.
// - 로딩 중: 앱 브랜드 컬러 다크 네이비-퍼플 그라데이션 배경 + 스피너
//   (기존 IntroPalette 그대로 재사용 — 별도 팔레트 신설 없이 "범위 격리
//   원칙" 그대로 준수).
// - assets/videos/onboarding.mp4 앱 번들 내장(17MB 수준, 가이드 권장).
// - BoxFit.cover로 9:16 전체화면 채우기.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'intro_palette.dart';
import 'widgets/intro_skip_action.dart';

class OnboardingVideoScreen extends StatefulWidget {
  /// 영상 재생이 끝나거나(자동/건너뛰기) 다음 화면으로 넘어가야 할 때 호출.
  final VoidCallback onFinished;

  const OnboardingVideoScreen({super.key, required this.onFinished});

  @override
  State<OnboardingVideoScreen> createState() => _OnboardingVideoScreenState();
}

class _OnboardingVideoScreenState extends State<OnboardingVideoScreen> {
  VideoPlayerController? _controller;
  bool _isMuted = true; // [가이드 §5] 자동재생 정책 대응 기본 음소거.
  bool _finished = false; // onFinished 중복 호출 방지.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(
      'assets/videos/onboarding.mp4',
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(0); // 기본 음소거로 재생 시작.
      await controller.setLooping(false); // [가이드 §5] loop 없이 1회만.
      controller.addListener(_onVideoTick);
      await controller.play();
      setState(() {});
    } catch (e) {
      // 영상 로드 실패 시 화면이 멈추지 않도록 즉시 다음 화면으로 폴백.
      if (mounted) {
        setState(() => _loadFailed = true);
      }
      _finish();
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    // [가이드 §5] "영상이 끝나면 자동으로 메인 화면으로 전환".
    if (!controller.value.isPlaying &&
        controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      _finish();
    }
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    controller.setVolume(_isMuted ? 0 : 1);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady =
        controller != null && controller.value.isInitialized && !_loadFailed;

    return Scaffold(
      backgroundColor: IntroPalette.backgroundBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [IntroPalette.backgroundTop, IntroPalette.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // [가이드 §5] 영상 로드 중 로딩 스피너, 로드 완료 시 영상 재생.
              if (isReady)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 9 / 16
                        : controller.value.aspectRatio,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  ),
                )
              else if (!_loadFailed)
                const Center(
                  child: CircularProgressIndicator(
                    color: IntroPalette.primary,
                  ),
                ),

              // [가이드 §5] 우측 상단 "건너뛰기" 버튼 — 항상 노출.
              Positioned(
                top: 8,
                right: 8,
                child: IntroSkipAction(onSkip: _finish),
              ),

              // [가이드 §5] 우측 하단 음소거 해제 아이콘.
              if (isReady)
                Positioned(
                  bottom: 24,
                  right: 20,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
