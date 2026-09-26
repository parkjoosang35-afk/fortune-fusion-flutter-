// [정통사주 69종 결과 화면 리뉴얼 — 6차 지시서] 실제 saju_v3 엔진
// (`/saju/v3/report` 9 PART + `/saju/v3/interpret` 카테고리 심층)를 그대로
// 반영하는 결과 화면 본문.
//
// [절대 원칙 — 사용자 확정]
// 1. 계산엔진/백엔드를 새로 만들지 않는다. 이 위젯은 이미 검증된
//    SajuV3Api.getSajuV3Report()/getSajuV3Interpret() 응답을 그대로
//    렌더링만 한다(값 가공·재계산 없음).
// 2. 화면 어디에도 "AI" 텍스트를 노출하지 않는다("AI 해석", "AI 분석" 등
//    금지). source(rule_fallback/cache/llm)에 따른 안내 문구도 AI라는
//    단어 없이 "확인된 계산 결과" 같은 중립적 표현만 쓴다.
// 3. 이름을 제목/헤더에 적극 사용한다(본문 문장마다 반복하지 않음).
//    이름이 없으면 "회원님"으로 대체한다.
// 4. 9 PART는 69종 전체에 걸쳐 항상 동일하게 노출되는 고정 스켈레톤이다.
//    선택된 카테고리에 대응하는 PART(있으면)는 시각적으로 강조하고, 그
//    PART 카드 안에 카테고리 심층 해석(interpret 결과)을 자연스럽게
//    엮어 넣는다 — "리포트 + AI 카드 하나 붙이기"가 아니라 "하나의
//    완성된 개인 리포트" 전체가 되도록 한다.
// 5. 9 PART 중 어느 것에도 대응하지 않는 카테고리(건강/궁합/개운 아이템
//    20종, [kJeontongCategoryToReportPartNo]가 null)는 9 PART 뒤에
//    별도 "선택 주제 심층 분석" 블록으로 붙인다(옵션 B).
import 'package:flutter/material.dart';

import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/fortune/result_bottom_actions.dart';
import '../../../fortune/saju_v3/domain/interpretation_result.dart';
import '../../../fortune/saju_v3/domain/saju_report.dart';
import '../../domain/jeontong_eighty_matrix.dart';
import '../../domain/jeontong_v3_report_mapping.dart';
import 'hanji_design_tokens.dart';

/// 9 PART 장문 리포트 + 선택 카테고리 심층 해석을 함께 그리는 결과 본문.
///
/// [상태 3분법] reportState/interpretState 둘 다 성공해야 완전한 화면을
/// 그린다. 리포트만 성공하면(해석 실패) 9 PART는 그대로 보여주고 해당
/// PART의 강조만 생략한다(부분 실패에도 전체가 깨지지 않도록 하는 방어적
/// 원칙 — 기존 화면들의 "재계산 없음/절대 안 깨짐" 철학과 동일).
class JeontongV3ReportView extends StatelessWidget {
  const JeontongV3ReportView({
    super.key,
    required this.entry,
    required this.displayName,
    required this.reportState,
    required this.interpretState,
    required this.onRetryReport,
    required this.onRetryInterpret,
    this.onSave,
    this.onShare,
    this.onBrowseOthers,
  });

  final JeontongCategoryEntry entry;

  /// 화면 표시용 이름 — [JeontongInput.normalizedName]이 없으면
  /// 호출부에서 이미 "회원님"으로 정규화해 전달한다.
  final String displayName;

  final LoadState<SajuReportResult> reportState;
  final LoadState<InterpretationResult> interpretState;
  final VoidCallback onRetryReport;
  final VoidCallback onRetryInterpret;

  // [정통사주 69종 결과 화면 리뉴얼 — 6차 지시서] legacy 화면과 동일한
  // 저장/공유/다른 운세 하단 액션. null이면(위젯 테스트 등) 액션 바를
  // 그리지 않는다 — 기존 회귀 없음 원칙과 동일하게 선택적 슬롯으로 둔다.
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onBrowseOthers;

