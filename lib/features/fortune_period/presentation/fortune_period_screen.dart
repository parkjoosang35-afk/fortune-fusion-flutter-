/// [기간별 운세 — 화면 B] 오늘 · 주간 · 월간 3탭 메인 화면.
///
/// `design_handoff_fortune_v4/design_files/fortune-v2.jsx`의
/// `UnifiedFortune` 공통 구조(기간 → 총평(가장 크게) → 흐름 → 분야별
/// (재물·애정·사업직장) → 주의사항(주간/월간만) → 지난 운세 → 공유)를
/// 백자 팔레트로 그대로 포팅한다. 점수·그래프·과한 카드는 추가하지
/// 않는다(README 절대 원칙 "점수·그래프·과한 카드 없음").
///
/// [서버 연동] `FortunePeriodRepository.fetchCurrent(kind)`가
/// `GET /api/public/fortune-period/{kind}`(get-or-create, 서버가 KST
/// 기준 period_key로 중복 생성을 막는다)를 호출한다. 탭 전환 시에는
/// 재요청하지 않고 화면 진입 시 탭별로 1회만 호출한 결과를 메모리에
/// 캐시해 재사용한다(README §6 "API 호출은 화면 진입당 1회").
library;

import 'package:flutter/material.dart';

import '../data/fortune_period_repository.dart';
import '../domain/fortune_period_model.dart';
import '../theme/fortune_period_theme.dart';
import '../widgets/fortune_common_widgets.dart';
import '../widgets/fortune_seal.dart';
import '../widgets/fortune_sigil.dart';
import 'saju_input_screen.dart';

class FortunePeriodScreen extends StatefulWidget {
  const FortunePeriodScreen({super.key});

  @override
  State<FortunePeriodScreen> createState() => _FortunePeriodScreenState();
}

/// 탭(kind) 1개의 화면 상태 — 화면 진입당 1회만 채워지고 탭 전환 시
/// 재사용된다.
class _TabState {
  bool loaded = false;
  bool loading = false;
  FortunePeriodResult? result;
  String? errorCode;
  String? errorMessage;
  List<FortuneArchiveItem> history = const [];
  bool dialogShown = false;

  // 지난 운세 열람 중 상태(ArchiveList → PastBanner).
  bool viewingPast = false;
  bool loadingPast = false;
  FortunePeriodResult? pastResult;
}

class _FortunePeriodScreenState extends State<FortunePeriodScreen> {
  final _repo = FortunePeriodRepository();
  FortuneKind _tab = FortuneKind.today;

