// 신통방통 정통사주 v3 — 상세 결과 화면 (4단계 UX ④)
// 상단: 팩트 패널(팔자·지장간·십이운성·신강약·용신·관계·신살)
// 탭1: 선택한 운세의 계산값(data) + 근거(basis) — 서버 실계산 원본
// 탭2: AI 해석 (rule_fallback 상태 배너 포함, /saju/v3/interpret)
//
// [Option 2 이식] 원본은 StatelessWidget + 계산값 탭만 있었으나, 이번 앱
// 통합에서는 해석 탭(jeontong69_interpretation_tab.dart)을 함께 보여주기 위해
// Provider(ChangeNotifier)를 구독하는 StatefulWidget + TabBar로 확장했다.
// (엔진 계산 로직·계약에는 손대지 않음 — 오직 화면 구성만 앱 표준에 맞춤)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/saju_v3_provider.dart';
import '../domain/birth_input.dart';
import '../domain/saju_result_v3.dart';
import 'jeontong_facts_panel.dart';
import 'jeontong69_interpretation_tab.dart';
import 'jeontong69_narrative_tab.dart';
import 'jeontong_v3_theme.dart';
import '../../../home/presentation/widgets/jeontong_easy_term_toggle.dart'
    show JeontongEasyTermToggle;

/// data 안의 동적 키 → 한글 라벨 (미지원 키는 원문 표시)
const kJt3DataLabels = <String, String>{
  'verdict': '판정',
  'note': '메모',
  'reason': '근거',
  'level': '등급',
  'risk_score': '위험도',
  'aggressive_ratio': '공격형 비율(%)',
  'my_zodiac': '내 띠',
  'harmony_zodiac': '궁합 띠',
  'conflict_zodiac': '충돌 띠',
  'wary_zodiac': '주의 띠',
  'complement_element': '보완 오행',
  'caution_element': '과다 오행',
  'core_industries': '기본 업종',
  'support_industries': '보완 업종',
  'officer_count': '관성 개수',
  'officer_years': '관성 발동연',
  'spouse_god_years': '배우자성 발동연',
  'sikshin_years': '식상 발동연',
  'fertile_years': '자녀 인연연',
  'exam_years': '인성 발동연',
  'yeokma_fired': '역마 발동',
  'yeokma_natal': '원국 역마',
  'yeokma_years': '역마 발동연',
  'water_score': '수 오행',
  'earth_score': '토 오행',
  'fire': '화',
  'water': '수',
  'expression_outlet': '식상(배출구)',
  'best_dayun': '최고 대운',
  'worst_dayun': '최악 대운',
  'next_dayun': '다음 대운',
  'next_turn_year': '다음 전환점',
  'turbulence_window': '격변 구간',
  'branch_chong_with_natal': '신대운 충',
  'relations_with_natal': '관계 검출',
  'dayun_zhi': '대운 지지',
  'per_dayun': '대운별 흐름',
  'months': '12개월',
  'week': '이번 주',
  'hours': '12시간대',
  'today_pillar': '오늘 일진',
  'year_pillar': '세운 간지',
  'gan_god': '천간 십신',
  'zhi_god': '지지 십신',
  'child_god_count': '식상 개수',
  'parent_god_count': '인성 개수',
  'sibling_god_count': '비겁 개수',
  'jeongjae': '정재',
  'pyeonjae': '편재',
  'printer_seun': '인성 세운',
  'munchang_seun': '문창 세운',
  'day_element': '일간 오행',
  'birth_season': '태생 계절',
  'constitution': '체질',
  'organ_focus': '주의 장기',
  'luck': '현재 대운',
  'group': '십신 그룹',
};

class Jeontong69DetailScreen extends StatefulWidget {
  final SajuAll69 all;
  final CategoryResultV3 item;
  final BirthInput birth;
  const Jeontong69DetailScreen({
    super.key,
    required this.all,
    required this.item,
    required this.birth,
  });

  @override
  State<Jeontong69DetailScreen> createState() =>
      _Jeontong69DetailScreenState();
}

