import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../intro/application/intro_state_provider.dart';
import '../../intro/application/intro_config_provider.dart';
import '../../home/domain/jeontong_local_to_server_migration.dart';
import '../../result_access/domain/pending_result_access_return.dart';
import '../../../core/router/web_share_entry.dart';
import '../application/auth_provider.dart';

/// [스플래시 디자인 교체 — "귀인지도" 브랜드 심볼+워드마크 애니메이션]
/// `design_handoff_gwiinjido_splash` 핸드오프(README.md +
/// reference/Splash.html + reference/gwiin-mark.jsx +
/// assets/gwiinjido-symbol.svg / gwiinjido-wordmark.svg)를 그대로 이식한다.
///
/// [구성 — 핸드오프 §레이아웃] 남색 밤하늘 배경(3겹 그라데이션) 위에 별
/// 44개가 반짝이고, 가운데에 "길을 걷는 5인 + 2명의 귀인(금빛 별) + 정상의
/// 큰 별" 심볼(SVG 원본 그대로 사용)이 위로 살짝 솟아오르며 나타난 뒤,
/// 그 아래 "귀인지도" 워드마크(송명체, '인' 위 작은 금별)가 블러와 함께
/// 페이드인한다. 전체가 완성된 상태로 잠시 머물다 축소스케일+페이드아웃
/// 되며 다음 화면과 같은 색(#0b1532)의 오버레이로 전환된다.
///
/// [기존 구조 재사용 원칙 유지] 부트스트랩 로직(`_bootstrap` — 세션 복원,
/// 인트로 설정 로드, pending result-access 복원, 웹 공유 진입점 분기,
/// introSeen 분기)은 과거 여러 차례 버그 수정을 거쳐 안정화된 코드이므로
/// 전혀 손대지 않는다. 오직 `build()`의 시각적 내용과 애니메이션 타이밍만
/// 교체한다.
///
/// [고정 4.4초 등장과 가변 부트스트랩 시간의 통합] 핸드오프 §로딩 관계는
/// "앱 초기화는 스플래시와 병렬 진행. 4.4초 전에 끝나도 애니메이션은 끝까지
/// 재생(브랜드 노출 보장). 초기화가 더 길면 등장 완료 상태에서 대기 후
/// 완료 시 퇴장 실행"을 명시한다. 이를 그대로 구현하기 위해 메인 타임라인을
/// "등장(0~4.4s, 심볼 솟아오름→워드마크 블러인)"과 "퇴장(1.3s, 그룹
/// 페이드아웃+스케일→전환 오버레이)" 두 구간으로 분리했다: 등장 애니메이션은
/// 즉시 재생을 시작해 4.4s 지점(완성된 심볼+워드마크 상태)에서 자동으로
/// 멈추고, 부트스트랩이 끝나는 시점에만 명시적으로 퇴장을 재생한 뒤
/// 네비게이션한다.
///
/// [접근성] `MediaQuery.disableAnimations`(OS의 "모션 줄이기" 설정)가 켜져
/// 있으면 핸드오프 §접근성 "translate/blur/scale 생략, opacity만 사용,
/// 총 길이 약 2초"를 따른다 — 별 반짝임은 이동/확대가 아닌 은은한 투명도
/// 변화뿐이라 모션 줄이기 대상에서 제외하고 그대로 유지한다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// 핸드오프 §모션 타임라인의 각 요소 시작 시각(초). 문서의 표를 그대로
/// 상수화했다 — 값 자체를 바꾸지 않아야 "픽셀/시간 단위로 동일하게 구현"
/// 요구사항을 지킬 수 있다.
class _SplashTiming {
  _SplashTiming._();

  static const double symbolStart = 0.2;
  static const double symbolDuration = 1.6;

  static const double wordmarkStart = 1.6;
  static const double wordmarkDuration = 1.6;