  final Map<FortuneKind, _TabState> _states = {
    for (final k in FortuneKind.values) k: _TabState(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_tab));
  }

  Future<void> _load(FortuneKind kind, {bool force = false}) async {
    final st = _states[kind]!;
    if (st.loaded && !force) return; // 이미 이번 화면 진입에서 가져온 결과 재사용
    setState(() {
      st.loading = true;
      st.errorCode = null;
      st.errorMessage = null;
    });

    final result = await _repo.fetchCurrent(kind);
    if (!mounted) return;

    setState(() {
      st.loading = false;
      if (result.success && result.data != null) {
        st.result = result.data;
        st.loaded = true;
      } else {
        st.errorCode = result.errorCode;
        st.errorMessage = result.errorMessage;
      }
    });

    if (result.success && result.data != null) {
      final d = result.data!;
      _loadHistory(kind);
      // 새 기간 안내창 — 주간/월간, 신규 생성 + 이전 결과 있을 때만, 1회만.
      if (kind != FortuneKind.today &&
          d.isNew &&
          d.hasPrevious &&
          !st.dialogShown) {
        st.dialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showNewPeriodDialog(kind, d);
        });
      }
    } else if (result.errorCode == 'SAJU_REQUIRED') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goRegister();
      });
    }
  }

  Future<void> _loadHistory(FortuneKind kind) async {
    final st = _states[kind]!;
    final res = await _repo.fetchHistory(kind, limit: 6);
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() => st.history = res.data!);
    }
  }

  Future<void> _goRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SajuInputScreen(mode: SajuInputMode.first),
      ),
    );
    if (!mounted) return;
    // 등록 후 전체 탭 상태를 초기화하고 현재 탭부터 다시 조회한다.
    setState(() {
      for (final k in FortuneKind.values) {
        _states[k] = _TabState();
      }
    });
    _load(_tab, force: true);
  }

  Future<void> _openPast(FortuneKind kind, String periodKey) async {
    final st = _states[kind]!;
    if (periodKey == st.result?.periodKey) return; // 현재 기간이면 그대로 둔다
    setState(() => st.loadingPast = true);
    final res = await _repo.fetchPast(kind, periodKey);
    if (!mounted) return;
    setState(() {
      st.loadingPast = false;
      if (res.success && res.data != null) {
        st.pastResult = res.data;
        st.viewingPast = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage ?? '지난 운세를 불러오지 못했습니다.')),
        );
      }
    });
  }

  void _backToCurrent(FortuneKind kind) {
    setState(() {
      _states[kind]!.viewingPast = false;
      _states[kind]!.pastResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FortunePeriodColors.bg1,
      appBar: AppBar(
        backgroundColor: FortunePeriodColors.bg1,
        elevation: 0,
        foregroundColor: FortunePeriodColors.fg,
        title: const Text(
          '운세',
          style: TextStyle(
            fontFamily: FortunePeriodType.serif,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: FortunePeriodColors.fg,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _PeriodTabs(
                value: _tab,
                onChanged: (k) {
                  setState(() => _tab = k);
                  _load(k);
                },
              ),
            ),
            Expanded(child: _buildBody(_tab)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FortuneKind kind) {
    final st = _states[kind]!;

    if (st.loading && !st.loaded) {
      return _LoadingState(kind: kind);
    }
    if (st.errorCode == 'SAJU_REQUIRED') {
      // 등록 화면으로 자동 이동 처리 중 — 짧게 로딩만 보여준다.
      return _LoadingState(kind: kind);
    }
    if (!st.loaded || st.result == null) {
      return _ErrorState(
        message: st.errorMessage ?? '기운이 잠시 닿지 않았어요',
        onRetry: () => _load(kind, force: true),
      );
    }

    final showPast = st.viewingPast && st.pastResult != null;
    final data = showPast ? st.pastResult! : st.result!;

    return RefreshIndicator(
      onRefresh: () => _load(kind, force: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPast)
              _PastBanner(
                kind: kind,
                onCurrent: () => _backToCurrent(kind),
              ),
            if (showPast) const SizedBox(height: 14),
            if (!showPast) _PeriodHeader(result: data),
            if (showPast) _PastPeriodHeader(result: data),
            const SizedBox(height: 22),
            _SummaryCard(result: data),
            const SizedBox(height: 28),
            _FlowSection(kind: kind, flow: data.flow),
            const SizedBox(height: 28),
            _FieldsSection(kind: kind, fields: data.fields),
            if (data.caution != null && data.caution!.isNotEmpty) ...[
              const SizedBox(height: 28),
              _CautionSection(kind: kind, caution: data.caution!),
            ],
            if (!showPast && st.history.isNotEmpty) ...[
              const SizedBox(height: 28),
              _ArchiveSection(
                kind: kind,
                items: st.history,
                currentKey: st.result!.periodKey,
                loading: st.loadingPast,
                onOpen: (periodKey) => _openPast(kind, periodKey),
              ),
            ],
            const SizedBox(height: 28),
            _ShareSection(kind: kind, result: data),
          ],
        ),
      ),
    );
  }

  void _showNewPeriodDialog(FortuneKind kind, FortunePeriodResult data) {
    final isWeek = kind == FortuneKind.week;
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x80140D22),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
            decoration: BoxDecoration(
              color: FortunePeriodColors.bg1,
              borderRadius: BorderRadius.circular(FortunePeriodRadius.xl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FortuneSeal(
                  text: isWeek ? '週' : '月',
                  size: 44,
                  color: FortunePeriodColors.accent,
                ),
                const SizedBox(height: 16),
                Text(
                  isWeek ? 'NEW WEEK' : 'NEW MONTH',
                  style: FortunePeriodType.mono10,
                ),
                const SizedBox(height: 14),
                Text(
                  isWeek
                      ? '새로운 한 주의\n운세가 열렸어요'
                      : '새로운 달의\n운세가 열렸어요',
                  textAlign: TextAlign.center,
                  style: FortunePeriodType.dialogTitle,
                ),
                const SizedBox(height: 10),
                Text(
                  isWeek
                      ? '이번 주 동안 같은 풀이를 언제든 다시 볼 수 있어요'
                      : '이번 달 동안 같은 풀이를 언제든 다시 볼 수 있어요',
                  textAlign: TextAlign.center,
                  style: FortunePeriodType.dialogBody,
                ),
                const SizedBox(height: 20),
                FortunePrimaryButton(
                  label: isWeek ? '☾ 이번 주 운세 보기' : '☾ 이번 달 운세 보기',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(height: 10),
                FortuneGhostButton(
                  label: isWeek ? '지난주 운세 다시 보기' : '지난달 운세 다시 보기',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    final st = _states[kind]!;
                    if (st.history.length > 1) {
                      // history[0]은 보통 현재 기간이므로 그 다음 항목을 연다.
                      final prev = st.history.firstWhere(
                        (it) => it.periodKey != st.result?.periodKey,
                        orElse: () => st.history.first,
                      );
                      _openPast(kind, prev.periodKey);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// `.period-tabs` — 오늘/주간/월간 3지선다 세그먼트.
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.value, required this.onChanged});

  final FortuneKind value;
  final ValueChanged<FortuneKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FortunePeriodRadius.pill),
        color: Colors.white.withValues(alpha: 0.75),
        border: Border.all(color: FortunePeriodColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F5B3FC4),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: FortuneKind.values.map((k) {
          final selected = k == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(k),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    FortunePeriodRadius.pill,
                  ),
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF6B4FD8), FortunePeriodColors.glow],
                        )
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: FortunePeriodColors.glow.withValues(
                              alpha: 0.32,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  k.tabLabel,
                  style: TextStyle(
                    fontFamily: FortunePeriodType.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: selected ? Colors.white : const Color(0xFF3A3048),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// `.v2-period` — 기간 라벨/메인 타이틀/보조 설명.
class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.result});
  final FortunePeriodResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(result.period.label, style: FortunePeriodType.mono10),
        const SizedBox(height: 8),
        Text(
          result.period.main,
          textAlign: TextAlign.center,
          style: FortunePeriodType.periodMain,
        ),
        const SizedBox(height: 5),
        Text(
          result.period.sub,
          textAlign: TextAlign.center,
          style: FortunePeriodType.periodSub,
        ),
      ],
    );
  }
}

