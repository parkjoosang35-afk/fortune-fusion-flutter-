import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode, ValueListenable;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../intro/application/intro_state_provider.dart';
import '../../intro/application/intro_config_provider.dart';
import '../../home/domain/jeontong_local_to_server_migration.dart';
import '../../result_access/domain/pending_result_access_return.dart';
import '../application/auth_provider.dart';

/// [2026-10 스플래시 디자인 교체 — "신통방통" 워드마크 애니메이션]
/// `design_handoff_splash` 핸드오프(`splash.html`)를 그대로 이식한다.
///
/// 배경은 기존 로딩 화면(`sintong.kr/app/`)과 동일한 보라 그라데이션을
/// 유지하고(핸드오프 §4-1, "변경 금지"), 중앙 컨텐츠만 "신통방통" 글자
/// 4개의 3D 플립 → 인장(神通萬通) 4개 팝 → 가는 선 → 영문 스크램블 →
/// 흰 빛 스윕 → 퇴장 순서로 재생되는 약 7.3초짜리 시퀀스로 교체했다.
///
/// [기존 구조 재사용 원칙 유지] 부트스트랩 로직(`_bootstrap` — 세션 복원,
/// 인트로 설정 로드, pending result-access 복원, introSeen 분기)은 과거
/// 여러 차례 버그 수정을 거쳐 안정화된 코드이므로 전혀 손대지 않는다.
/// 오직 `build()`의 시각적 내용만 교체한다.
///
/// [고정 7.3초 애니메이션과 가변 부트스트랩 시간의 통합] 핸드오프 §6은
/// "데이터 로딩은 스플래시와 병렬 진행. 7.3초 전에 끝나도 애니메이션은
/// 끝까지 재생 권장. 로딩이 더 길면 퇴장(6.4s) 직전 최종 상태에서 대기
/// 후 로딩 완료 시 퇴장 실행"을 명시한다. 이를 그대로 구현하기 위해
/// 메인 타임라인 컨트롤러를 "등장(0~6.4s)"과 "퇴장(6.4~7.3s)" 두
/// 구간으로 분리했다: 등장 애니메이션은 즉시 재생을 시작해 6.4s 지점
/// (완성된 워드마크 상태)에서 자동으로 멈추고, 부트스트랩이 끝나는
/// 시점에만 명시적으로 퇴장(0.9s)을 재생한 뒤 네비게이션한다.
///
/// [접근성] `MediaQuery.disableAnimations`(OS의 "모션 줄이기" 설정)가
/// 켜져 있으면 핸드오프 §6 "애니메이션 생략, 최종 상태 즉시 표시,
/// 1.2초 후 종료"를 따른다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// 핸드오프 §5 타임라인 각 요소의 시작 시각(초). 문서의 표를 그대로
/// 상수화했다 — 값 자체를 바꾸지 않아야 "픽셀 단위로 동일하게 구현"
/// 요구사항(§3)을 지킬 수 있다.
class _SplashTiming {
  _SplashTiming._();

  static const double charFlip1 = 0.40;
  static const double charFlip2 = 0.75;
  static const double charFlip3 = 1.10;
  static const double charFlip4 = 1.45;
  static const double charFlipDuration = 2.1;

  static const double settleStart = 2.60;
  static const double settleDuration = 1.2;

  static const double seal1 = 3.00;
  static const double seal2 = 3.12;
  static const double seal3 = 3.24;
  static const double seal4 = 3.36;
  static const double sealDuration = 0.7;

  static const double ruleStart = 3.60;
  static const double ruleDuration = 1.2;

  static const double enFadeStart = 3.70;
  static const double enFadeDuration = 0.3;
  static const double scrambleStart = 3.70;
  static const double scrambleDuration = 1.1;

  static const double sweepLine1Start = 4.60;
  static const double sweepLine2Start = 4.72;
  static const double sweepDuration = 1.6;

  /// 등장 시퀀스가 "완성된 상태"로 멈추는 지점 = 퇴장 시작 지점.
  static const double outroStart = 6.40;
  static const double outroDuration = 0.9;

