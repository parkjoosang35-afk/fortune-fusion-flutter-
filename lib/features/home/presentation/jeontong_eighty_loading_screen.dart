// ============================================================
// [운세 섹션 4단계 흐름 - 화면3 · 만세력 계산 로딩]
// 원본: flutter_handoff.zip screens/saju_loading_screen.dart
// (만세력 책 페이지 넘김 애니메이션 + 천간·지지 스트림 + 4단계 순차
// 진행 + 하단 진행바)의 시각 디자인을 100% 재현하되, 이 프로젝트는
// flutter_riverpod/go_router를 쓰지 않으므로 StatefulWidget +
// Navigator + 기존 HanjiColors/HanjiTextStyles 토큰 기반으로 이식한다.
//
// [사용자 명시 요구사항 재확인] "69종중에 1개을 선택을하면 정보창이뜨고
// 사주보기을누르면 로딩창 디자인이 뜨며 다음애 결과페이지가 뜨게" — 이전
// 구현이 이 로딩 화면(화면3) 자체를 완전히 빠뜨리고 목록/입력에서 결과로
// 곧장 점프해 지적을 받았다. 이 파일이 그 누락을 채운다.
//
// [계산 재사용 원칙] 신규 계산 로직을 만들지 않는다 — 이미 검증된
// [jeontongReportCache.getOrBuild]를 애니메이션 진행 중 1회 호출해 결과를
// "미리 데워두고"(warm), 애니메이션이 끝나면 결과 화면으로 넘어간다.
// 결과 화면(JeontongEightyResultScreen)은 동일한 캐시 키로 다시
// getOrBuild()를 호출하므로 캐시 히트로 즉시 렌더링된다(중복 계산 아님 —
// LRU+TTL 캐시가 같은 입력에 대해 항상 같은 결과를 반환하는 순수 함수
// 호출이므로 여러 번 호출해도 부작용이 없다).
//
// [부적게이트 도입 - 총 대기시간 유지] 사용자 확정 답변(Q1)에 따라 이
// 로딩 화면의 총 시간을 8초 → 5초로 줄이고, 애니메이션 완료 후에는
// 결과 화면이 아니라 부적게이트([JeontongEightyMatrix.gateRoute])로
// 넘어간다. 부적게이트가 3초(세션 2번째부터 1.5초)를 추가로 소비하므로
// "만세력 5초(계산 신뢰감) + 게이트 3초(능동 인터랙션) = 총 8초"로 기존과
// 총 대기시간이 동일하게 유지된다. 계산 자체([_startCalculation])는
// 변경하지 않는다 — 이미 이 5초 안에 완료된다.
//
// [게이트 재검증 없음] 이 화면에 도달하는 시점에는 이미
// `navigateWithPassGate()`가 게이트 체크(로그인/프리패스 소비)를 마친
// 상태다. 따라서 이 화면에서 결과 화면으로 넘어갈 때는 게이트를 다시
// 통과시키지 않고(중복 소비 방지) `pushReplacementNamed`로 곧장 이동한다
// (뒤로가기 시 로딩 화면을 건너뛰어 입력/목록 화면으로 바로 돌아가게
// 하기 위해 push가 아닌 replace를 사용).
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/auth/auth_token_store.dart';
import '../data/jeontong_profile_store.dart';
import '../domain/jeontong_eighty_matrix.dart';
import '../domain/jeontong_input.dart';
import '../domain/jeontong_report_cache.dart';
import 'jeontong_design/hanji_background.dart';
import 'jeontong_design/hanji_design_tokens.dart';
import 'jeontong_design/saju_seal.dart';

/// 로딩 화면에 표시할 4단계 — handoff `data/saju_calc_service.dart`의
/// `kCalcSteps`와 라벨을 그대로 재현(신규 개념 추가 없음).
class _CalcStep {
  final String label;
  const _CalcStep(this.label);
}

const List<_CalcStep> _kCalcSteps = [
  _CalcStep('만세력 조회'),
  _CalcStep('사주 원국 배열'),
  _CalcStep('오행 분석'),
  _CalcStep('대운 계산'),
];