/// 과거 결과 열람 시 — `period` 메타가 없으므로(README: 조회 전용) 보관
/// 상태만 간단히 pstamp 형태로 보여준다.
class _PastPeriodHeader extends StatelessWidget {
  const _PastPeriodHeader({required this.result});
  final FortunePeriodResult result;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(FortunePeriodRadius.pill),
          border: Border.all(color: FortunePeriodColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: FortunePeriodColors.glow,
              ),
            ),
            const Text('지난 운세 · 보관된 결과', style: FortunePeriodType.pastBanner),
          ],
        ),
      ),
    );
  }
}

/// `.v2-summary` — 총평 카드(가장 큰 비중). Sigil 배경 + Seal + 2줄 타이틀 +
/// 본문.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result});
  final FortunePeriodResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FortunePeriodRadius.xl),
        border: Border.all(color: const Color(0x244A2FB0)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FortunePeriodColors.summaryGradStart,
            FortunePeriodColors.summaryGradMid,
            FortunePeriodColors.summaryGradEnd,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5B3FC4),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -80,
            child: FortuneSigil(
              size: 240,
              color: FortunePeriodColors.sigil,
              opacity: 0.35,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('총평 · 總評', style: FortunePeriodType.mono10),
                  FortuneSeal(
                    text: result.seal,
                    size: 38,
                    color: FortunePeriodColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: result.titleLine1,
                      style: FortunePeriodType.summaryTitle,
                    ),
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text: result.titleLine2,
                      style: FortunePeriodType.summaryTitleGlow,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(result.summary, style: FortunePeriodType.summaryBody),
            ],
          ),
        ],
      ),
    );
  }
}

/// 섹션 소제목 — `.v2-h` (제목 + 오른쪽으로 뻗는 구분선).
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: FortunePeriodType.sectionHead),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: FortunePeriodColors.line),
        ),
      ],
    );
  }
}

/// `.v2-flow` — 타임라인(오전/오후/저녁 또는 초반/중반/후반 또는
/// 초순/중순/하순).
class _FlowSection extends StatelessWidget {
  const _FlowSection({required this.kind, required this.flow});
  final FortuneKind kind;
  final List<FortuneFlowItem> flow;