  // 전체 길이(등장 6.4s + 퇴장 0.9s) = 7.3s — 핸드오프 §1 "총 길이 약
  // 7.3초"와 일치(값 자체는 outroStart + outroDuration로 유도 가능하므로
  // 별도 상수로 두지 않음 — unused_field 경고 방지).
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// 등장 구간(0~6.4s) 전용 컨트롤러. 6.4s 지점에서 자동 정지한 채
  /// "완성된 워드마크" 상태를 부트스트랩이 끝날 때까지 유지한다.
  late final AnimationController _introController;

  /// 퇴장 구간(0.9s) 전용 컨트롤러. 부트스트랩 완료 직후에만 재생한다.
  late final AnimationController _outroController;

  /// OS 모션 줄이기 설정 여부(§6). didChangeDependencies에서 확정한다.
  bool _reduceMotion = false;
  bool _reduceMotionResolved = false;

  // [영문 스크램블 — 핸드오프 §5 키프레임 ⑤] 매 프레임 텍스트를 직접
  // 갱신해야 하므로 Text 위젯 상태를 별도 ValueNotifier로 들고 있다
  // (AnimationController의 리빌드 주기와 분리해 스크램블 글자가 매
  // 프레임 새로 랜덤 선택되도록 하기 위함).
  static const String _finalEnglishText = 'SINTONG BANGTONG';
  static const String _scrambleGlyphs =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#*+/<>';
  final ValueNotifier<String> _englishText = ValueNotifier<String>(
    _finalEnglishText.replaceAll(RegExp(r'\S'), '·'),
  );
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (_SplashTiming.outroStart * 1000).round(),
      ),
    );
    _outroController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (_SplashTiming.outroDuration * 1000).round(),
      ),
    );
    // 영문 스크램블은 매 프레임 랜덤 글자를 다시 뽑아야 하므로, 등장
    // 컨트롤러의 tick에 얹어 진행률을 직접 계산한다(키프레임 ⑤).
    _introController.addListener(_onIntroTick);

    // [스플래시 워드마크 애니메이션 시작] 기존 히어로 이미지/폰트 precache
    // 로직은 전부 제거되었다(핸드오프는 이미지 에셋을 쓰지 않음 — §8).
    // Google Fonts(Black Han Sans/Noto Serif HK/IBM Plex Mono)는 폭이
    // 좁은 텍스트 몇 글자만 그리므로 별도 게이팅 없이 바로 재생해도
    // tofu box가 체감될 정도로 노출되지 않는다(기존 "정통사주 폰트 tofu"
    // 버그는 38px 큰 제목 텍스트였던 것과 다름).
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
      // 핸드오프 §6: 애니메이션 생략, 최종 상태 즉시 표시.
      _introController.value = 1.0;
      _englishText.value = _finalEnglishText;
      return;
    }
    _introController.forward();
  }

  void _onIntroTick() {
    if (_reduceMotion) return;
    final elapsed = _introController.value * _SplashTiming.outroStart;
    if (elapsed < _SplashTiming.scrambleStart) return;
    final p =
        ((elapsed - _SplashTiming.scrambleStart) /
                _SplashTiming.scrambleDuration)
            .clamp(0.0, 1.0);
    final buffer = StringBuffer();
    for (var i = 0; i < _finalEnglishText.length; i++) {
      final ch = _finalEnglishText[i];
      if (ch == ' ' || i / _finalEnglishText.length < p) {
        buffer.write(ch);
      } else {
        buffer.write(_scrambleGlyphs[_random.nextInt(_scrambleGlyphs.length)]);
      }
    }
    _englishText.value = buffer.toString();
  }

  @override
  void dispose() {
    _introController
      ..removeListener(_onIntroTick)
      ..dispose();
    _outroController.dispose();
    _englishText.dispose();
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

    // [핸드오프 §6 "애니메이션은 끝까지 재생 권장"] 부트스트랩이 등장
    // 애니메이션(6.4s)보다 먼저 끝났다면, 등장 애니메이션이 완성 상태에
    // 도달할 때까지 기다린다. reduceMotion이면 §6 "1.2초 후 종료"를 따른다.
    if (_reduceMotion) {
      await Future.delayed(const Duration(milliseconds: 1200));
    } else if (_introController.status != AnimationStatus.completed) {
      await _introController.forward().orCancel.catchError((_) {});
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

    // [핸드오프 §5 퇴장(outro)] 모든 부트스트랩이 끝난 "이 시점"에야
    // 비로소 퇴장(0.9s, 위로 살짝 이동 + 블러 + 페이드아웃)을 재생하고,
    // 끝날 때까지 await한 뒤 네비게이션한다.
    if (!_reduceMotion) {
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
    // [핸드오프 §4-1 "변경 금지"] 기존 로딩 화면(sintong.kr/app/)과 완전히
    // 동일한 보라 그라데이션. 스플래시 → 앱 진입 시 색 변화(깜빡임) 없음.
    return const Scaffold(
      backgroundColor: _SplashColors.bgBottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _SplashColors.bgTop,
                  _SplashColors.bg40,
                  _SplashColors.bg60,
                  _SplashColors.bgBottom,
                ],
                stops: [0.0, 0.4, 0.6, 1.0],
              ),
            ),
          ),
          _SplashMark(),
        ],
      ),
    );
  }
}