  /// 등장 시퀀스가 "완성된 상태"로 멈추는 지점 = 퇴장 시작 지점.
  /// (핸드오프 §모션 타임라인 "4.4s 그룹 페이드아웃 시작").
  static const double introBoundary = 4.4;

  /// 퇴장(outro) 내부 상대 타이밍. 그룹 페이드아웃+스케일은 퇴장 시작과
  /// 동시(상대 0s)에 1.0s간, 전환 오버레이는 상대 0.5s 지점(절대 4.9s =
  /// 4.4+0.5)부터 0.8s간 — 즉 퇴장 컨트롤러 전체 길이는
  /// max(1.0, 0.5+0.8) = 1.3s (절대 4.4~5.7s, 핸드오프 "총 길이 약 5.7초"와 일치).
  static const double groupFadeDuration = 1.0;
  static const double overlayDelay = 0.5;
  static const double overlayDuration = 0.8;
  static const double outroTotal = 1.3;

  /// [접근성 §2초] 모션 줄이기 시 등장은 즉시 최종 상태로 점프하고,
  /// 최소 체감 노출 시간만 대기한 뒤 opacity 전용 퇴장(0.6s)을 재생한다.
  static const int reduceMotionHoldMs = 1400;
  static const int reduceMotionOutroMs = 600;
}

/// 핸드오프 §모션 타임라인 이징 2종(CSS cubic-bezier 값 그대로).
class _SplashEase {
  _SplashEase._();

  /// 심볼 솟아오름 / 워드마크 블러인: cubic-bezier(.22,1,.36,1)
  static const Cubic riseIn = Cubic(.22, 1, .36, 1);

  /// 그룹 페이드아웃: cubic-bezier(.4,0,.2,1)
  static const Cubic fadeOut = Cubic(.4, 0, .2, 1);
}

/// 핸드오프 §디자인 토큰 그대로.
class _GjColors {
  _GjColors._();

  static const Color bgTop = Color(0xFF1D2C58);
  static const Color bgMid = Color(0xFF14214A);
  static const Color bgBottom = Color(0xFF0B1532);
  static const Color glowCool = Color(0x248CAAEB); // rgba(140,170,235,.14)
  static const Color glowWarm = Color(0x12D4AF5F); // rgba(212,175,95,.07)
  static const Color ink = Color(0xFFF4EFFF);
  static const Color gold = Color(0xFFF5CF6A);
}

double _progress(double elapsed, double start, double duration) {
  if (duration <= 0) return elapsed >= start ? 1.0 : 0.0;
  return ((elapsed - start) / duration).clamp(0.0, 1.0);
}

/// 핸드오프 §별 필드 시드 랜덤(Lehmer/Park-Miller LCG, seed=11) — JS 원본
/// (`let s=11; r=()=>((s=(s*16807)%2147483647)/2147483647)`)과 완전히
/// 동일한 수열을 생성해, 매 실행마다 별 배치가 동일하게 유지된다.
class _GjStar {
  const _GjStar({
    required this.xPct,
    required this.yPct,
    required this.diameter,
    required this.delay,
  });

  final double xPct;
  final double yPct;
  final double diameter;
  final double delay;
}

List<_GjStar> _generateGjStars() {
  int seed = 11;
  double next() {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  }

  return List.generate(44, (_) {
    final x = next() * 100;
    final y = next() * 95;
    final d = 0.8 + next() * 1.6;
    final delay = next() * 4;
    return _GjStar(xPct: x, yPct: y, diameter: d, delay: delay);
  });
}

