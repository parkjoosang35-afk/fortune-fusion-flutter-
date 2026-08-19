// ============================================================
// [사용자 요청 · 2026 결과 화면 개편 3단계] "친절한 카드형 상세 리포트"
// 표현 계층 위젯.
//
// [배경] 대표님이 다른 사주 앱 캡처 2장 + 본인이 정리한 마크다운 예시를
// 제시하며 "정통사주 69종 다 이런 식으로" 보여달라고 명시적으로 요청함
// (① 한마디요약 → ② 사주구성 한눈에(표) → ③ 성격 → ④ 오행균형(수/화/토/
// 목/금 각각) → ⑤ 강점4개+조심할점4개(신살 포함) → ⑥ 돈·일·관계·건강
// 실용조언 → ⑦ 대운흐름 → ⑧ 최종정리).
//
// [절대 원칙 — 표현 계층만 개선] 이 위젯은 새로운 계산을 전혀 하지 않는다.
// 이미 PHASE1~4가 계산해 [SajuProfile]에 채워둔 값(오행 dominant/deficient,
// 신강신약, 용신/기신, 신살 목록, 대운 목록)과 이미 각 카테고리
// Analyzer/NarrativeGenerator가 산출한 [strengths]/[weaknesses]/
// [practicalGuidance] 문자열을 그대로 "구조화된 섹션"으로 배치만 한다.
// term_translation_layer.dart의 [sinsalPhrase]/[elementMeaningDictionary]도
// 기존 함수를 그대로 재사용한다(신규 사전 없음).
//
// [적용 범위] A01(평생총운)/A03(재물)/A04(직업)/A05(건강)/A06(애정) —
// 구조화된 CategoryAnalysis를 가진 5종에 우선 적용한다(대표님 승인 B안).
// 나머지 64종은 이 위젯을 그대로 재사용할 수 있도록 범용 데이터 클래스
// ([JeontongDeepReportData])로 입력을 추상화해 두었다 — 이후 각 카테고리에
// Analyzer가 보강되면 동일 위젯을 그대로 물려 쓸 수 있다.
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/manseryeok/saju_profile.dart';
import '../../domain/interpretation/term_translation.dart';
import '../../domain/interpretation/term_translation_layer.dart' show sinsalMeanings;
import 'hanji_design_tokens.dart';
import 'saju_seal.dart';

/// [JeontongDeepReportCard]에 넘길 입력을 카테고리 종류와 무관하게
/// 통일하기 위한 순수 데이터 홀더. 계산 로직은 전혀 없다 — 호출부(각
/// 카테고리 결과 화면 배선 코드)가 이미 계산된 값을 채워 넣기만 한다.
class JeontongDeepReportData {
  const JeontongDeepReportData({
    required this.oneLineSummary,
    required this.personalitySentences,
    required this.strengths,
    required this.cautions,
    this.practicalAdvice = const {},
    this.generalGuidance = const [],
    this.daewoonFlow = const [],
    this.finalSummary = const [],
    this.characteristicsTitle = '② 타고난 성격',
  });

  /// ① 한마디 요약 (헤드라인 한 문장).
  final String oneLineSummary;

  /// ③ 성격/타고난 성향 서술 문장들.
  final List<String> personalitySentences;

  /// [카테고리별 제목 커스터마이즈] A01(평생총운)은 '타고난 성격'이 자연
  /// 스럽지만, A03(재물)은 '재물 스타일', A04(직업)는 '일하는 방식',
  /// A05(건강)는 '타고난 체질', A06(애정)은 '연애·결혼 성향'처럼 카테고리
  /// 마다 이 섹션이 다루는 내용이 다르다. 계산 로직은 그대로 두고 표현
  /// 계층에서 제목만 바꾼다(§ 표현 계층 vs 계산 계층 분리 원칙).
  final String characteristicsTitle;

  /// ⑤ 강점 목록(신살 포함, 이미 쉬운 말로 변환된 문장).
  final List<String> strengths;

