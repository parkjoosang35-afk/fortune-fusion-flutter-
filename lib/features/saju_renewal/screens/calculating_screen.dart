import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../data/saju_visual_adapter.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_story_widgets.dart';
import '../widgets/saju_visual_widgets.dart';
import 'analysis_complete_screen.dart';
import 'error_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면③ 분석 중
/// (9단계 세레모니). `design_files/saju/screens-a.jsx`의 `ScreenAnalyze`와
/// `docs/04_모션.md`의 9단계 타이밍 표를 재현한다.
///
/// [절대 금지] 단순 타이머로 N초 후 다음 화면으로 넘어가지 않는다 —
/// 이 화면의 9단계 시각 연출은 STEP(880ms) 리듬으로 "진행"되지만, 실제
/// 화면 전환(다음 화면으로의 Navigator 이동)은 오직
/// [SajuRenewalProvider.status]가 factsReady/storyPreview(성공) 또는
/// error가 되었을 때만 일어난다([_maybeNavigate] — 기존 로직 그대로
/// 유지). 세레모니 타이머가 9단계에 먼저 도달해도 실제 서버 응답이
/// 아직 없으면 "대기" 상태로 머물며(펄스 인디케이터), 응답이 와야만
/// 완료 라벨을 보여주고 다음 화면으로 넘어간다.
///
/// [실제 데이터 사용] 여기서 그리는 원국/오행/음양균형/대운은 가짜
/// 데모 사주가 아니라, 화면②에서 이미 저장된 실제 사용자
/// [UserModel]의 생년월일로 [SajuVisualAdapter]를 호출해 로컬에서
/// 계산한 값이다(기존 `saju_visual_adapter.dart` 설계 의도와 동일 —
/// 02/03/04 화면 공용).
class CalculatingScreen extends StatefulWidget {
  const CalculatingScreen({super.key});

  @override
  State<CalculatingScreen> createState() => _CalculatingScreenState();
}

/// docs/06_카피덱.md C-03-1~10 — 문구를 한 글자도 바꾸지 않고 그대로 사용.
class _StepMeta {
  const _StepMeta(this.en, this.ko);
  final String en;
  final String ko;
}

const List<_StepMeta> _kSteps = [
  _StepMeta('BIRTH INPUT', '태어난 순간을 확인하고 있어요'),
  _StepMeta('FOUR PILLARS', '여덟 글자를 새기고 있어요'),
  _StepMeta('FIVE ELEMENTS', '다섯 기운의 균형을 살피고 있어요'),
  _StepMeta('TEN GODS', '각 자리의 성격을 읽고 있어요'),
  _StepMeta('RELATIONS', '기운이 만나고 부딪히는 자리를 찾고 있어요'),
  _StepMeta('BALANCE', '당신 사주가 필요로 하는 기운을 찾고 있어요'),
  _StepMeta('LUCK CYCLE', '10년마다 바뀌는 바람을 계산하고 있어요'),
  _StepMeta('KEY FACTS', '가장 중요한 특징을 모으고 있어요'),
  _StepMeta('STORY SELECT', '당신의 이야기를 고르고 있어요'),
];

const Map<String, Offset> _kShardPos = {
  'wood': Offset(-156, -34),
  'fire': Offset(-156, 62),
  'earth': Offset(156, 62),
  'metal': Offset(156, -34),
  'water': Offset(0, -124),
};

class _CalculatingScreenState extends State<CalculatingScreen> {
  bool _navigated = false;