/// 핸드오프 §심볼 "작은 금별(귀인 표식)"과 동일한 4-point sparkle 패스
/// (단위 크기, 중심 원점 기준). 원본 경로:
/// `M0,-1 C0.1,-0.18 0.18,-0.1 1,0 C0.18,0.1 0.1,0.18 0,1
///  C-0.1,0.18 -0.18,0.1 -1,0 C-0.18,-0.1 -0.1,-0.18 0,-1Z`
Path _gjSparkleUnitPath() {
  return Path()
    ..moveTo(0, -1)
    ..cubicTo(0.1, -0.18, 0.18, -0.1, 1, 0)
    ..cubicTo(0.18, 0.1, 0.1, 0.18, 0, 1)
    ..cubicTo(-0.1, 0.18, -0.18, 0.1, -1, 0)
    ..cubicTo(-0.18, -0.1, -0.1, -0.18, 0, -1)
    ..close();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// 등장 구간(0~4.4s) 전용 컨트롤러. 4.4s 지점에서 자동 정지한 채
  /// "완성된 심볼+워드마크" 상태를 부트스트랩이 끝날 때까지 유지한다.
  late final AnimationController _introController;

  /// 퇴장 구간(1.3s) 전용 컨트롤러. 부트스트랩 완료 직후에만 재생한다.
  late final AnimationController _outroController;

  /// 배경 별 반짝임 전용 컨트롤러. 등장/퇴장과 무관하게 화면이 떠 있는
  /// 내내 4초 주기로 계속 순환한다(핸드오프 §배경 "즉시 표시, 4s 루프").
  late final AnimationController _starController;

  final List<_GjStar> _stars = _generateGjStars();

  /// OS 모션 줄이기 설정 여부. didChangeDependencies에서 확정한다.
  bool _reduceMotion = false;
  bool _reduceMotionResolved = false;

  /// [폰트 tofu 박스 버그 수정] "귀인지도" 워드마크는 Song Myung
  /// 구글폰트를 쓰는데, 웹에서는 폰트 파일이 네트워크로 비동기 로드된다.
  /// 워드마크 등장 시점(1.6s)에 아직 폰트 다운로드가 끝나지 않으면
  /// 시스템 fallback 글리프("□" tofu 박스, 과거 "정통사주 폰트 tofu"
  /// 버그와 동일 계열)가 노출된다. 폰트 로딩 완료 신호를 별도로 추적해,
  /// 로딩 전에는 워드마크를 아예 그리지 않고(투명) 로딩 완료 후에만
  /// 정상 텍스트로 페이드인시킨다.
  final ValueNotifier<bool> _wordmarkFontReady = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (_SplashTiming.introBoundary * 1000).round(),
      ),
    );
    _outroController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (_SplashTiming.outroTotal * 1000).round(),
      ),
    );
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // [폰트 tofu 박스 버그 수정] Song Myung 폰트 다운로드를 즉시
    // 트리거하고(GoogleFonts.songMyung() 호출 자체가 로드를 시작시킴),
    // 완료될 때까지 기다린 뒤에만 워드마크 렌더링을 허용한다.
    GoogleFonts.songMyung();
    GoogleFonts.pendingFonts().then((_) {
      if (mounted) _wordmarkFontReady.value = true;
    });

    // [스플래시 심볼/워드마크 애니메이션 시작] 핸드오프는 이미지 에셋
    // 대신 SVG(심볼) + 코드로 그린 워드마크를 쓰므로 별도 이미지 precache
    // 로직이 필요 없다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startSequence();
    });

    // [버그 수정 유지] initState 안에서 _bootstrap()을 곧바로 호출하면,
    // 그 안의 AuthProvider.restoreSession()이 첫 await 이전에 동기적으로
    // notifyListeners()를 호출해 "setState() or markNeedsBuild() called
    // during build" assertion을 유발한다. addPostFrameCallback으로 첫
    // 프레임이 끝난 뒤에 실행한다(기존 수정 그대로 보존).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!_reduceMotionResolved || reduce != _reduceMotion) {
      _reduceMotionResolved = true;
      _reduceMotion = reduce;
    }
  }

  void _startSequence() {
    if (_reduceMotion) {
      // 핸드오프 §접근성: translate/blur/scale 생략, 최종 상태 즉시 표시.
      _introController.value = 1.0;
      return;
    }
    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _outroController.dispose();
    _starController.dispose();
    _wordmarkFontReady.dispose();
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
    ]);

    if (!mounted) return;

    // [핸드오프 §로딩 관계 "애니메이션은 끝까지 재생 권장"] 부트스트랩이
    // 등장 애니메이션(4.4s)보다 먼저 끝났다면, 등장 애니메이션이 완성
    // 상태에 도달할 때까지 기다린다. reduceMotion이면 §접근성 "최소 체감
    // 노출 시간"만 대기한다.
    if (_reduceMotion) {
      await Future.delayed(
        const Duration(milliseconds: _SplashTiming.reduceMotionHoldMs),
      );
    } else if (_introController.status != AnimationStatus.completed) {
      await _introController.forward().orCancel.catchError((_) {});
    }

    if (!mounted) return;

    // [귀인지도 2단계 - 로컬 → 서버 1회성 마이그레이션] 세션 복원(=로그인
    // 상태 확정) 직후, 로그인 사용자에 한해 로컬 JeontongProfileStore 값을
    // 서버 UserProfile로 1회 옮긴다. 조건은 함수 내부에서 전부 판단하므로
    // (비로그인/이미 서버 데이터 있음/로컬 데이터 없음이면 아무 것도 하지
    // 않음) 매 부팅마다 안전하게 호출할 수 있다(멱등). 실패해도 스플래시
    // 화면 전환(아래 라우팅)을 막지 않는다 — fire-and-forget이 아니라 await로
    // 순서를 보장하되, 결과와 무관하게 계속 진행한다.
    if (authProvider.isLoggedIn) {
      final migration = await migrateLocalJeontongProfileToServer(authProvider);
      if (kDebugMode) {
        debugPrint('[귀인지도 2단계 마이그레이션] $migration');
      }
    }

    if (!mounted) return;

    // [핸드오프 §모션 타임라인 퇴장] 모든 부트스트랩이 끝난 "이 시점"에야
    // 비로소 퇴장(그룹 페이드아웃+스케일 → 전환 오버레이)을 재생하고,
    // 끝날 때까지 await한 뒤 네비게이션한다.
    if (_reduceMotion) {
      await _outroController
          .animateTo(
            1.0,
            duration: const Duration(
              milliseconds: _SplashTiming.reduceMotionOutroMs,
            ),
            curve: Curves.easeOut,
          )
          .orCancel
          .catchError((_) {});
    } else {
      await _outroController.forward().orCancel.catchError((_) {});
    }

    if (!mounted) return;

    // [결과보기 통합 권한 시스템 v1.0, §7 쿠팡 이동 후 상태 복원] 쿠팡
    // 이동 중 OS가 Flutter 프로세스를 kill해 재부팅된 경우, 여기서 저장된
    // pending 상태를 소비(1회성)해 원래 입력화면으로 직접 복원한다.
    // introSeen 분기보다 먼저 확인해야, 온보딩을 이미 마친 사용자가 쿠팡
    // 도중 프로세스가 죽어도 /intro가 아니라 정확히 원래 화면으로 돌아간다.
    final pendingReturn = await PendingResultAccessReturnStore.consume();
    if (!mounted) return;
    if (pendingReturn != null) {
      Navigator.of(context).pushReplacementNamed(
        pendingReturn.returnRoute,
        arguments: {
          'restoredInput': pendingReturn.userInput,
          if (pendingReturn.contentType == 'compatibility')
            'resumeResultAccess': true,
        },
      );
      return;
    }

    // [웹 공유 "가짜 페이지" 근본 재설계 — 대표 긴급 지시, 2027-02]
    // pendingReturn(쿠팡 이동 복귀)보다 뒤, introSeen 분기보다 먼저
    // 확인한다 — 공유 링크로 들어온 방문자는 온보딩 여부와 무관하게
    // 항상 그 결과 화면으로 바로 가야 하기 때문이다(admin_web이 더
    // 이상 자체 렌더링 페이지를 갖지 않으므로, 이 분기가 없으면 공유
    // 링크 방문자가 볼 수 있는 화면이 전혀 없어진다 —
    // web_share_entry.dart 문서 주석 참고).
    final webShareRoute = webShareEntryRouteFromUrl();
    if (webShareRoute != null) {
      Navigator.of(context).pushReplacementNamed(webShareRoute);
      return;
    }

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
    // [핸드오프 §캔버스] 전체 화면 full-bleed(상태바 영역 포함), 상태바
    // 콘텐츠 스타일 = light(밝은 아이콘) — 어두운 남색 배경 위에서 상태바
    // 아이콘이 보이도록.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _GjColors.bgBottom,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 레이어 1: 기본 선형 그라데이션(위→아래: top 0% / mid 50% /
            // bottom 100%).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_GjColors.bgTop, _GjColors.bgMid, _GjColors.bgBottom],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // 레이어 2+3: 상단 푸른 글로우 + 하단 금빛 글로우(타원형 라디얼).
            const Positioned.fill(child: CustomPaint(painter: _GjGlowPainter())),
            // 별 필드(44개, 시드 고정, 4초 주기 반짝임).
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _starController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _GjStarFieldPainter(
                      stars: _stars,
                      t: _starController.value,
                    ),
                  );
                },
              ),
            ),
            // 중앙 콘텐츠(심볼 + 워드마크) + 퇴장 페이드/스케일.
            Center(
              child: Semantics(
                label: '귀인지도',
                child: ExcludeSemantics(child: _SplashMark(state: this)),
              ),
            ),
            // 전환 오버레이(다음 화면과 동일 색 #0b1532로 덮어 색 끊김 없이 전환).
            AnimatedBuilder(
              animation: _outroController,
              builder: (context, _) {
                final outroElapsed =
                    _outroController.value * _SplashTiming.outroTotal;
                final overlayP = _progress(
                  outroElapsed,
                  _SplashTiming.overlayDelay,
                  _SplashTiming.overlayDuration,
                );
                if (overlayP <= 0) return const SizedBox.shrink();
                return IgnorePointer(
                  child: Opacity(
                    opacity: overlayP,
                    child: const ColoredBox(color: _GjColors.bgBottom),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 핸드오프 §배경 레이어2/3: 타원형 라디얼 글로우 2개.
/// Flutter의 `RadialGradient`는 x/y 반지름을 독립적으로 지정할 수 없어,
/// `dart:ui`의 `Gradient.radial`에 비균등 스케일 행렬(matrix4)을 직접
/// 전달해 CSS `radial-gradient(ellipse ...)`와 동일한 타원형 확산을
/// 재현한다(원점에서 1.0 반경의 원을 (rx,ry)로 스케일하면 반장축이
/// rx/ry인 타원이 된다).
class _GjGlowPainter extends CustomPainter {
  const _GjGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintEllipseGlow(
      canvas,
      size,
      centerFrac: const Offset(0.5, 0.22),
      rxFrac: 0.45, // 90% width → 반장축(半長軸) = 45%
      ryFrac: 0.25, // 50% height → 반장축 = 25%
      color: _GjColors.glowCool,
    );
    _paintEllipseGlow(
      canvas,
      size,
      centerFrac: const Offset(0.5, 1.0),
      rxFrac: 0.35, // 70% width
      ryFrac: 0.175, // 35% height
      color: _GjColors.glowWarm,
    );
  }

  void _paintEllipseGlow(
    Canvas canvas,
    Size size, {
    required Offset centerFrac,
    required double rxFrac,
    required double ryFrac,
    required Color color,
  }) {
    final center = Offset(
      centerFrac.dx * size.width,
      centerFrac.dy * size.height,
    );
    final rx = rxFrac * size.width;
    final ry = ryFrac * size.height;
    if (rx <= 0 || ry <= 0) return;

    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(rx, ry, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);

    final shader = ui.Gradient.radial(
      center,
      1.0,
      [color, color.withAlpha(0)],
      const [0.0, 0.7],
      TileMode.clamp,
      matrix.storage,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GjGlowPainter oldDelegate) => false;
}

/// 핸드오프 §별 필드: 44개 흰 점, seed=11 LCG로 고정 배치, 각각 4초 주기
/// (0-4초 랜덤 delay) opacity 0.15↔0.8 ease-in-out 반짝임.
class _GjStarFieldPainter extends CustomPainter {
  const _GjStarFieldPainter({required this.stars, required this.t});

  final List<_GjStar> stars;

  /// 0..1 (4초 주기 중 현재 위치).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final star in stars) {
      final phase = ((t + star.delay / 4.0) % 1.0);
      // CSS `0%,100%→.15 / 50%→.8` ease-in-out 키프레임과 동등한 코사인
      // 보간: phase 0→opacity .15, phase .5→opacity .8, phase 1→opacity .15.
      final opacity = 0.475 - 0.325 * math.cos(2 * math.pi * phase);
      paint.color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));
      final center = Offset(
        star.xPct / 100 * size.width,
        star.yPct / 100 * size.height,
      );
      canvas.drawCircle(center, star.diameter / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GjStarFieldPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// 중앙 콘텐츠(심볼 + 워드마크) 전체. `_SplashScreenState`가 들고 있는
/// 두 컨트롤러를 생성자 주입으로 전달받는다(InheritedWidget 불필요).
class _SplashMark extends StatelessWidget {
  const _SplashMark({required this.state});

  final _SplashScreenState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([state._introController, state._outroController]),
      builder: (context, _) {
        final introT = state._introController.value;
        final outroT = state._outroController.value;
        final elapsed = introT * _SplashTiming.introBoundary;

        // 핸드오프 §레이아웃: Symbol(224×419.5) + gap(10) + Wordmark(216.6×47.5),
        // flex-column, center 정렬 — 둘 다 동일한 가로 중심축을 공유한다.
        Widget content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GjSymbol(elapsed: elapsed, reduceMotion: state._reduceMotion),
            const SizedBox(height: 10),
            _GjWordmark(
              elapsed: elapsed,
              reduceMotion: state._reduceMotion,
              fontReady: state._wordmarkFontReady,
            ),
          ],
        );

        // 핸드오프 §모션 타임라인 퇴장: opacity 1→0, scale 1→1.02(모션
        // 줄이기 시 scale은 생략하고 opacity만 적용).
        if (outroT > 0) {
          final outroElapsed = outroT * _SplashTiming.outroTotal;
          final groupP = _progress(
            outroElapsed,
            0,
            _SplashTiming.groupFadeDuration,
          );
          final curved = _SplashEase.fadeOut.transform(groupP);
          final scale = state._reduceMotion ? 1.0 : 1 + 0.02 * curved;
          content = Opacity(
            opacity: (1 - curved).clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: content),
          );
        }
        return content;
      },
    );
  }
}