/// 핸드오프 §7 디자인 토큰(Colors) 그대로.
class _SplashColors {
  _SplashColors._();

  static const Color bgTop = Color(0xFF3D3568);
  static const Color bg40 = Color(0xFF312A54);
  static const Color bg60 = Color(0xFF282349);
  static const Color bgBottom = Color(0xFF1E1A3A);
  static const Color text = Colors.white;
  static const Color textEn = Color(0xCCFFFFFF); // rgba(255,255,255,.8)
  static const Color seal = Color(0xFFC23A2C);
  static const Color sealText = Color(0xFFFFF8EC);
  static const Color rule = Color(0x99FFFFFF); // rgba(255,255,255,.6) center
}

/// 핸드오프 §5 이징 3종.
class _SplashEase {
  _SplashEase._();

  static const Cubic out = Cubic(.16, 1, .3, 1);
  static const Cubic spring = Cubic(.34, 1.56, .64, 1);
  static const Cubic inout = Cubic(.76, 0, .24, 1);
}

/// 중앙 워드마크 전체(§4 레이아웃: 신통/방통 2줄 → 인장 4개 → 선 →
/// 영문). `_SplashScreenState`가 들고 있는 두 컨트롤러를
/// `InheritedWidget` 없이 단순 생성자 주입으로 전달받는다.
class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_SplashScreenState>()!;
    return Center(
      // 핸드오프 §4: "세로 중앙에서 24px 위로 올림".
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            state._introController,
            state._outroController,
          ]),
          builder: (context, _) {
            final introT = state._introController.value;
            final outroT = state._outroController.value;
            final elapsed = introT * _SplashTiming.outroStart;

            Widget content = Semantics(
              label: '신통방통',
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Wordmark(elapsed: elapsed),
                    const SizedBox(height: 18),
                    _SealRow(elapsed: elapsed),
                    const SizedBox(height: 22),
                    _RuleLine(elapsed: elapsed),
                    const SizedBox(height: 12),
                    _EnglishLabel(
                      elapsed: elapsed,
                      textListenable: state._englishText,
                    ),
                  ],
                ),
              ),
            );

            // 핸드오프 §5 퇴장(outro): opacity 1→0, translateY 0→-10px,
            // scale 1→1.04, blur 0→6px. 퇴장은 등장이 끝난 뒤에만 진행되므로
            // outroT만으로 적용한다.
            if (outroT > 0) {
              final curved = _SplashEase.inout.transform(outroT);
              content = Opacity(
                opacity: (1 - curved).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -10 * curved),
                  child: Transform.scale(
                    scale: 1 + 0.04 * curved,
                    child: content,
                  ),
                ),
              );
            }
            return content;
          },
        ),
      ),
    );
  }
}