class JeontongEightyLoadingScreen extends StatefulWidget {
  const JeontongEightyLoadingScreen({super.key, required this.categoryId});

  /// 결과를 보여줄 카테고리 id(예: 'A01'). null이면(비정상 진입) 애니메이션만
  /// 재생하고 결과 화면으로 넘어가 [JeontongEightyResultScreen]의 자체
  /// "준비 중" 안내를 그대로 보여준다(신규 에러 UI를 만들지 않는다).
  final String? categoryId;

  @override
  State<JeontongEightyLoadingScreen> createState() =>
      _JeontongEightyLoadingScreenState();
}

class _JeontongEightyLoadingScreenState
    extends State<JeontongEightyLoadingScreen>
    with TickerProviderStateMixin {
  // [부적게이트 도입] 8초 → 5초로 축소(뒤이어 부적게이트 3초가 순차
  // 추가되어 총 8초 유지 — 상단 헤더 주석 참고).
  static const _totalDuration = Duration(seconds: 5);

  late final AnimationController _progressCtrl;
  late final AnimationController _pageFlipCtrl;
  late final AnimationController _streamCtrl;

  int _stepIndex = 0;
  bool _navigated = false;
  JeontongInput? _profile;

  String get _userId =>
      (AuthTokenStore.cachedUserIdOrNull ?? AuthTokenStore.fallbackUserId)
          .toString();

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _totalDuration)
      ..forward();
    _pageFlipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _streamCtrl = AnimationController(
      vsync: this,
      duration: HanjiMotion.ganjiStream,
    )..repeat();

    _progressCtrl.addListener(() {
      final t = _progressCtrl.value;
      final newStep = (t * _kCalcSteps.length).floor().clamp(
        0,
        _kCalcSteps.length - 1,
      );
      if (newStep != _stepIndex) {
        setState(() => _stepIndex = newStep);
      }
    });

    _startCalculation();
  }

  Future<void> _startCalculation() async {
    // [계산 재사용] 저장된 프로필을 조회해 결과를 미리 캐시에 데워둔다.
    // 실패해도(프로필 없음/카테고리 없음) 예외를 던지지 않고 그대로 진행
    // — 결과 화면 자체가 이미 null-safe 폴백을 갖고 있다(회귀 없음).
    try {
      final profile = await jeontongProfileStore.get(_userId);
      if (!mounted) return;
      _profile = profile;

      final entry = JeontongEightyMatrix.byId(widget.categoryId ?? '');
      if (entry != null) {
        jeontongReportCache.getOrBuild(
          entry: entry,
          userId: profile != null ? _userId : null,
          birthDateTimeUtc: profile?.birthDateTimeUtc,
          gender: profile?.gender,
          isLunar: profile?.isLunar,
        );
      }
    } catch (_) {
      // 계산 준비 실패는 치명적이지 않다 — 결과 화면이 필요 시 자체적으로
      // 다시 조회/폴백한다.
    }

    // 최소 로딩 시간(애니메이션) 보장 — 위 계산은 순수 동기 함수라
    // 즉시 끝나므로, 애니메이션이 끝날 때까지 대기한다.
    await _progressCtrl.forward().orCancel;
    if (!mounted || _navigated) return;
    _navigated = true;
    // [부적게이트 도입] 결과 화면으로 곧장 가지 않고 부적게이트를 먼저
    // 거친다 — 게이트가 자체적으로 [resultRoute]로 이어간다.
    Navigator.of(context).pushReplacementNamed(
      JeontongEightyMatrix.gateRoute,
      arguments: widget.categoryId,
    );
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pageFlipCtrl.dispose();
    _streamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final birthLabel = _profile == null
        ? '◇ · ◇ · ◇'
        : '${_profile!.birthDateTimeLocal.year} · '
              '${_profile!.birthDateTimeLocal.month.toString().padLeft(2, '0')} · '
              '${_profile!.birthDateTimeLocal.day.toString().padLeft(2, '0')}';

    return Scaffold(
      body: HanjiBackground(
        sigilOpacity: 0.20,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              const MonoLabel(
                '◈ CALCULATING · 03 / 04',
                color: HanjiColors.accent,
              ),
              const SizedBox(height: 8),
              Text(
                '만세력을 펼치고\n사주를 세우는 중',
                textAlign: TextAlign.center,
                style: HanjiTextStyles.display2().copyWith(height: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                '"간절히 원하면, 온 우주가 도와준다"',
                textAlign: TextAlign.center,
                style: HanjiTextStyles.bodySmall().copyWith(fontSize: 12),
              ),
              const SizedBox(height: 24),

              _MansaeryeokBook(
                pageFlipAnimation: _pageFlipCtrl,
                birthLabel: birthLabel,
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HanjiSpacing.xl,
                ),
                child: _GanjiStream(controller: _streamCtrl),
              ),
              const SizedBox(height: HanjiSpacing.xxl),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HanjiSpacing.xl,
                ),
                child: _StepList(activeIndex: _stepIndex),
              ),
              const Spacer(),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HanjiSpacing.xl,
                  0,
                  HanjiSpacing.xl,
                  12,
                ),
                child: AnimatedBuilder(
                  animation: _progressCtrl,
                  builder: (context, _) => Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(HanjiRadii.pill),
                        child: LinearProgressIndicator(
                          value: _progressCtrl.value,
                          minHeight: 3,
                          backgroundColor: HanjiColors.sigil.withValues(
                            alpha: 0.15,
                          ),
                          valueColor: const AlwaysStoppedAnimation(
                            HanjiColors.glow,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      MonoLabel('${(_progressCtrl.value * 100).round()}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 만세력 책 ────────────────────────────────────────────
class _MansaeryeokBook extends StatelessWidget {
  final AnimationController pageFlipAnimation;
  final String birthLabel;

  const _MansaeryeokBook({
    required this.pageFlipAnimation,
    required this.birthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 170,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(-20),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    HanjiColors.glowShadow,
                    HanjiColors.glowShadow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Expanded(child: _BookPage(side: _BookSide.left)),
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF4A2F15),
                      Color(0xFF8B5A2B),
                      Color(0xFF4A2F15),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: pageFlipAnimation,
                  builder: (context, child) {
                    final t = pageFlipAnimation.value;
                    double angle = 0;
                    if (t > 0.4 && t < 0.6) {
                      angle = -0.44;
                    } else if (t < 0.4) {
                      angle = -0.44 * (t / 0.4);
                    } else {
                      angle = -0.44 * (1 - (t - 0.6) / 0.4);
                    }
                    return Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      child: child,
                    );
                  },
                  child: const _BookPage(side: _BookSide.right),
                ),
              ),
            ],
          ),
          Positioned(
            top: -14,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [MonoLabel('MANSAERYEOK'), MonoLabel('萬歲曆')],
            ),
          ),
          Positioned(
            bottom: -18,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [MonoLabel(birthLabel), const MonoLabel('p. 214')],
            ),
          ),
        ],
      ),
    );
  }
}