  String get _flowLabel {
    switch (kind) {
      case FortuneKind.today:
        return '오늘 하루의 흐름';
      case FortuneKind.week:
        return '이번 주의 흐름';
      case FortuneKind.month:
        return '이번 달의 흐름';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHead(title: _flowLabel),
        const SizedBox(height: 14),
        ...List.generate(flow.length, (i) {
          final item = flow[i];
          final isLast = i == flow.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Column(
                      children: [
                        Transform.rotate(
                          angle: 0.785398, // 45deg
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: FortunePeriodColors.bg1,
                              border: Border.all(
                                color: FortunePeriodColors.glow,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 1,
                              margin: const EdgeInsets.only(top: 4),
                              color: FortunePeriodColors.glow.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(item.t, style: FortunePeriodType.flowName),
                            const SizedBox(width: 8),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(item.text, style: FortunePeriodType.flowText),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// `.v2-fields` — 재물운/애정운/사업·직장운 3종 고정 필드.
class _FieldsSection extends StatelessWidget {
  const _FieldsSection({required this.kind, required this.fields});
  final FortuneKind kind;
  final List<FortuneFieldItem> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHead(title: kind.fieldsSectionTitle),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FortunePeriodRadius.xl),
            border: Border.all(color: FortunePeriodColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D5B3FC4),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(fields.length, (i) {
              final f = fields[i];
              final color = FortunePeriodColors.fieldColor(f.id);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : const Border(
                          top: BorderSide(color: FortunePeriodColors.line),
                        ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        f.glyph,
                        style: TextStyle(
                          fontFamily: FortunePeriodType.serif,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.name, style: FortunePeriodType.fieldName),
                          const SizedBox(height: 4),
                          Text(f.text, style: FortunePeriodType.fieldText),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// `.v2-caution` — 주간/월간만 노출.
class _CautionSection extends StatelessWidget {
  const _CautionSection({required this.kind, required this.caution});
  final FortuneKind kind;
  final List<String> caution;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHead(title: kind.cautionSectionTitle ?? '주의할 점'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: FortunePeriodColors.cautionBg,
            borderRadius: BorderRadius.circular(FortunePeriodRadius.xl),
            border: Border.all(color: FortunePeriodColors.cautionBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: caution.asMap().entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: e.key == caution.length - 1 ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3, right: 6),
                      child: Text(
                        '◇',
                        style: TextStyle(
                          fontSize: 10,
                          color: FortunePeriodColors.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(e.value, style: FortunePeriodType.caution),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// `ArchiveList` — 지난 결과 목록(최대 6건, 최신순). 조회 전용.
class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({
    required this.kind,
    required this.items,
    required this.currentKey,
    required this.loading,
    required this.onOpen,
  });

  final FortuneKind kind;
  final List<FortuneArchiveItem> items;
  final String currentKey;
  final bool loading;
  final ValueChanged<String> onOpen;

  String get _title {
    switch (kind) {
      case FortuneKind.today:
        return '지난 오늘의 운세';
      case FortuneKind.week:
        return '지난 주간운세';
      case FortuneKind.month:
        return '지난 월간운세';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHead(title: _title),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FortunePeriodRadius.xl),
            border: Border.all(color: FortunePeriodColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: items.asMap().entries.map((e) {
              final it = e.value;
              final isCurrent = it.periodKey == currentKey;
              return InkWell(
                onTap: loading ? null : () => onOpen(it.periodKey),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? FortunePeriodColors.glow.withValues(alpha: 0.07)
                        : null,
                    border: e.key == 0
                        ? null
                        : const Border(
                            top: BorderSide(color: FortunePeriodColors.line),
                          ),
                  ),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: -0.1047, // -6deg
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: FortunePeriodColors.accent.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Text(
                            it.seal,
                            style: const TextStyle(
                              fontFamily: FortunePeriodType.serif,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: FortunePeriodColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatWhen(it.createdAt),
                              style: FortunePeriodType.archiveWhen,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              it.title.join(' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FortunePeriodType.archiveTitle,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isCurrent ? '보는 중' : '다시 보기',
                        style: isCurrent
                            ? FortunePeriodType.archiveGo.copyWith(
                                color: FortunePeriodColors.muted,
                              )
                            : FortunePeriodType.archiveGo,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatWhen(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    return '${local.month}.${local.day}';
  }
}

/// `PastBanner` — 지난 운세 열람 중 상단 배너.
class _PastBanner extends StatelessWidget {
  const _PastBanner({required this.kind, required this.onCurrent});
  final FortuneKind kind;
  final VoidCallback onCurrent;

  String get _currentLabel {
    switch (kind) {
      case FortuneKind.today:
        return '오늘의 운세';
      case FortuneKind.week:
        return '이번 주 운세';
      case FortuneKind.month:
        return '이번 달 운세';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FortunePeriodColors.cautionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FortunePeriodColors.cautionBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('지난 운세를 보고 있어요', style: FortunePeriodType.pastBanner),
          GestureDetector(
            onTap: onCurrent,
            child: Text(
              '$_currentLabel로 ›',
              style: FortunePeriodType.pastBanner.copyWith(
                color: FortunePeriodColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.v2-share` — 공유 버튼 + 간단한 공유 카드 미리보기 시트.
class _ShareSection extends StatelessWidget {
  const _ShareSection({required this.kind, required this.result});
  final FortuneKind kind;
  final FortunePeriodResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FortunePrimaryButton(
          label: '☾ 운세 공유하기',
          onPressed: () => _showShareSheet(context),
        ),
        const SizedBox(height: 12),
        const Text(
          '이름과 생년월일은 공유되지 않아요',
          textAlign: TextAlign.center,
          style: FortunePeriodType.noteMono,
        ),
      ],
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            decoration: const BoxDecoration(
              color: FortunePeriodColors.bg1,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: FortunePeriodColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Text(
                  'SHARE · 운세 카드',
                  style: FortunePeriodType.mono10,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  height: 220,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: FortunePeriodColors.line),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FortunePeriodColors.summaryGradStart,
                        FortunePeriodColors.summaryGradMid,
                        FortunePeriodColors.summaryGradEnd,
                      ],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      FortuneSigil(
                        size: 200,
                        color: FortunePeriodColors.sigil,
                        opacity: 0.3,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FortuneSeal(
                              text: result.seal,
                              size: 38,
                              color: FortunePeriodColors.accent,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              result.period.main,
                              style: FortunePeriodType.mono10,
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: result.titleLine1,
                                    style: FortunePeriodType.summaryTitle
                                        .copyWith(fontSize: 20),
                                  ),
                                  const TextSpan(text: '\n'),
                                  TextSpan(
                                    text: result.titleLine2,
                                    style: FortunePeriodType.summaryTitleGlow
                                        .copyWith(fontSize: 20),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '⌖ 신통방통',
                              style: TextStyle(
                                fontFamily: FortunePeriodType.mono,
                                fontSize: 8,
                                letterSpacing: 3,
                                color: FortunePeriodColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ('카카오톡', '◈'),
                    ('인스타그램', '◇'),
                    ('이미지 저장', '↓'),
                    ('링크 복사', '⇆'),
                  ].map((pair) {
                    return _ShareTarget(
                      label: pair.$1,
                      glyph: pair.$2,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('공유 기능은 준비 중이에요')),
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                FortuneGhostButton(
                  label: '닫기',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({
    required this.label,
    required this.glyph,
    required this.onTap,
  });
  final String label;
  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FortunePeriodColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: FortunePeriodColors.line),
            ),
            child: Text(glyph, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: FortunePeriodType.body,
              fontSize: 11,
              color: FortunePeriodColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// `FortuneLoading` — 꺼진 촛불 + 어두운 sigil 로딩 상태.
class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.kind});
  final FortuneKind kind;

  String get _label {
    switch (kind) {
      case FortuneKind.today:
        return '오늘의 기운을';
      case FortuneKind.week:
        return '이번 주의 기운을';
      case FortuneKind.month:
        return '이번 달의 기운을';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FortuneSigil(
                  size: 160,
                  color: FortunePeriodColors.sigil,
                  opacity: 0.3,
                ),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(
                      FortunePeriodColors.glow,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('READING · 점사 중', style: FortunePeriodType.mono10),
          const SizedBox(height: 10),
          Text(
            '$_label\n살피고 있어요',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: FortunePeriodType.serif,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              height: 1.4,
              color: FortunePeriodColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// `FortuneEmpty` — 엔진/네트워크 오류 상태(사주 미입력은 자동 리다이렉트).
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ERROR · 불러오지 못함', style: FortunePeriodType.mono10),
            const SizedBox(height: 14),
            const Text(
              '기운이 잠시\n닿지 않았어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: FortunePeriodType.serif,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.4,
                color: FortunePeriodColors.fg,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: FortunePeriodType.body,
                fontSize: 13.5,
                height: 1.7,
                color: FortunePeriodColors.muted,
              ),
            ),
            const SizedBox(height: 22),
            FortunePrimaryButton(label: '🕯 다시 불러오기', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