/// "신통 / 방통" 2줄, 글자 4개 — 각각 독립적인 3D 플립 등장(키프레임 ①)
/// + 전체 squash(키프레임 ②) + 글자별 빛 스윕(키프레임 ⑥)을 적용한다.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.elapsed});

  final double elapsed;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.blackHanSans(
      fontSize: 62,
      height: 0.98,
      color: _SplashColors.text,
    );
    // 키프레임 ② squash: 0% scale(1,1) → 35% scale(1.04,.96) → 100% scale(1,1).
    final settleP = _progress(
      elapsed,
      _SplashTiming.settleStart,
      _SplashTiming.settleDuration,
    );
    final settleEased = _SplashEase.out.transform(settleP);
    final squash = _squashScale(settleEased);

    return Transform.scale(
      scaleX: squash.$1,
      scaleY: squash.$2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WordmarkLine(
            text: '신통',
            chars: const ['신', '통'],
            charStarts: const [
              _SplashTiming.charFlip1,
              _SplashTiming.charFlip2,
            ],
            sweepStart: _SplashTiming.sweepLine1Start,
            elapsed: elapsed,
            style: style,
          ),
          _WordmarkLine(
            text: '방통',
            chars: const ['방', '통'],
            charStarts: const [
              _SplashTiming.charFlip3,
              _SplashTiming.charFlip4,
            ],
            sweepStart: _SplashTiming.sweepLine2Start,
            elapsed: elapsed,
            style: style,
          ),
        ],
      ),
    );
  }

  /// settle keyframe의 0/35/100% 세 지점을 선형 보간한다.
  (double, double) _squashScale(double t) {
    if (t <= 0.35) {
      final local = t / 0.35;
      return (1 + (1.04 - 1) * local, 1 + (0.96 - 1) * local);
    }
    final local = (t - 0.35) / 0.65;
    return (1.04 + (1 - 1.04) * local, 0.96 + (1 - 0.96) * local);
  }
}

double _progress(double elapsed, double start, double duration) {
  if (duration <= 0) return elapsed >= start ? 1.0 : 0.0;
  return ((elapsed - start) / duration).clamp(0.0, 1.0);
}

/// 워드마크 한 줄(글자 2개) + 그 위에 얹히는 빛 스윕 레이어.
class _WordmarkLine extends StatelessWidget {
  const _WordmarkLine({
    required this.text,
    required this.chars,
    required this.charStarts,
    required this.sweepStart,
    required this.elapsed,
    required this.style,
  });

  final String text;
  final List<String> chars;
  final List<double> charStarts;
  final double sweepStart;
  final double elapsed;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final sweepP = _progress(elapsed, sweepStart, _SplashTiming.sweepDuration);
    return Stack(
      alignment: Alignment.center,
      children: [
        // perspective(600px) 근사 — 3D 플립 글자 행.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < chars.length; i++)
              _FlipChar(
                char: chars[i],
                startAt: charStarts[i],
                elapsed: elapsed,
                style: style,
              ),
          ],
        ),
        if (sweepP > 0 && sweepP < 1)
          IgnorePointer(
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                // 키프레임 ⑥: background-position 120% → -20%, 가운데
                // 90도 사선 하이라이트 밴드(폭 ~16%)가 좌→우로 이동.
                final pos = 1.2 + (-0.2 - 1.2) * sweepP;
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Colors.transparent,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [
                    (pos - 0.08).clamp(0.0, 1.0),
                    pos.clamp(0.0, 1.0),
                    (pos + 0.08).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
              child: Text(text, style: style),
            ),
          ),
      ],
    );
  }
}

/// 글자 1개의 3D 플립 등장 애니메이션(키프레임 ①).
/// 0%: opacity 0, translateY(46px) rotateX(-90deg) scale(.9), blur(10px)
/// 50%: opacity 1
/// 100%: opacity 1, transform none, blur(0)
class _FlipChar extends StatelessWidget {
  const _FlipChar({
    required this.char,
    required this.startAt,
    required this.elapsed,
    required this.style,
  });

  final String char;
  final double startAt;
  final double elapsed;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final p = _progress(elapsed, startAt, _SplashTiming.charFlipDuration);
    final eased = _SplashEase.out.transform(p);
    final opacity = p <= 0
        ? 0.0
        : p < 0.5
        ? (eased * 2).clamp(0.0, 1.0)
        : 1.0;
    final translateY = 46 * (1 - eased);
    final rotateX = (-math.pi / 2) * (1 - eased);
    final scale = 0.9 + 0.1 * eased;
    final blur = 10 * (1 - eased);