/// 핸드오프 §심볼: 제공된 벡터 에셋(`gwiinjido-symbol.svg`)을 그대로
/// 렌더링한다(원·경로·라디얼 그라데이션만 사용돼 flutter_svg로 안전하게
/// 지원됨). 0.2s 지연 후 1.6s간 opacity 0→1 + translateY 14→0,
/// cubic-bezier(.22,1,.36,1)(핸드오프 §모션 타임라인 ①).
class _GjSymbol extends StatelessWidget {
  const _GjSymbol({required this.elapsed, required this.reduceMotion});

  final double elapsed;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final symbol = SizedBox(
      width: 224,
      height: 419.5,
      child: SvgPicture.asset('assets/images/splash/gwiinjido_symbol.svg'),
    );

    if (reduceMotion) return symbol;

    final p = _progress(
      elapsed,
      _SplashTiming.symbolStart,
      _SplashTiming.symbolDuration,
    );
    final eased = _SplashEase.riseIn.transform(p);
    final opacity = eased.clamp(0.0, 1.0);
    final translateY = 14 * (1 - eased);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(offset: Offset(0, translateY), child: symbol),
    );
  }
}

/// 핸드오프 §워드마크: "귀인지도" 4글자(Song Myung 400, 38pt, 센터 간격
/// 49.4pt) + '인' 위 작은 금별(4-point sparkle). 원본 SVG는 `<text>`
/// 엘리먼트를 쓰지만(폰트 의존), flutter_svg는 커스텀 웹폰트를 자동으로
/// 로드하지 못하므로 동일한 좌표를 `CustomPainter`로 직접 재현한다(SVG
/// viewBox `0 -4 216.6 51.5`의 좌표를 그대로 사용 — 캔버스를 (0,4)만큼
/// 이동시켜 viewBox의 음수 y 오프셋을 보정한다).
/// 1.6s 지연 후 1.6s간 opacity 0→1 + blur 8px→0,
/// cubic-bezier(.22,1,.36,1)(핸드오프 §모션 타임라인 ②).
class _GjWordmark extends StatelessWidget {
  const _GjWordmark({
    required this.elapsed,
    required this.reduceMotion,
    required this.fontReady,
  });

