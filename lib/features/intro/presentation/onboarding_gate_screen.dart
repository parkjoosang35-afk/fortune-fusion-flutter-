// ═══════════════════════════════════════════════════════════════
// FILE: onboarding_gate_screen.dart
// [온보딩 영상 적용] "신통방통 온보딩 영상 적용 가이드" §4 트리거/재노출
// 방지 요구사항을 기존 인트로 페이저(IntroPagerScreen, 카드1/카드2/CTA)
// 앞단에 배선하는 게이트 화면.
//
// [기존 구조 재사용 원칙] SplashScreen은 이미 `introSeen`(=기존
// onboarding_completed 키) 여부로 `/intro` vs `/home` 분기를 담당하고
// 있다. 이 게이트는 그 분기 로직을 건드리지 않고, `/intro`로 진입한
// 뒤 "영상을 아직 안 봤으면 영상부터, 봤으면(또는 영상 끝나면) 기존
// IntroPagerScreen"으로 한 단계 더 얹는다.
//
// [SharedPreferences 키] 가이드 §6 예시 그대로 `has_seen_onboarding_v1`을
// 별도 키로 사용한다(기존 `onboarding_completed`와는 다른 목적 —
// 그것은 "인트로 카드 3페이지를 봤는지", 이것은 "5대 기능 소개 영상을
// 봤는지"를 각각 독립적으로 추적해, 향후 영상만 교체해도(v1→v2) 카드
// 인트로 완료 여부와 무관하게 영상만 재노출할 수 있도록 설계했다).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'intro_palette.dart';
import 'intro_pager_screen.dart';
import 'onboarding_video_screen.dart';

class OnboardingGateScreen extends StatefulWidget {
  const OnboardingGateScreen({super.key});

  static const String _prefsKey = 'has_seen_onboarding_v1';

  @override
  State<OnboardingGateScreen> createState() => _OnboardingGateScreenState();
}

class _OnboardingGateScreenState extends State<OnboardingGateScreen> {
  /// null=아직 SharedPreferences 조회 중, true=영상 다시 안 봐도 됨,
  /// false=영상을 아직 안 봤으므로 재생해야 함.
  bool? _videoAlreadySeen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen =
          prefs.getBool(OnboardingGateScreen._prefsKey) ?? false;
      if (!mounted) return;
      setState(() => _videoAlreadySeen = seen);
    } catch (_) {
      // 조회 실패 시 안전하게 "영상을 봤다"로 간주해 카드 인트로로 진행
      // (네트워크/저장소 이슈로 화면이 멈추는 것보다 다음 화면 진행이 우선).
      if (mounted) setState(() => _videoAlreadySeen = true);
    }
  }

  Future<void> _onVideoFinished() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingGateScreen._prefsKey, true);
    } catch (_) {
      // 저장 실패해도 이번 실행에서는 계속 진행(다음 실행에 재노출될 수
      // 있으나 화면이 멈추지 않는 것이 우선).
    }
    if (!mounted) return;
    setState(() => _videoAlreadySeen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_videoAlreadySeen == null) {
      // [가이드 §5] 로딩 처리 - 앱 브랜드 컬러 그라데이션 + 스피너.
      return Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                IntroPalette.backgroundTop,
                IntroPalette.backgroundBottom,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: IntroPalette.primary),
          ),
        ),
      );
    }

    if (_videoAlreadySeen == false) {
      return OnboardingVideoScreen(onFinished: _onVideoFinished);
    }

    return const IntroPagerScreen();
  }
}
