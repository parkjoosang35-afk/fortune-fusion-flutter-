import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../intro/application/intro_state_provider.dart';
import '../../intro/application/intro_config_provider.dart';
import '../../intro/domain/intro_config_model.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';
import '../../intro/presentation/widgets/intro_eyebrow_label.dart';
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
/// [2026 디자인 핸드오프 콘텐츠 전면 반영] 기존 UI는 색상/캐릭터 이미지만
/// 핸드오프를 따르고 실제 카피/구조(eyebrow 라벨, 정확한 서브카피, 로딩닷)는
/// 반영하지 않았던 문제를 바로잡는다. `screens/01_Intro.html` 페이지1
/// (`eyebrow`="神通萬通 · SINTONG", 제목 "신통방통" 42px, 서브카피
/// "하늘의 답을 / 신통도령이 전해드립니다", 하단 로딩닷 3개)을 그대로 이식했다.
/// 부트스트랩 로직(`_bootstrap`)과 fade 애니메이션 컨트롤러는 절대 손대지 않는다.
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
  // [스플래시 히어로 이미지 미표시 버그 수정 - 2차, 근본 원인 해결]
  // 1차 수정(precacheImage를 _bootstrap의 Future.wait에 포함)은
  // "화면 전환 타이밍"만 늦출 뿐, 정작 첫 build() 호출 시점에 이미지가
  // 아직 캐시에 없으면 그 프레임은 빈 이미지로 그려지는 문제를 막지
  // 못했다(Playwright 정밀 캡처로 실제 확인 — 첫 페인트 프레임에
  // 히어로 영역이 빈 그라디언트로 나가고, 폰트조차 tofu box로
  // 깨져 있었음). 근본적으로는 "이미지가 준비되기 전에는 그 자리를
  // 아예 투명하게 유지"해야 한다. _heroReady 플래그를 두어 build()에서
  // AnimatedOpacity로 감싸고, precacheImage가 끝나야만(또는 타임아웃 시)
  // 화면에 드러나도록 한다 — 레이아웃 높이(260px)는 항상 고정 유지되므로
  // 다른 요소가 밀리는 점프는 없다.
  Future<void>? _heroImagePrecache;
  bool _heroReady = false;

  @override
  void initState() {
    super.initState();
    // [스플래시 히어로 이미지 미표시 버그 수정 - 4차, 진짜 근본 원인 해결]
    // 1~3차 수정은 모두 "setState와 네비게이션 사이의 프레임 레이스"를
    // 의심했으나, 실제 디버그 로그(T0~T10 타임스탬프)를 웹 콘솔에서
    // 직접 추적한 결과 전혀 다른 원인이 드러났다:
    //
    //   기존 _controller는 initState 시점부터 "고정 1300ms" 동안
    //   fade-in(0~40%) -> hold(40~80%) -> fade-out(80~100%)을 자동으로
    //   전부 재생하는 TweenSequence였다. 그런데 실제 부트스트랩
    //   (세션 복원 + introConfig 로드 + 히어로 이미지 precache + 400ms
    //   체류)은 이 환경에서 약 2.0~2.5초가 걸린다(T0=4.937s ~
    //   T10=7.438s, 총 2501ms). 즉 화면 전체를 감싸는 FadeTransition은
    //   1.3초 만에 이미 opacity=0(완전 투명)으로 끝나버리고, 그 안의
    //   히어로 이미지가 `_heroReady=true`가 되어 실제로 그려지는 시점
    //   (T7=6.950s, initState 대비 +2013ms)에는 이미 부모 전체가
    //   투명해서 화면에 아무것도 보이지 않았던 것이다. setState/
    //   endOfFrame 관련 수정(2~3차)은 이 문제와 무관했다.
    //
    //   근본 해결: 컨트롤러를 "고정 시간에 자동으로 사라지는 애니메이션"
    //   이 아니라 "빠르게 페이드인한 뒤 부트스트랩이 끝날 때까지 완전히
    //   보이는 상태(opacity=1)로 유지 -> 부트스트랩 완료 직후에만 명시적
    //   으로 페이드아웃"하는 방식으로 재설계한다. forward()는 페이드인만
    //   담당하고 끝나면 1.0에 멈춰 있으며, `_bootstrap()`의 네비게이션
    //   직전에 `_controller.reverse()`를 await해 페이드아웃시킨다.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    // [스플래시 히어로 이미지 미표시 버그 수정] 첫 프레임이 끝난 직후
    // (addPostFrameCallback) precacheImage를 시작해 다운로드를 최대한
    // 앞당긴다. initState 시점에는 아직 BuildContext의 mediaquery 등이
    // 완전히 준비되지 않을 수 있어 postFrameCallback에서 실행한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // [스플래시 타이틀 폰트 tofu box 버그 수정 - 5차, 폰트 로딩도 이미지와
      // 동일하게 게이팅한다] 근본 원인: IntroTextStyles.title()이 쓰는
      // GoogleFonts.nanumMyeongjo()는 로컬 asset으로 번들되어 있지 않아
      // (Pretendard/GowunBatang/IBMPlexMono와 달리) 웹에서 최초 호출 시마다
      // fonts.gstatic.com으로 런타임 네트워크 다운로드가 필요하다. 그런데
      // 기존 코드는 히어로 이미지만 _heroReady로 게이팅했고, 타이틀
      // Text는 폰트 도착 여부와 무관하게 즉시 그려져 — 다운로드가 끝나기
      // 전 첫 프레임에는 시스템 폴백 폰트(한글 글리프 없음)로 그려져
      // tofu box(□□□□)가 노출됐다. 해결: 여기서 IntroTextStyles.title()을
      // 한 번 호출해 폰트 로딩을 즉시 트리거하고, 그 직후
      // GoogleFonts.pendingFonts()로 로딩 완료 Future를 확보한 뒤,
      // 이미지 precache와 함께 Future.wait로 묶어 둘 다 끝나야만
      // _heroReady=true가 되도록 한다 — build()에서도 히어로 이미지와
      // 타이틀/서브카피를 하나의 AnimatedOpacity로 함께 묶어 폰트가
      // 준비되기 전에는 텍스트도 투명하게 유지된다(FOUT 원천 차단).
      IntroTextStyles.title(fontSize: 38); // 폰트 로딩 트리거(side-effect)
      final fontsPending = GoogleFonts.pendingFonts();
      _heroImagePrecache =
          fontsPending
          .timeout(
            const Duration(milliseconds: 2500),
            onTimeout: () {
              if (kDebugMode) {
                debugPrint(
                  '[스플래시 히어로 이미지/폰트] precache 타임아웃(2.5초) — 계속 진행',
                );
              }
              return <void>[];
            },
          ).whenComplete(() {
            // [2차 수정 핵심] precache(이미지+폰트)가 끝나는 즉시(성공이든
            // 타임아웃이든) setState로 _heroReady를 true로 바꿔, 그제서야
            // 히어로 이미지 + 타이틀/서브카피가 함께 화면에 페이드인되도록
            // 한다. 이 setState 시점에는 이미 이미지가 디코딩되고 폰트가
            // FontLoader에 등록된 상태이므로, 다음 build()에서는 반드시
            // 완성된 이미지와 정상 한글 폰트가 함께 그려진다.
            if (mounted) {
              setState(() => _heroReady = true);
            }
          });
    });
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

    // [스플래시 히어로 이미지 미표시 버그 수정 - 3차, 완전 해결]
    // 2차 수정(precacheImage 완료 시 setState(_heroReady=true))도
    // Future.wait 안에 함께 묶어두면, precache가 끝나는 순간 setState가
    // "다음 프레임에 리빌드 예약"만 걸어둔 채로 Future.wait의 연속 실행이
    // 곧바로(같은 마이크로태스크 배치 안에서) 이어져 버려, 실제로는
    // 이미지가 포함된 프레임이 화면에 한 번도 그려지지 않고 바로
    // Navigator.pushReplacementNamed가 호출되는 경쟁 상태가 있었다
    // (Playwright 정밀 캡처로 재확인: 여전히 빈 이미지+깨진 폰트 프레임만
    // 노출됨). 이를 근본적으로 막기 위해 여기서는:
    //  1) 다른 부트스트랩 작업(세션 복원 등)과 히어로 이미지 로딩을
    //     완전히 분리된 await 단계로 나누고,
    //  2) setState 이후 `WidgetsBinding.instance.endOfFrame`으로 실제로
    //     그 프레임이 래스터화될 때까지 명시적으로 대기하며,
    //  3) 그 후에도 최소 체류 시간(400ms)을 추가로 확보해, 이미지가
    //     "찰나에 스쳐가는" 것이 아니라 사용자 눈에 실제로 보이도록 한다.
    if (_heroImagePrecache != null) {
      await _heroImagePrecache;
    }
    if (mounted) {
      setState(() => _heroReady = true);
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;

    // [신통방통 2단계 - 로컬 → 서버 1회성 마이그레이션] 세션 복원(=로그인
    // 상태 확정) 직후, 로그인 사용자에 한해 로컬 JeontongProfileStore 값을
    // 서버 UserProfile로 1회 옮긴다. 조건은 함수 내부에서 전부 판단하므로
    // (비로그인/이미 서버 데이터 있음/로컬 데이터 없음이면 아무 것도 하지
    // 않음) 매 부팅마다 안전하게 호출할 수 있다(멱등). 실패해도 스플래시
    // 화면 전환(아래 라우팅)을 막지 않는다 — fire-and-forget이 아니라 await로
    // 순서를 보장하되, 결과와 무관하게 계속 진행한다.
    if (authProvider.isLoggedIn) {
      final migration = await migrateLocalJeontongProfileToServer(authProvider);
      if (kDebugMode) {
        debugPrint('[신통방통 2단계 마이그레이션] $migration');
      }
    }

    if (!mounted) return;

    // [4차 수정] 모든 부트스트랩/이미지 준비가 끝난 "이 시점"에야 비로소
    // 명시적으로 페이드아웃을 재생하고, 그 애니메이션이 완전히 끝날
    // 때까지 await한 뒤 네비게이션한다. 더 이상 고정된 1.3초 타이머에
    // 의존하지 않으므로, 부트스트랩이 얼마나 걸리든 항상 완성된 화면
    // (히어로 이미지 + 정상 폰트)이 사용자에게 노출된 뒤에 사라진다.
    if (mounted) {
      await _controller.reverse();
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
    // [2026 핸드오프 콘텐츠 반영] fallback 카피가 곧 정확한 핸드오프 원문이므로
    // 서버 config 로드를 기다릴 필요 없이 바로 fallback을 읽어도 안전하다
    // (스플래시는 IntroConfigProvider.load()를 트리거하는 화면 자체이며, 이
    // 첫 프레임 시점엔 아직 로드가 끝나지 않았을 수 있음).
    final config = IntroConfigModel.fallback();
    final subtitleLines = (config.splashSubtitle ?? '').split('\n');

    // [스플래시 풀블리드 개편 - "증명사진 카드처럼 작게 떠 있다" 피드백 반영]
    // 기존 구조는 캐릭터 이미지를 260px 높이의 둥근 카드 하나로 축소해
    // 화면 중앙에 배치하고, 위/아래로 텅 빈 그라데이션 여백이 크게
    // 남아 "동영상 인트로 앞에 뜨는 어색한 화면"으로 보였다(사용자 피드백
    // 스크린샷 참고: 캐릭터가 작은 사진처럼 붙어 있고 위아래 배경만 넓게
    // 비어 있음). 이제는 캐릭터 전신 이미지를 화면 전체를 채우는 배경
    // (Positioned.fill + BoxFit.cover)으로 깔고, 그 위에 그라데이션
    // 스크림을 얹어 텍스트 가독성을 확보한 뒤, eyebrow/타이틀/서브카피/
    // 로딩닷을 이미지 위에 오버레이하는 "풀스크린 히어로" 방식으로
    // 재구성한다. 부트스트랩 로직(_bootstrap, _controller 애니메이션,
    // _heroReady 게이팅)은 전혀 손대지 않고 오직 build()의 레이아웃만
    // 바꾼다.
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 그라데이션(이미지 로딩 전/실패 시에도 항상 깔려 있는 베이스).
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    IntroPalette.backgroundTop,
                    IntroPalette.backgroundBottom,
                  ],
                ),
              ),
            ),
          ),
          // [캐릭터 삭제 — 2026-09-24 사용자 요청] 기존 풀블리드 캐릭터
          // 전신 이미지를 삭제하고 배경 그라데이션만 유지한다.
          // 이미지 위에 얹는 그라데이션 스크림 - 상단은 eyebrow 라벨이
          // 잘 보이도록 살짝 어둡게, 중단은 얼굴이 잘 보이도록 투명하게,
          // 하단은 타이틀/서브카피/로딩닷이 놓일 자리를 배경색에 가깝게
          // 어둡혀 가독성을 확보한다.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99201A3D), // 상단 - 반투명 다크
                    Color(0x00201A3D), // 중단 - 투명(얼굴이 잘 보이도록)
                    Color(0xCC1E1A3A), // 하단 - 텍스트 가독용 다크
                    Color(0xFF1E1A3A), // 최하단 - 배경색과 동일(자연스러운 이음)
                  ],
                  stops: [0.0, 0.32, 0.68, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // eyebrow - 神通萬通 · SINTONG (이미지 위, 화면 최상단)
                    const IntroEyebrowLabel('神通萬通 · SINTONG'),
                    // 캐릭터 얼굴/상반신이 잘 보이도록 중단은 비워둔다
                    // (배경 이미지가 이 공간을 채운다).
                    const Spacer(),
                    // [5차 수정 원칙 유지] 타이틀/서브카피도 폰트 로딩이
                    // 끝난 뒤(_heroReady=true)에만 나타나도록 게이팅한다.
                    AnimatedOpacity(
                      opacity: _heroReady ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        children: [
                          Text(
                            config.splashTitle,
                            textAlign: TextAlign.center,
                            style: IntroTextStyles.title(fontSize: 38),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            subtitleLines.join('\n'),
                            textAlign: TextAlign.center,
                            style: IntroTextStyles.sub(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // 로딩 dot 3개(핸드오프 .load-dot)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _LoadDot(
                            delay: Duration(milliseconds: i * 200),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [핸드오프 반영] `.load-dot` — 스플래시 하단 로딩 점 3개, 순차 pulse 애니메이션.
class _LoadDot extends StatefulWidget {
  final Duration delay;

  const _LoadDot({required this.delay});

  @override
  State<_LoadDot> createState() => _LoadDotState();
}

class _LoadDotState extends State<_LoadDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final opacity = 0.35 + 0.65 * (0.5 - (t - 0.5).abs()) * 2;
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: IntroPalette.primary.withValues(
              alpha: opacity.clamp(0.35, 1.0),
            ),
          ),
        );
      },
    );
  }
}