class _Jeontong69DetailScreenState extends State<Jeontong69DetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // [69종 서사형 해석 — 용어 탭 설명] 결과 화면 진입 시 1회 프리로드.
    JeontongEasyTermToggle.preload();
    // AI 해석 탭 데이터는 진입 시점에 미리 요청해 둔다(탭 전환 시 즉시 표시).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SajuV3Provider>().loadInterpretation(widget.item.code);
      context.read<SajuV3Provider>().loadNarrative(widget.item.code);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facts = widget.all.facts;
    final item = widget.item;
    return Scaffold(
      backgroundColor: Jt3Colors.inkBlack,
      appBar: AppBar(
        backgroundColor: Jt3Colors.inkBlack,
        foregroundColor: Jt3Colors.royalGold,
        title: Text('${item.code} · ${item.name}'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Jt3Colors.royalGold,
          labelColor: Jt3Colors.royalGold,
          unselectedLabelColor: Jt3Colors.moonSilver,
          tabs: const [
            Tab(text: '계산 결과'),
            Tab(text: '해석'),
            Tab(text: '해석(줄글)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFactsTab(facts, item),
          _buildInterpretationTab(item.code),
          _buildNarrativeTab(item.code),
        ],
      ),
    );
  }

  Widget _buildFactsTab(SajuResultV3 facts, CategoryResultV3 item) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Jt3SectionTitle('사주팔자 · 지장간 · 십이운성'),
        Jt3PillarGrid(facts: facts),
        const Jt3SectionTitle('일간 세력 (100점 점수제)'),
        Jt3StrengthBar(strength: facts.strength),
        const Jt3SectionTitle('용신 · 희신 · 기신 · 구신'),
        Jt3YongshinCard(ys: facts.yongshin),
        const Jt3SectionTitle('합 · 충 · 형 · 파 · 해 · 원진'),
        Jt3RelationsChips(relations: facts.relations),
        const Jt3SectionTitle('신살 · 공망'),
        Jt3SinsalRow(sinsal: facts.sinsal, gongmang: facts.gongmang),
        Jt3SectionTitle('운세 결과 — ${item.name}'),
        if (item.hasError)
          Jt3Card(
            child: Text(
              '산출 오류: ${item.error}',
              style: const TextStyle(color: Color(0xFFC62828)),
            ),
          )
        else ...[
          Jt3Card(child: _render(item.data, 0)),
          const SizedBox(height: 10),
          Jt3Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '사용한 계산값',
                  style: TextStyle(color: Jt3Colors.antiqueGold, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  item.basis.join(' · '),
                  style: const TextStyle(
                    color: Jt3Colors.moonSilver,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInterpretationTab(String categoryCode) {
    return Consumer<SajuV3Provider>(
      builder: (context, provider, _) {
        final state = provider.interpretStateOf(categoryCode);
        return Container(
          color: Jt3Colors.inkBlack,
          child: Jeontong69InterpretationTab(
            result: state.data,
            loading: state.isLoading,
            error: state.isError ? state.errorMessage : null,
            onRetry: () => provider.retryInterpretation(categoryCode),
          ),
        );
      },
    );
  }

  // [69종 AI 해석 전면 재설계] 서사형(줄글) 탭 — /saju/v3/narrative.
  Widget _buildNarrativeTab(String categoryCode) {
    return Consumer<SajuV3Provider>(
      builder: (context, provider, _) {
        final state = provider.narrativeStateOf(categoryCode);
        return Container(
          color: Jt3Colors.inkBlack,
          child: Jeontong69NarrativeTab(
            result: state.data,
            loading: state.isLoading,
            error: state.isError ? state.errorMessage : null,
            onRetry: () => provider.retryNarrative(categoryCode),
          ),
        );
      },
    );
  }

  // ---- 동적 데이터 렌더러 (depth 0~1) ----
  Widget _render(dynamic v, int depth) {
    if (v is Map<String, dynamic>) {
      final children = <Widget>[];
      v.forEach((k, val) {
        final label = kJt3DataLabels[k] ?? k;
        if (val is Map || val is List) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Jt3Colors.royalGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _render(val, depth + 1),
                ],
              ),
            ),
          );
        } else {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label · ',
                      style: const TextStyle(
                        color: Jt3Colors.moonSilver,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: _str(val),
                      style: const TextStyle(
                        color: Jt3Colors.starWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
    if (v is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in v)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: e is Map<String, dynamic>
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Jt3Colors.charcoal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _render(e, depth + 1),
                    )
                  : Text(
                      '· ${_str(e)}',
                      style: const TextStyle(
                        color: Jt3Colors.starWhite,
                        fontSize: 12,
                      ),
                    ),
            ),
        ],
      );
    }
    return Text(
      _str(v),
      style: const TextStyle(color: Jt3Colors.starWhite, fontSize: 13),
    );
  }

  static String _str(dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? '예' : '아니오';
    return v.toString();
  }
}