  /// ⑤ 조심할 점 목록(이미 쉬운 말로 변환된 문장).
  final List<String> cautions;

  /// ⑥ 돈·일·관계·건강 실용 조언 — key는 '돈' | '일' | '관계' | '건강'.
  /// [구조적 차이 처리] 현재 69종은 재물(A03)/직업(A04)/건강(A05)/애정
  /// (A06)이 이미 별도 카테고리로 분리돼 있어, 한 카테고리 안에서 4분야를
  /// 모두 "판단"할 근거 데이터는 없다. 그래서 이 맵은 해당 카테고리가
  /// 실제로 분석한 항목만 채우고(예: A03은 '돈' 한 개), 나머지는 아래
  /// [generalGuidance]로 그 카테고리 고유의 실전 조언 여러 줄을 보여준다.
  final Map<String, String> practicalAdvice;

  /// [신규] 카테고리 자신의 practicalGuidance(이미 계산된 문장들)를 그대로
  /// 나열하는 범용 실전 가이드 섹션. practicalAdvice(4분야 그리드)가 1개
  /// 항목만 채워지는 카테고리(A03/A04/A05/A06)에서 나머지 조언들을 함께
  /// 보여주기 위함 — 새 판단이 아니라 이미 만들어진 문장을 배치만 한다.
  final List<String> generalGuidance;

  /// ⑦ 대운 흐름 한 줄씩(예: "32세(2004)~41세 갑자(甲子) 대운 · 재물운 상승").
  final List<String> daewoonFlow;

  /// ⑧ 최종 정리 문장들.
  final List<String> finalSummary;
}

/// [사용자 요청 스타일] 사주구성표 + 성격 + 오행균형 + 강점/조심점 +
/// 실용조언 + 대운흐름 + 최종정리를 제목이 있는 섹션으로 나눠 그리는
/// 카드형 리포트. [SajuProfile]에서 사주구성표/오행균형 계산 재료를
/// 직접 읽어오고(재계산 없음, 필드 조회만), 나머지는 [JeontongDeepReportData]
/// 로 주입받는다.
class JeontongDeepReportCard extends StatelessWidget {
  const JeontongDeepReportCard({
    super.key,
    required this.profile,
    required this.data,
  });