  @override
  Widget build(BuildContext context) {
    if (reportState.isLoading || reportState.isInitial) {
      return const _JeontongV3Loading();
    }
    if (reportState.isError) {
      return _JeontongV3ErrorView(
        message: reportState.errorMessage ?? '알 수 없는 오류',
        onRetry: onRetryReport,
      );
    }

    final report = reportState.data!;
    final focusPartNo = kJeontongCategoryToReportPartNo[entry.id];
    final interpret = interpretState.isSuccess ? interpretState.data : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HanjiSpacing.xl,
        HanjiSpacing.sm,
        HanjiSpacing.xl,
        HanjiSpacing.xxl,
      ),
      children: [
        _JeontongV3StatusNotice(report: report),
        const SizedBox(height: HanjiSpacing.md),
        for (final part in report.report.parts) ...[
          _JeontongV3PartCard(
            part: part,
            displayName: displayName,
            isFocused: focusPartNo == part.no,
            focusInterpret: focusPartNo == part.no ? interpret : null,
            focusInterpretState: focusPartNo == part.no
                ? interpretState
                : null,
            onRetryInterpret: onRetryInterpret,
          ),
          const SizedBox(height: HanjiSpacing.md),
        ],
        if (report.report.summary.isNotEmpty) ...[
          _JeontongV3SummaryCard(
            displayName: displayName,
            summary: report.report.summary,
          ),
          const SizedBox(height: HanjiSpacing.md),
        ],
        // [옵션 B] 9 PART 중 어느 것에도 대응하지 않는 카테고리(건강/궁합/
        // 개운 아이템)는 9 PART 뒤에 별도 블록으로 심층 해석을 붙인다.
        if (focusPartNo == null) ...[
          _JeontongV3StandaloneDeepDive(
            entry: entry,
            displayName: displayName,
            interpretState: interpretState,
            onRetry: onRetryInterpret,
          ),
          const SizedBox(height: HanjiSpacing.md),
        ],
        if (onSave != null || onShare != null || onBrowseOthers != null)
          ResultBottomActions(
            actions: [
              if (onSave != null)
                ResultActionItem(
                  icon: Icons.bookmark_border_rounded,
                  label: '저장',
                  onTap: onSave!,
                ),
              if (onShare != null)
                ResultActionItem(
                  icon: Icons.ios_share_rounded,
                  label: '공유',
                  onTap: onShare!,
                ),
              if (onBrowseOthers != null)
                ResultActionItem(
                  icon: Icons.grid_view_rounded,
                  label: '다른 운세',
                  onTap: onBrowseOthers!,
                ),
            ],
          ),
      ],
    );
  }
}

class _JeontongV3Loading extends StatelessWidget {
  const _JeontongV3Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: HanjiColors.accent),
          const SizedBox(height: HanjiSpacing.md),
          Text(
            '사주를 풀이하고 있어요...',
            style: HanjiTextStyles.body(color: HanjiColors.muted),
          ),
        ],
      ),
    );
  }
}

