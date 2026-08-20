import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../intro/application/intro_state_provider.dart';
import '../../intro/application/intro_config_provider.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../home/domain/jeontong_local_to_server_migration.dart';
import '../application/auth_provider.dart';

/// [인트로 전면 개편 - 1단계 브랜드 스플래시]
/// 중앙 로고 + "신통방통" + (선택)짧은 카피, fade-in/out, 1.0~1.5초.
///
/// [2026-08-21 인트로 3종 색상 정리] 배경/로고 톤을 브랜드 컬러
/// #90035C(IntroPalette) 기준으로 교체했다. 부트스트랩 로직과 진입 정책은
/// 절대 손대지 않고 시각적 톤만 바꾼다(§7 계산/로직 불변 원칙과 동일한
/// 정신 — 여기서는 "부트스트랩 로직 불변").
///
/// [기존 구조 재사용 원칙] 부트스트랩 로직(AuthProvider.restoreSession() 호출,
/// introSeen 여부에 따른 분기)은 기존 SplashScreen 구조를 그대로 유지하고,
/// 시각적 톤과 진입 정책만 개선한다.
///
/// [진입 정책 변경 — 로그인 강제 제거] 기존에는 "온보딩 완료 + 비로그인"이면
/// 무조건 /login으로 보냈으나, 이는 "회원가입 강제 없이 체험 가능"이라는 인트로
/// 개편 핵심 원칙과 배치된다. 이제 introSeen(=기존 onboarding_completed)이면
/// 로그인 여부와 무관하게 항상 /home(AppShell)으로 보낸다 — 홈 화면과 하위 화면은
/// 이미 auth.isLoggedIn을 각자 체크해 비회원도 안전하게 탐색할 수 있도록 되어 있다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    // fade-in(0~40%) -> hold -> fade-out(80~100%), 전체 1.3초 내에서 처리.
    _fade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);
    _controller.forward();
    // [버그 수정] initState 안에서 _bootstrap()을 곧바로 호출하면, 그 안의
    // AuthProvider.restoreSession()이 첫 await 이전에 동기적으로
    // notifyListeners()를 호출해 "setState() or markNeedsBuild() called
    // during build" assertion을 유발한다(위젯 트리가 아직 최초 빌드 중인
    // 시점에 상위 InheritedProvider를 갱신 요청하기 때문). release 빌드는
    // assert가 제거돼 겉으로 드러나지 않았지만, widget test(debug 모드)에서는
    // 항상 예외로 잡힌다. addPostFrameCallback으로 첫 프레임이 완전히 끝난
    // 뒤에 실행하도록 미뤄 근본적으로 해결한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final authProvider = context.read<AuthProvider>();
    final introState = context.read<IntroStateProvider>();
    final introConfig = context.read<IntroConfigProvider>();

    // [인트로 전면 개편] 인트로 문구/보상수량 설정도 스플래시 단계에서 함께
    // 미리 로드해둔다 — IntroPagerScreen 진입 시 깜빡임 없이 바로 관리자
    // 설정(또는 fallback)이 반영된 카피를 보여주기 위함.
    await Future.wait([
      authProvider.restoreSession(),
      introState.load(),
      introConfig.load(),
      Future.delayed(const Duration(milliseconds: 1300)),
    ]);

    if (!mounted) return;

    // [신통방통 2단계 - 로컬 → 서버 1회성 마이그레이션] 세션 복원(=로그인
    // 상태 확정) 직후, 로그인 사용자에 한해 로컬 JeontongProfileStore 값을
    // 서버 UserProfile로 1회 옮긴다. 조건은 함수 내부에서 전부 판단하므로
    // (비로그인/이미 서버 데이터 있음/로컬 데이터 없음이면 아무 것도 하지
    // 않음) 매 부팅마다 안전하게 호출할 수 있다(멱등). 실패해도 스플래시
    // 화면 전환(아래 라우팅)을 막지 않는다 — fire-and-forget이 아니라 await로
    // 순서를 보장하되, 결과와 무관하게 계속 진행한다.
    if (authProvider.isLoggedIn) {
      final migration = await migrateLocalJeontongProfileToServer(
        authProvider,
      );
      if (kDebugMode) {
        debugPrint('[신통방통 2단계 마이그레이션] $migration');
      }
    }

    if (!mounted) return;

    if (!introState.introSeen) {
      Navigator.of(context).pushReplacementNamed('/intro');
    } else {
      // [로그인 강제 제거] 로그인 여부와 무관하게 홈으로. 비회원도 하위 화면에서
      // 자연스럽게 탐색 가능(각 화면이 auth.isLoggedIn을 개별 체크).
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IntroPalette.backgroundSoft,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [IntroPalette.backgroundSoft, IntroPalette.primaryLight],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        IntroPalette.primary,
                        IntroPalette.primaryDark,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: IntroPalette.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: IntroPalette.onPrimary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: UnifiedTokens.spaceXxl),
                Text(
                  '신통방통',
                  style: UnifiedText.titleLarge(
                    color: IntroPalette.primaryDark,
                  ).copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