  final SajuProfile profile;
  final JeontongDeepReportData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _oneLineSummaryCard(),
        const SizedBox(height: HanjiSpacing.md),
        _sectionCard(
          title: '① 사주 구성 한눈에 보기',
          child: _PillarTable(profile: profile),
        ),
        const SizedBox(height: HanjiSpacing.md),
        if (data.personalitySentences.isNotEmpty) ...[
          _sectionCard(
            title: data.characteristicsTitle,
            child: _paragraphs(data.personalitySentences),
          ),
          const SizedBox(height: HanjiSpacing.md),
        ],
        _sectionCard(
          title: '③ 오행 균형 — 목·화·토·금·수',
          child: _FiveElementBalance(profile: profile),
        ),
        const SizedBox(height: HanjiSpacing.md),
        _sectionCard(
          title: '④ 강점과 조심할 점',
          child: _StrengthCautionList(
            strengths: data.strengths,
            cautions: data.cautions,
          ),
        ),
        if (data.practicalAdvice.isNotEmpty) ...[
          const SizedBox(height: HanjiSpacing.md),
          _sectionCard(
            title: '⑤ 돈 · 일 · 관계 · 건강 조언',
            child: _PracticalAdviceGrid(advice: data.practicalAdvice),
          ),
        ],
        if (data.generalGuidance.isNotEmpty) ...[
          const SizedBox(height: HanjiSpacing.md),
          _sectionCard(
            title: '⑤ 실전 가이드',
            child: _paragraphs(data.generalGuidance),
          ),
        ],
        if (data.daewoonFlow.isNotEmpty) ...[
          const SizedBox(height: HanjiSpacing.md),
          _sectionCard(
            title: '⑥ 대운 흐름',
            child: _paragraphs(data.daewoonFlow, numbered: true),
          ),
        ],
        if (data.finalSummary.isNotEmpty) ...[
          const SizedBox(height: HanjiSpacing.md),
          _sectionCard(
            title: '⑦ 최종 정리',
            accent: true,
            child: _paragraphs(data.finalSummary),
          ),
        ],
      ],
    );
  }

  Widget _oneLineSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HanjiSpacing.lg),
      decoration: BoxDecoration(
        color: HanjiColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(HanjiRadii.card),
        border: Border.all(color: HanjiColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SajuSeal(glyph: '解', size: 32),
          const SizedBox(width: HanjiSpacing.md),
          Expanded(
            child: Text(
              data.oneLineSummary,
              style: HanjiTextStyles.bodyTitle(color: HanjiColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    bool accent = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HanjiSpacing.lg),
      decoration: BoxDecoration(
        color: accent ? HanjiColors.card : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(HanjiRadii.card),
        border: Border.all(color: HanjiColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoLabel(title, color: HanjiColors.sigil),
          const SizedBox(height: HanjiSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _paragraphs(List<String> lines, {bool numbered = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : HanjiSpacing.sm),
            child: Text(
              numbered ? '${i + 1}. ${lines[i]}' : lines[i],
              style: HanjiTextStyles.body(),
            ),
          ),
      ],
    );
  }
}

/// ① 사주구성표 — 년/월/일/시 4주를 표 형태(천간/지지/오행)로 보여준다.
/// [SajuProfile.yearPillar]~[hourPillar]를 읽기만 한다(재계산 없음).
class _PillarTable extends StatelessWidget {
  const _PillarTable({required this.profile});
  final SajuProfile profile;

  @override
  Widget build(BuildContext context) {
    final columns = [
      ('시', profile.hourPillar),
      ('일', profile.dayPillar),
      ('월', profile.monthPillar),
      ('년', profile.yearPillar),
    ];
    return Table(
      border: TableBorder.all(color: HanjiColors.line, width: 1),
      children: [
        TableRow(
          decoration: BoxDecoration(color: HanjiColors.card),
          children: [
            for (final c in columns) _cell(c.$1, isHeader: true),
          ],
        ),
        TableRow(
          children: [
            for (final c in columns)
              _cell(
                '${c.$2.stemKr}(${c.$2.stemHanja})',
                color: HanjiColors.wuxingColor(c.$2.stemElement),
                bold: c.$1 == '일',
              ),
          ],
        ),
        TableRow(
          children: [
            for (final c in columns)
              _cell(
                '${c.$2.branchKr}(${c.$2.branchHanja})',
                color: HanjiColors.wuxingColor(c.$2.branchElement),
              ),
          ],
        ),
      ],
    );
  }

  Widget _cell(String text, {bool isHeader = false, Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HanjiSpacing.sm, horizontal: HanjiSpacing.xs),
      child: Center(
        child: Text(
          text,
          style: isHeader
              ? HanjiTextStyles.bodyTitle()
              : HanjiTextStyles.body(color: color).copyWith(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
        ),
      ),
    );
  }
}

/// ③ 오행 균형 — 목/화/토/금/수 5개를 막대 + 쉬운 설명으로 보여준다.
/// [FiveElementsProfile.totalCount]를 조회만 한다(재계산 없음).
class _FiveElementBalance extends StatelessWidget {
  const _FiveElementBalance({required this.profile});
  final SajuProfile profile;

  static const _order = ['목', '화', '토', '금', '수'];

  @override
  Widget build(BuildContext context) {
    final fe = profile.fiveElements;
    final counts = fe?.totalCount ?? const <String, int>{};
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    final dominant = fe?.dominant ?? const <String>[];
    final deficient = fe?.deficient ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final el in _order) ...[
          _elementRow(
            element: el,
            count: counts[el] ?? 0,
            maxCount: maxCount,
            isDominant: dominant.contains(el),
            isDeficient: deficient.contains(el),
          ),
          if (el != _order.last) const SizedBox(height: HanjiSpacing.sm),
        ],
      ],
    );
  }

  Widget _elementRow({
    required String element,
    required int count,
    required int maxCount,
    required bool isDominant,
    required bool isDeficient,
  }) {
    final color = HanjiColors.wuxingColor(element);
    final chain = elementMeaningDictionary[element];
    final ratio = maxCount == 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
    final statusLabel = isDominant ? '넘치는 편' : (isDeficient ? '부족한 편' : '적당함');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            element,
            style: HanjiTextStyles.bodyTitle(color: color),
          ),
        ),
        const SizedBox(width: HanjiSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(HanjiRadii.pill),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: HanjiColors.line,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: HanjiSpacing.sm),
                  Text('$count개 · $statusLabel', style: HanjiTextStyles.bodySmall()),
                ],
              ),
              const SizedBox(height: 2),
              if (chain != null)
                Text(chain.plainKorean, style: HanjiTextStyles.bodySmall()),
            ],
          ),
        ),
      ],
    );
  }
}