    Widget child = Text(char, style: style);
    if (blur > 0.01) {
      child = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      );
    }
    return Opacity(
      opacity: opacity,
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0016) // perspective(≈600px) 근사
          ..translateByDouble(0.0, translateY, 0.0, 1.0)
          ..rotateX(rotateX)
          ..scaleByDouble(scale, scale, 1.0, 1.0),
        child: child,
      ),
    );
  }
}

/// 인장 4개(神 通 萬 通) 가로 배치 — 각자 독립된 팝 애니메이션(키프레임 ③).
class _SealRow extends StatelessWidget {
  const _SealRow({required this.elapsed});

  final double elapsed;

  static const _glyphs = ['神', '通', '萬', '通'];
  static const _starts = [
    _SplashTiming.seal1,
    _SplashTiming.seal2,
    _SplashTiming.seal3,
    _SplashTiming.seal4,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _glyphs.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          _Seal(glyph: _glyphs[i], startAt: _starts[i], elapsed: elapsed),
        ],
      ],
    );
  }
}

/// 인장 1개. 0%: opacity 0, scale(0) rotate(-30deg) → 100%: opacity 1,
/// scale(1) rotate(0) — spring 이징(살짝 튕김).
class _Seal extends StatelessWidget {
  const _Seal({
    required this.glyph,
    required this.startAt,
    required this.elapsed,
  });

  final String glyph;
  final double startAt;
  final double elapsed;

  @override
  Widget build(BuildContext context) {
    final p = _progress(elapsed, startAt, _SplashTiming.sealDuration);
    final eased = _SplashEase.spring.transform(p);
    final opacity = p <= 0 ? 0.0 : 1.0;
    final scale = eased.clamp(0.0, double.infinity);
    final rotate = (-30 * math.pi / 180) * (1 - eased);

    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: rotate,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _SplashColors.seal,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0x8CFFF8EC), // rgba(255,248,236,.55)
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59C23A2C), // rgba(194,58,44,.35)
                  blurRadius: 14,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: Color(0x40000000), // inset 근사(바깥 그림자로 대체)
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              glyph,
              style: GoogleFonts.notoSerifHk(
                fontSize: 16,
                height: 1,
                fontWeight: FontWeight.w900,
                color: _SplashColors.sealText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 가는 선 — 가운데에서 양옆으로 펼쳐짐(키프레임 ④, scaleX 0→1).
class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.elapsed});

  final double elapsed;

  @override
  Widget build(BuildContext context) {
    final p = _progress(
      elapsed,
      _SplashTiming.ruleStart,
      _SplashTiming.ruleDuration,
    );
    final eased = _SplashEase.out.transform(p);
    return Transform.scale(
      scaleX: eased,
      child: Container(
        width: 96,
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              _SplashColors.rule,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// 영문 "SINTONG BANGTONG" — 페이드인 + 스크램블(키프레임 ⑤는
/// `_SplashScreenState._onIntroTick`이 매 프레임 텍스트를 갱신).
class _EnglishLabel extends StatelessWidget {
  const _EnglishLabel({required this.elapsed, required this.textListenable});

  final double elapsed;
  final ValueListenable<String> textListenable;

  @override
  Widget build(BuildContext context) {
    final p = _progress(
      elapsed,
      _SplashTiming.enFadeStart,
      _SplashTiming.enFadeDuration,
    );
    return Opacity(
      opacity: p,
      child: Padding(
        // 핸드오프: letter-spacing .42em 가운데 정렬 보정을 위한
        // padding-left: .42em 근사(11px 폰트 기준 ≈4.6px).
        padding: const EdgeInsets.only(left: 4.6),
        child: ValueListenableBuilder<String>(
          valueListenable: textListenable,
          builder: (context, value, _) {
            return Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                height: 1,
                letterSpacing: 4.62, // 11px * .42em
                color: _SplashColors.textEn,
              ),
            );
          },
        ),
      ),
    );
  }
}