/// [402/429/네트워크 오류 구분] SajuV3ApiException.message에 실린 문구로
/// 상황을 구분해 사용자에게 정직하게 안내한다 — AI라는 단어는 쓰지 않는다.
class _JeontongV3ErrorView extends StatelessWidget {
  const _JeontongV3ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isFreePass = message.contains('열림패스') || message.contains('프리패스');
    final isRateLimited =
        message.contains('너무 많습니다') || message.contains('rate');
    final title = isFreePass
        ? '열림패스가 필요해요'
        : isRateLimited
        ? '요청이 많아 잠시 기다려야 해요'
        : '사주 풀이를 불러오지 못했어요';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HanjiSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFreePass
                  ? Icons.lock_outline
                  : isRateLimited
                  ? Icons.hourglass_empty
                  : Icons.error_outline,
              color: HanjiColors.accent,
              size: 40,
            ),
            const SizedBox(height: HanjiSpacing.md),
            Text(title, style: HanjiTextStyles.display2()),
            const SizedBox(height: HanjiSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: HanjiTextStyles.body(color: HanjiColors.muted),
            ),
            const SizedBox(height: HanjiSpacing.lg),
            TextButton(
              onPressed: onRetry,
              child: Text(
                '다시 시도',
                style: HanjiTextStyles.body(color: HanjiColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [AI 텍스트 절대 금지] source에 따라 중립적인 문구만 노출한다.
/// - rule_fallback: "확인된 계산 결과로 정리해서 보여드려요" (AI 언급 없음)
/// - cache: "이전에 만든 풀이를 다시 보여드려요"
/// - llm: 아무것도 표시하지 않음(정상 케이스 — 사용자는 이게 기본이라고
///   느껴야 한다. "AI가 만들었다"는 사실이 드러나면 안 된다).
class _JeontongV3StatusNotice extends StatelessWidget {
  const _JeontongV3StatusNotice({required this.report});

  final SajuReportResult report;

  @override
  Widget build(BuildContext context) {
    String? text;
    if (report.isFallback) {
      text = '확인된 사주 계산 결과를 바탕으로 정리해서 보여드려요.';
    } else if (report.isCache) {
      text = '조금 전 풀이해드린 결과를 다시 보여드려요.';
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(HanjiSpacing.md),
      decoration: BoxDecoration(
        color: UnifiedColors.cardBanner,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        border: Border.all(color: UnifiedColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textCaption,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(child: Text(text, style: UnifiedText.caption())),
        ],
      ),
    );
  }
}

/// PART 제목 앞에 이름을 붙여 개인화한다("OOO님의 타고난 성향").
/// PART1(한눈에 보는 나)은 "OOO님의 사주 한눈에 보기"처럼 조금 더 자연스러운
/// 문장으로 다듬는다 — 새 해석이 아니라 제목 문구 조합일 뿐이다.
String _personalizedPartTitle(String displayName, SajuReportPart part) {
  switch (part.no) {
    case 1:
      return '$displayName의 사주, 한눈에 보기';
    case 9:
      return '$displayName의 사주 종합 분석';
    default:
      return '$displayName의 ${part.title}';
  }
}

class _JeontongV3PartCard extends StatelessWidget {
  const _JeontongV3PartCard({
    required this.part,
    required this.displayName,
    required this.isFocused,
    required this.focusInterpret,
    required this.focusInterpretState,
    required this.onRetryInterpret,
  });

  final SajuReportPart part;
  final String displayName;
  final bool isFocused;
  final InterpretationResult? focusInterpret;
  final LoadState<InterpretationResult>? focusInterpretState;
  final VoidCallback onRetryInterpret;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HanjiSpacing.lg),
      decoration: BoxDecoration(
        color: isFocused
            ? HanjiColors.glowShadow
            : HanjiColors.card,
        borderRadius: BorderRadius.circular(HanjiRadii.card),
        border: Border.all(
          color: isFocused ? HanjiColors.glow : HanjiColors.line,
          width: isFocused ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFocused ? HanjiColors.accent : HanjiColors.sigil,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${part.no}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: HanjiSpacing.sm),
              Expanded(
                child: Text(
                  _personalizedPartTitle(displayName, part),
                  style: HanjiTextStyles.display2(),
                ),
              ),
              if (isFocused)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HanjiSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HanjiColors.accent,
                    borderRadius: BorderRadius.circular(HanjiRadii.pill),
                  ),
                  child: const Text(
                    '이번 풀이 핵심',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: HanjiSpacing.sm),
          ...part.paras.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: HanjiSpacing.xs + 2),
              child: Text(
                p,
                style: HanjiTextStyles.body(color: HanjiColors.fg),
              ),
            ),
          ),
          // [핵심 상세 분석 — 카테고리 심층 엮기] 사용자가 탭한 69종
          // 카테고리가 이 PART에 대응할 때만, interpret() 결과를 이 카드
          // 내부에 이어서 자연스럽게 엮는다. 별도 카드로 분리하지 않는다
          // (사용자 지시 — "AI 해석 카드 하나 붙이는 게 아니라 그 개인
          // 리포트 안에서 더 깊게 분석되는 구조").
          if (isFocused) ...[
            const SizedBox(height: HanjiSpacing.md),
            Container(height: 1, color: HanjiColors.line),
            const SizedBox(height: HanjiSpacing.md),
            _JeontongV3FocusDetail(
              interpret: focusInterpret,
              state: focusInterpretState,
              onRetry: onRetryInterpret,
            ),
          ],
        ],
      ),
    );
  }
}

/// 강조된 PART 안에서 interpret() 결과(headline/sections/actions/closing)를
/// 이어 붙이는 "핵심 상세 분석" 소블록.
class _JeontongV3FocusDetail extends StatelessWidget {
  const _JeontongV3FocusDetail({
    required this.interpret,
    required this.state,
    required this.onRetry,
  });