/// ④ 강점 4개 + 조심할 점 4개(신살 용어가 섞여 있어도 이미 호출부에서
/// sinsalPhrase 등으로 풀어쓴 완성 문장을 그대로 받는다 — 이 위젯은
/// 배치만 담당).
class _StrengthCautionList extends StatelessWidget {
  const _StrengthCautionList({required this.strengths, required this.cautions});
  final List<String> strengths;
  final List<String> cautions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (strengths.isNotEmpty) ...[
          Text('강점', style: HanjiTextStyles.bodyTitle(color: HanjiColors.crystal)),
          const SizedBox(height: HanjiSpacing.sm),
          for (final s in strengths.take(4)) _bulletLine(s, HanjiColors.crystal, Icons.check_circle_outline_rounded),
        ],
        if (strengths.isNotEmpty && cautions.isNotEmpty)
          const SizedBox(height: HanjiSpacing.md),
        if (cautions.isNotEmpty) ...[
          Text('조심할 점', style: HanjiTextStyles.bodyTitle(color: HanjiColors.accent)),
          const SizedBox(height: HanjiSpacing.sm),
          for (final c in cautions.take(4)) _bulletLine(c, HanjiColors.accent, Icons.error_outline_rounded),
        ],
      ],
    );
  }

  Widget _bulletLine(String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HanjiSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: HanjiSpacing.sm),
          Expanded(child: Text(text, style: HanjiTextStyles.body())),
        ],
      ),
    );
  }
}

/// ⑤ 돈·일·관계·건강 4분야 실용 조언 그리드.
class _PracticalAdviceGrid extends StatelessWidget {
  const _PracticalAdviceGrid({required this.advice});
  final Map<String, String> advice;

  static const _icons = {
    '돈': Icons.payments_outlined,
    '일': Icons.work_outline_rounded,
    '관계': Icons.people_outline_rounded,
    '건강': Icons.favorite_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in advice.entries) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icons[entry.key] ?? Icons.info_outline_rounded, size: 18, color: HanjiColors.sigil),
              const SizedBox(width: HanjiSpacing.sm),
              SizedBox(
                width: 36,
                child: Text(entry.key, style: HanjiTextStyles.bodyTitle()),
              ),
              const SizedBox(width: HanjiSpacing.sm),
              Expanded(child: Text(entry.value, style: HanjiTextStyles.body())),
            ],
          ),
          if (entry.key != advice.keys.last) const SizedBox(height: HanjiSpacing.sm),
        ],
      ],
    );
  }
}

/// [보조 유틸] 신살 이름 목록을 [sinsalPhrase]가 쓰는 사전을 그대로 참조해
/// "이름(한자, 쉬운의미)" 형태의 짧은 라벨로 변환한다(강점/조심점 문장을
/// 만들 때 호출부가 재사용). 재계산 없음 — 사전 조회만.
String sinsalShortLabel(String nameKr) {
  final meaning = sinsalMeanings[nameKr];
  if (meaning == null) return nameKr;
  return '$nameKr(${meaning.easyMeaning})';
}