  final double elapsed;
  final bool reduceMotion;
  final ValueListenable<bool> fontReady;

  @override
  Widget build(BuildContext context) {
    // [폰트 tofu 박스 버그 수정] Song Myung 폰트(웹에서 비동기 네트워크
    // 로드) 다운로드가 끝나기 전에는 fallback 글리프(tofu 박스)가 그대로
    // 보이지 않도록, 폰트 준비가 끝날 때까지 이 레이아웃 공간만 확보한 채
    // 아무것도 그리지 않는다.
    return ValueListenableBuilder<bool>(
      valueListenable: fontReady,
      builder: (context, ready, _) {
        if (!ready) {
          return const SizedBox(width: 216.6, height: 51.5);
        }

        final style = GoogleFonts.songMyung(fontSize: 38, color: _GjColors.ink);
        final painted = SizedBox(
          width: 216.6,
          height: 51.5,
          child: CustomPaint(painter: _GjWordmarkPainter(style: style)),
        );

        if (reduceMotion) return painted;

        final p = _progress(
          elapsed,
          _SplashTiming.wordmarkStart,
          _SplashTiming.wordmarkDuration,
        );
        final eased = _SplashEase.riseIn.transform(p);
        final opacity = eased.clamp(0.0, 1.0);
        final blur = (8 * (1 - eased)).clamp(0.0, double.infinity);

        Widget child = painted;
        if (blur > 0.01) {
          child = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: child,
          );
        }
        return Opacity(opacity: opacity, child: child);
      },
    );
  }
}