  // 세레모니(시각 연출) 전용 로컬 상태 — 실제 화면 전환과는 분리된다.
  int _step = 0; // 0 = 아직 시작 전, 1..9
  int _reveal = 0; // 0~8, 2단계(여덟 글자 새김) 진행도
  bool _ceremonyReachedEnd = false; // 9단계 STEP 시간 도달(= 최소 대기 충족)
  bool _disposed = false;
  SajuVisualProfile? _profile;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _user = user;
    if (user != null && user.birthDate != null) {
      final parts = user.birthDate!.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        final timeUnknown = user.birthTimeUnknown || user.birthTime == null;
        int hour = 0;
        if (!timeUnknown && user.birthTime != null) {
          final t = user.birthTime!.split(':');
          hour = int.tryParse(t.isNotEmpty ? t[0] : '') ?? 0;
        }
        if (y != null && m != null && d != null) {
          _profile = SajuVisualAdapter.build(
            kst: DateTime(y, m, d, hour, 0),
            gender: user.gender ?? 'female',
            isLunar: user.isLunar,
            timeUnknown: timeUnknown,
            referenceDate: DateTime.now(),
            isLeapMonth: user.isLeapMonth,
          );
        }
      }
    }
    _runCeremony();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// STEP(880ms) 리듬으로 1~9단계를 진행한다(docs/04_모션.md §3-4).
  /// 9단계에 도달한 뒤에는 로컬 상태만 "최소 대기 충족"으로 표시할 뿐,
  /// 실제 다음 화면 전환은 여전히 [_maybeNavigate]가 Provider 상태를
  /// 보고 판단한다 — 이 메서드는 Navigator를 호출하지 않는다.
  Future<void> _runCeremony() async {
    await Future.delayed(const Duration(milliseconds: 250));
    for (var s = 1; s <= 9; s++) {
      if (_disposed || !mounted) return;
      setState(() => _step = s);
      if (s == 2) {
        _runReveal();
      }
      await Future.delayed(SajuMotion.step);
    }
    if (_disposed || !mounted) return;
    setState(() => _ceremonyReachedEnd = true);
  }

  /// 2단계 — 여덧 글자를 한 자씩 새긴다(JSX: `(ms-150)/8` 간격).
  Future<void> _runReveal() async {
    setState(() => _reveal = 0);
    final interval = ((SajuMotion.step.inMilliseconds - 150) / 8)
        .clamp(60, SajuMotion.step.inMilliseconds)
        .round();
    for (var r = 1; r <= 8; r++) {
      if (_disposed || !mounted) return;
      await Future.delayed(Duration(milliseconds: interval));
      if (_disposed || !mounted) return;
      setState(() => _reveal = r);
    }
  }

  /// 실제 화면 전환 — [SajuRenewalProvider.status]만을 근거로 판단한다
  /// (기존 로직 그대로 유지, 세레모니 타이머와 무관).
  void _maybeNavigate(SajuRenewalProvider provider) {
    if (_navigated) return;
    if (provider.status == SajuRenewalFlowStatus.storyPreview ||
        provider.status == SajuRenewalFlowStatus.factsReady) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AnalysisCompleteScreen()),
        );
      });
    } else if (provider.status == SajuRenewalFlowStatus.error) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ErrorScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    _maybeNavigate(provider);

    final step = _step.clamp(0, 9);
    final displayStep = step <= 1 ? 1 : step;
    final condense = step >= 9 && _ceremonyReachedEnd;
    final focus = step >= 8;
    final waitingForServer =
        _ceremonyReachedEnd &&
        provider.status != SajuRenewalFlowStatus.factsReady &&
        provider.status != SajuRenewalFlowStatus.storyPreview &&
        provider.status != SajuRenewalFlowStatus.error;
    final noHour = _profile?.timeUnknown ?? (_user?.birthTimeUnknown ?? false);
    final pillars = _profile?.pillars ?? const [null, null, null, null];
    final relations = _profile?.relations ?? const [];
    final elementsWeighted =
        _profile?.elementsWeighted ??
        const {'wood': 0.0, 'fire': 0.0, 'earth': 0.0, 'metal': 0.0, 'water': 0.0};
    final sortedEl = elementsWeighted.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTwo = sortedEl.take(2).map((e) => e.key).toList();
    final maxWeight = elementsWeighted.values.isEmpty
        ? 1.0
        : elementsWeighted.values.reduce((a, b) => a > b ? a : b).clamp(
            0.0001,
            1000,
          );

    return Scaffold(
      body: SajuDarkBase(
        child: SafeArea(
          child: Column(
            children: [
              SajuTopBar(
                title:
                    'ANALYSIS · ${displayStep.toString().padLeft(2, '0')} / 09',
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cx = constraints.maxWidth / 2;
                    final cy = constraints.maxHeight * 0.4;
                    Widget anchored(Offset o, Widget child) {
                      return Positioned(
                        left: cx + o.dx,
                        top: cy + o.dy,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: child,
                        ),
                      );
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 팔괘 오브제 = 진행 인디케이터.
                        anchored(
                          Offset.zero,
                          AnimatedOpacity(
                            opacity: step <= 1 ? 1 : (condense ? 0 : 0.32),
                            duration: const Duration(milliseconds: 1200),
                            child: SajuBagua(
                              size: step <= 1 ? 300 : 360,
                              speedSeconds: step <= 1 ? 30 : 60,
                              lit: step.clamp(0, 8),
                              intensity: 1.1,
                            ),
                          ),
                        ),

                        // 1 · 입력값이 빛점으로 흡수.
                        if (step == 1) ..._buildInputAbsorb(anchored, noHour),

                        // 원국 + 관계선(실데이터, 서버 완료 전엔 로컬 계산값).
                        if (step >= 2)
                          anchored(
                            const Offset(0, -70),
                            AnimatedOpacity(
                              opacity: condense ? 0 : 1,
                              duration: const Duration(milliseconds: 800),
                              child: AnimatedScale(
                                scale: condense ? 0.3 : 1,
                                duration: const Duration(milliseconds: 1200),
                                curve: SajuMotion.easeSj,
                                child: SajuPillarGrid(
                                  pillars: pillars,
                                  cell: 56,
                                  gap: 8,
                                  reveal: step > 2 ? 8 : _reveal,
                                  showRelations: step >= 5,
                                  relations: relations,
                                  dimAll: focus && !condense,
                                ),
                              ),
                            ),
                          ),

                        // 3 · 오행 조각.
                        if (step >= 3)
                          ..._kShardPos.entries.map((entry) {
                            final k = entry.key;
                            final isTop = topTwo.contains(k);
                            final base = entry.value;
                            final pos = focus
                                ? (isTop
                                      ? Offset(k == topTwo.first ? -34 : 34, 0)
                                      : Offset(base.dx * 1.1, base.dy * 1.1))
                                : base;
                            final w = elementsWeighted[k] ?? 0;
                            final sz =
                                18 +
                                (w / maxWeight) * 26 +
                                (focus && isTop ? 18 : 0);
                            return anchored(
                              pos,
                              AnimatedOpacity(
                                opacity: condense
                                    ? 0
                                    : (focus && !isTop ? 0.2 : 1),
                                duration: const Duration(milliseconds: 1000),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 1200),
                                  curve: SajuMotion.easeSj,
                                  child: SajuElementShard(
                                    element: k,
                                    size: sz,
                                    glow: focus && isTop,
                                  ),
                                ),
                              ),
                            );
                          }),

                        // 6 · 음양 균형.
                        if (step >= 6)
                          anchored(
                            const Offset(0, 140),
                            AnimatedOpacity(
                              opacity: focus ? (condense ? 0 : 0.25) : 1,
                              duration: const Duration(milliseconds: 800),
                              child: SajuBalanceGauge(
                                level: _profile?.balanceLevel ?? 2,
                                width: 240,
                              ),
                            ),
                          ),

                        // 7 · 대운 별줄기.
                        if (step >= 7 && (_profile?.luck.isNotEmpty ?? false))
                          anchored(
                            const Offset(0, 230),
                            AnimatedOpacity(
                              opacity: focus ? (condense ? 0 : 0.25) : 1,
                              duration: const Duration(milliseconds: 800),
                              child: SajuLuckStream(
                                luck: _profile!.luck,
                                current: _profile!.luckCurrentIndex,
                                width: 320,
                              ),
                            ),
                          ),

                        // 9 · 봉인된 책으로 응축.
                        anchored(
                          Offset.zero,
                          AnimatedOpacity(
                            opacity: condense ? 1 : 0,
                            duration: const Duration(milliseconds: 1000),
                            child: AnimatedScale(
                              scale: condense ? 1 : 0.4,
                              duration: const Duration(milliseconds: 1000),
                              curve: SajuMotion.easeSj,
                              child: const SajuSealedCard(width: 180, small: true),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // 하단 단계 라벨.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(9, (i) {
                        final active = i + 1 == displayStep;
                        final filled = i + 1 <= displayStep;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: filled ? SajuGold.g300 : SajuText.line,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        key: ValueKey(waitingForServer ? 'wait' : displayStep),
                        children: [
                          Text(
                            waitingForServer
                                ? 'STORY SELECT'
                                : _kSteps[displayStep - 1].en,
                            style: SajuType.mono10,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 26,
                            child: Text(
                              waitingForServer
                                  ? _kSteps.last.ko
                                  : _kSteps[displayStep - 1].ko,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: SajuType.body,
                                fontSize: 17,
                                color: SajuGold.g100,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (waitingForServer) ...[
                      const SizedBox(height: 10),
                      const _PulsingDot(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInputAbsorb(
    Widget Function(Offset, Widget) anchored,
    bool noHour,
  ) {
    final values = <String>[
      _user?.birthDate?.replaceAll('-', '.') ?? '—',
      (_user?.isLunar ?? false) ? '음력' : '양력',
      noHour ? '시간 모름' : (_user?.birthTime ?? '—'),
    ];
    if (_user?.birthPlace != null && _user!.birthPlace!.isNotEmpty) {
      values.add(_user!.birthPlace!);
    }
    const positions = [
      Offset(-120, -140),
      Offset(120, -120),
      Offset(-110, 130),
      Offset(125, 140),
    ];
    return List.generate(values.length, (i) {
      return anchored(
        positions[i],
        Text(values[i], style: SajuType.mono10),
      );
    });
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_controller),
      child: const SizedBox(
        width: 6,
        height: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SajuGold.g300,
          ),
        ),
      ),
    );
  }
}