  final InterpretationResult? interpret;
  final LoadState<InterpretationResult>? state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state == null || state!.isLoading || state!.isInitial) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: HanjiSpacing.sm),
          Text(
            '핵심 상세 분석을 준비하고 있어요...',
            style: HanjiTextStyles.body(color: HanjiColors.muted),
          ),
        ],
      );
    }
    if (state!.isError || interpret == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '핵심 상세 분석을 불러오지 못했어요.',
              style: HanjiTextStyles.body(color: HanjiColors.muted),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              '다시 시도',
              style: HanjiTextStyles.body(color: HanjiColors.accent),
            ),
          ),
        ],
      );
    }

    final r = interpret!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '핵심 상세 분석',
          style: HanjiTextStyles.monoSmall(color: HanjiColors.accent),
        ),
        const SizedBox(height: HanjiSpacing.xs),
        if (r.headline.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: HanjiSpacing.sm),
            child: Text(
              r.headline,
              style: HanjiTextStyles.display2(color: HanjiColors.accent),
            ),
          ),
        for (final section in r.sections) ...[
          if (section.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HanjiSpacing.xs),
              child: Text(
                section.title,
                style: HanjiTextStyles.body(
                  color: HanjiColors.fg,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          for (final line in section.body)
            Padding(
              padding: const EdgeInsets.only(
                top: 2,
                bottom: HanjiSpacing.xs,
              ),
              child: Text(
                line,
                style: HanjiTextStyles.body(color: HanjiColors.fg),
              ),
            ),
        ],
        if (r.hasActions) ...[
          const SizedBox(height: HanjiSpacing.xs),
          Text(
            '이런 점을 참고해보세요',
            style: HanjiTextStyles.body(
              color: HanjiColors.fg,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          ...r.actions.map(
            (a) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· '),
                  Expanded(
                    child: Text(
                      a,
                      style: HanjiTextStyles.body(color: HanjiColors.fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (r.hasClosing) ...[
          const SizedBox(height: HanjiSpacing.sm),
          Text(
            r.closing,
            style: HanjiTextStyles.body(
              color: HanjiColors.muted,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

class _JeontongV3SummaryCard extends StatelessWidget {
  const _JeontongV3SummaryCard({
    required this.displayName,
    required this.summary,
  });

  final String displayName;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HanjiSpacing.lg),
      decoration: BoxDecoration(
        color: HanjiColors.bg2,
        borderRadius: BorderRadius.circular(HanjiRadii.card),
        border: Border.all(color: HanjiColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$displayName을 위한 한마디',
            style: HanjiTextStyles.monoSmall(color: HanjiColors.accent),
          ),
          const SizedBox(height: HanjiSpacing.xs),
          Text(
            summary,
            style: HanjiTextStyles.body(
              color: HanjiColors.fg,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// [옵션 B] 9 PART 중 어느 것에도 대응하지 않는 20종(건강/궁합/개운
/// 아이템)을 위한 별도 심층 분석 블록. PART 카드와 시각적으로 동일한
/// 톤을 쓰되, "9 PART 다음에 이어지는 추가 심층"이라는 위치를 명확히
/// 보이도록 살짝 다른 라벨을 쓴다.
class _JeontongV3StandaloneDeepDive extends StatelessWidget {
  const _JeontongV3StandaloneDeepDive({
    required this.entry,
    required this.displayName,
    required this.interpretState,
    required this.onRetry,
  });

  final JeontongCategoryEntry entry;
  final String displayName;
  final LoadState<InterpretationResult> interpretState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HanjiSpacing.lg),
      decoration: BoxDecoration(
        color: HanjiColors.glowShadow,
        borderRadius: BorderRadius.circular(HanjiRadii.card),
        border: Border.all(color: HanjiColors.glow, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$displayName이 선택한 주제 · ${entry.title}',
                  style: HanjiTextStyles.display2(),
                ),
              ),
            ],
          ),
          const SizedBox(height: HanjiSpacing.sm),
          _JeontongV3FocusDetail(
            interpret: interpretState.isSuccess ? interpretState.data : null,
            state: interpretState,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}