enum _BookSide { left, right }

class _BookPage extends StatelessWidget {
  final _BookSide side;
  const _BookPage({required this.side});

  @override
  Widget build(BuildContext context) {
    final columns = side == _BookSide.left
        ? const [
            ['壬', '申', '年'],
            ['丁', '未', '月'],
            ['癸', '酉', '日'],
            ['丁', '巳', '時'],
          ]
        : const [
            ['◇', '◇', '◇'],
            ['壬', '申', '年'],
            ['丁', '未', '月'],
            ['◇', '◇', '◇'],
          ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3E5C3), Color(0xFFE8D5A3)],
        ),
        borderRadius: BorderRadius.horizontal(
          left: side == _BookSide.left ? const Radius.circular(3) : Radius.zero,
          right: side == _BookSide.right
              ? const Radius.circular(3)
              : Radius.zero,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        textDirection: TextDirection.rtl,
        children: columns.map((col) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: col.map((ch) {
              final isMarker = ch == '年' || ch == '月' || ch == '日' || ch == '時';
              final isDiamond = ch == '◇';
              return Container(
                width: 18,
                height: 24,
                margin: const EdgeInsets.only(top: 4),
                alignment: Alignment.center,
                decoration: isMarker
                    ? const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x404A2F15)),
                        ),
                      )
                    : null,
                child: Text(
                  ch,
                  style:
                      HanjiTextStyles.display1(
                        color: isDiamond
                            ? const Color(0x598B5A2B)
                            : (isMarker
                                  ? const Color(0x8C4A2F15)
                                  : const Color(0xFF2A1F14)),
                      ).copyWith(
                        fontSize: isMarker ? 11 : 16,
                        fontWeight: isMarker
                            ? FontWeight.w400
                            : FontWeight.w900,
                      ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 천간·지지 스트림 ───────────────────────────────────
class _GanjiStream extends StatelessWidget {
  final AnimationController controller;
  const _GanjiStream({required this.controller});

  static const _gan = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
  static const _ji = [
    '子',
    '丑',
    '寅',
    '卯',
    '辰',
    '巳',
    '午',
    '未',
    '申',
    '酉',
    '戌',
    '亥',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HanjiColors.sigil.withValues(alpha: 0.05),
        border: Border.all(color: HanjiColors.line),
        borderRadius: BorderRadius.circular(HanjiRadii.card - 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              MonoLabel('천간지지 · 60갑자 조합 중'),
              Text(
                '· · ·',
                style: TextStyle(color: HanjiColors.muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _StreamLine(
            chars: _gan,
            controller: controller,
            reverse: false,
            accent: HanjiColors.accent,
          ),
          const SizedBox(height: 4),
          _StreamLine(
            chars: _ji,
            controller: controller,
            reverse: true,
            accent: HanjiColors.glow,
          ),
        ],
      ),
    );
  }
}

class _StreamLine extends StatelessWidget {
  final List<String> chars;
  final AnimationController controller;
  final bool reverse;
  final Color accent;
  const _StreamLine({
    required this.chars,
    required this.controller,
    required this.reverse,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 24,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = reverse ? 1 - controller.value : controller.value;
            return LayoutBuilder(
              builder: (context, cs) {
                final tripled = [...chars, ...chars, ...chars];
                return ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0, 0.15, 0.85, 1],
                  ).createShader(rect),
                  child: Transform.translate(
                    offset: Offset(-t * cs.maxWidth * 0.9, 0),
                    child: Row(
                      children: [
                        for (int i = 0; i < tripled.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              tripled[i],
                              style:
                                  HanjiTextStyles.display1(
                                    color: i % 10 == 3
                                        ? accent
                                        : HanjiColors.fg,
                                  ).copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── 진행 단계 리스트 ───────────────────────────────────
class _StepList extends StatelessWidget {
  final int activeIndex;
  const _StepList({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HanjiColors.card,
        border: Border.all(color: HanjiColors.line),
        borderRadius: BorderRadius.circular(HanjiRadii.card - 2),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _kCalcSteps.length; i++)
            _StepRow(
              step: _kCalcSteps[i],
              state: i < activeIndex
                  ? _StepState.done
                  : i == activeIndex
                  ? _StepState.active
                  : _StepState.pending,
              index: i,
            ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  final _CalcStep step;
  final _StepState state;
  final int index;
  const _StepRow({
    required this.step,
    required this.state,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: state == _StepState.pending ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _StepIcon(state: state),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                step.label,
                style: HanjiTextStyles.bodyTitle().copyWith(
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
            MonoLabel(
              state == _StepState.active
                  ? '계산 중…'
                  : 'STEP ${(index + 1).toString().padLeft(2, '0')}',
              color: state == _StepState.active ? HanjiColors.accent : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final _StepState state;
  const _StepIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == _StepState.done) {
      return Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: HanjiColors.accent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          '✓',
          style: TextStyle(
            color: Color(0xFFFFF9E8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (state == _StepState.active) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(HanjiColors.glow),
        ),
      );
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HanjiColors.line, width: 1.5),
      ),
    );
  }
}