/// `gwiinjido-wordmark.svg`의 4개 `<text>` x좌표(text-anchor:middle) +
/// 베이스라인 y + '인' 위 작은 별(translate 76.38 1.52, scale 3.23)을
/// 그대로 재현한다.
class _GjWordmarkPainter extends CustomPainter {
  const _GjWordmarkPainter({required this.style});

  final TextStyle style;

  static const _chars = ['귀', '인', '지', '도'];
  static const _centerXs = [34.2, 83.6, 133.0, 182.4];
  static const _baselineY = 41.8;

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox="0 -4 216.6 51.5" → 박스 원점을 (0,4)만큼 이동해 음수 y
    // 오프셋을 보정한다.
    canvas.save();
    canvas.translate(0, 4);

    for (var i = 0; i < _chars.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: _chars[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final baselineOffset =
          tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final dx = _centerXs[i] - tp.width / 2;
      final dy = _baselineY - baselineOffset;
      tp.paint(canvas, Offset(dx, dy));
    }

    // 작은 금별 — SVG: transform="translate(76.38 1.52) scale(3.23)".
    canvas.save();
    canvas.translate(76.38, 1.52);
    canvas.scale(3.23);
    canvas.drawPath(_gjSparkleUnitPath(), Paint()..color = _GjColors.gold);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GjWordmarkPainter oldDelegate) => false;
}
