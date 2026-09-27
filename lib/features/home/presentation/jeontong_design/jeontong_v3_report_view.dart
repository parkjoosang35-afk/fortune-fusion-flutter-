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
import '../../../fortune/saju_v3/domain/narrative_result.dart';
import '../../../fortune/saju_v3/domain/saju_report.dart';
import '../../../fortune/saju_v3/presentation/widgets/narrative_term_text.dart';
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
    required this.narrativeState,
    required this.onRetryReport,
    required this.onRetryInterpret,
    required this.onRetryNarrative,
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
  // [버그 수정 — 2026-09-27] 69종 "이야기형(줄글)" 해석
  // (`/saju/v3/narrative`). 강조된 PART 카드 안의 "핵심 상세 분석"에서
  // interpret(4블록 카드형)보다 우선해 이 줄글을 보여준다 — 사용자가
  // 실제로 겪은 문제(관계 구조 JSON 그대로 노출)의 직접적인 수정.
  final LoadState<NarrativeResult> narrativeState;
  final VoidCallback onRetryReport;
  final VoidCallback onRetryInterpret;
  final VoidCallback onRetryNarrative;

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
    // [버그 수정 — 2026-11 "주제에 맞는것만" 재수정] 9-PART는 "평생 총운"
    // 하나를 볼 때만 의미가 있는 고정 스켈레톤이고, 나머지 68종 카테고리는
    // 자기 주제와 무관한 나머지 8개 PART(오행 분포, 십성 배치, 관계 구조
    // 등 JSON 나열 문구 포함)까지 전부 화면에 그대로 노출돼 사용자가 "개판"
    // 이라고 느낀 원인이었다. 이제는 선택한 카테고리에 대응하는 PART
    // 딱 하나만(있으면) 보여주고, 나머지 8개는 화면에 전혀 그리지 않는다.
    // 대응 PART가 없는 카테고리(건강/궁합/개운 아이템)는 9-PART 카드를
    // 아예 하나도 그리지 않고 [_JeontongV3StandaloneDeepDive] 하나만
    // 보여준다. summary(9개 전체를 아우르는 한 문단)도 같은 이유로 뺀다
    // — 주제와 무관한 다른 축 언급이 섞여 들어갈 수 있기 때문이다.
    final focusedPart = focusPartNo == null
        ? null
        : report.report.parts.where((p) => p.no == focusPartNo).firstOrNull;

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
        if (focusedPart != null) ...[
          _JeontongV3PartCard(
            part: focusedPart,
            displayName: displayName,
            isFocused: true,
            focusInterpret: interpret,
            focusInterpretState: interpretState,
            focusNarrativeState: narrativeState,
            onRetryInterpret: onRetryInterpret,
            onRetryNarrative: onRetryNarrative,
          ),
          const SizedBox(height: HanjiSpacing.md),
        ] else ...[
          // [옵션 B] 9 PART 중 어느 것에도 대응하지 않는 카테고리(건강/궁합/
          // 개운 아이템)는 이 카테고리 전용 심층 분석 블록 하나만 보여준다.
          _JeontongV3StandaloneDeepDive(
            entry: entry,
            displayName: displayName,
            interpretState: interpretState,
            narrativeState: narrativeState,
            onRetry: onRetryInterpret,
            onRetryNarrative: onRetryNarrative,
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

/// [6차 지시서 §4] 리포트 최초 로딩 화면. 기존엔 화면 중앙에 스피너만
/// 떠 있다가 데이터가 오면 레이아웃 전체가 한 번에 나타나는 방식이라
/// "텍스트가 갑자기 밀리는" 느낌이 컸다. 실제 완성 화면(상태 배너 +
/// PART 카드 1장)과 같은 모양의 회색 블록을 먼저 그려서, 로딩→완료
/// 전환 시 레이아웃이 그 자리에서 내용만 바뀌듯 자연스럽게 이어지도록
/// 한다(카드 위치·크기가 로딩 단계부터 이미 확정돼 있음).
class _JeontongV3Loading extends StatelessWidget {
  const _JeontongV3Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        HanjiSpacing.xl,
        HanjiSpacing.sm,
        HanjiSpacing.xl,
        HanjiSpacing.xxl,
      ),
      children: [
        // 상태 배너 자리
        const _HanjiSkeletonBox(height: 46, radius: UnifiedTokens.radiusMd),
        const SizedBox(height: HanjiSpacing.md),
        // PART 카드 자리 — 실제 _JeontongV3PartCard와 동일한 패딩으로
        // 카드 테두리 위치를 미리 잡아 둔다.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(HanjiSpacing.lg),
          decoration: BoxDecoration(
            color: HanjiColors.card,
            borderRadius: BorderRadius.circular(HanjiRadii.card),
            border: Border.all(color: HanjiColors.line, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _HanjiSkeletonBox(
                    width: 24,
                    height: 24,
                    radius: 12,
                  ),
                  const SizedBox(width: HanjiSpacing.sm),
                  const Expanded(
                    child: _HanjiSkeletonBox(height: 22, radius: 6),
                  ),
                ],
              ),
              const SizedBox(height: HanjiSpacing.lg),
              const _HanjiSkeletonBox(height: 15, radius: 4),
              const SizedBox(height: HanjiSpacing.sm),
              const _HanjiSkeletonBox(height: 15, radius: 4),
              const SizedBox(height: HanjiSpacing.sm),
              const _HanjiSkeletonBox(
                height: 15,
                width: 220,
                radius: 4,
              ),
              const SizedBox(height: HanjiSpacing.md),
              Container(height: 1, color: HanjiColors.line),
              const SizedBox(height: HanjiSpacing.md),
              const _HanjiSkeletonBox(height: 13, width: 110, radius: 4),
              const SizedBox(height: HanjiSpacing.sm),
              const _HanjiSkeletonBox(height: 15, radius: 4),
              const SizedBox(height: HanjiSpacing.sm),
              const _HanjiSkeletonBox(height: 15, width: 180, radius: 4),
            ],
          ),
        ),
        const SizedBox(height: HanjiSpacing.md),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: HanjiSpacing.sm),
            child: Text(
              '사주를 풀이하고 있어요...',
              style: HanjiTextStyles.body(color: HanjiColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hanji 팔레트 톤에 맞춘 스켈레톤 블록. 공용 [SkeletonBox]는
/// `Theme.of(context).dividerColor`(전역 라이트/다크 테마 기준)를 쓰지만,
/// 이 화면은 항상 고정된 Hanji 크림톤 배경이라 그 색과 맞지 않는다.
/// 애니메이션 로직은 동일하게 유지하고 베이스 컬러만 [HanjiColors.line]
/// 계열로 바꿔 이 화면 배경 위에서 자연스럽게 보이도록 한다.
class _HanjiSkeletonBox extends StatefulWidget {
  const _HanjiSkeletonBox({
    this.width = double.infinity,
    this.height = 16,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<_HanjiSkeletonBox> createState() => _HanjiSkeletonBoxState();
}

class _HanjiSkeletonBoxState extends State<_HanjiSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = 0.35 + 0.3 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: HanjiColors.sigil.withValues(alpha: opacity * 0.5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
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
///
/// [6차 지시서 §4 실측 후 수정]
/// 1) 대비 — 기존 아이콘·문구가 `UnifiedColors.textCaption`(#9A9AA2)을
///    이 배너 배경(`cardBanner` #F2F0FA) 위에 그대로 써서 대비율 2.48:1로
///    WCAG AA 기준(4.5:1)에 크게 못 미쳤다(실측 계산 확인). 전역 상수 값을
///    바꾸면 25곳의 다른 화면에 영향을 주므로, 이 배너 안에서만
///    `UnifiedColors.textSecondary`(#6B6B75, 대비 4.67:1)로 국소 교체.
/// 2) rule_fallback일 때는 폴백이라는 사실을 더 명확히 전달하도록 아이콘을
///    "준비 중" 톤(auto_stories → hourglass_top)으로 바꾸고 문구도 "AI"란
///    말은 여전히 쓰지 않되 "곧 더 자세한 풀이로 갈아드려요"를 덧붙여
///    사용자가 이게 임시 화면임을 알 수 있게 한다(§4 "폴백 응답이 그대로
///    노출되는 경우 절대 금지 — 폴백 배너로 깔끔하게" 요구 반영).
class _JeontongV3StatusNotice extends StatelessWidget {
  const _JeontongV3StatusNotice({required this.report});

  final SajuReportResult report;

  @override
  Widget build(BuildContext context) {
    String? text;
    IconData icon = Icons.auto_stories_rounded;
    if (report.isFallback) {
      text = '확인된 사주 계산 결과를 바탕으로 정리해서 보여드려요. '
          '곧 더 자세한 풀이로 갈아드릴게요.';
      icon = Icons.hourglass_top_rounded;
    } else if (report.isCache) {
      text = '조금 전 풀이해드린 결과를 다시 보여드려요.';
      icon = Icons.auto_stories_rounded;
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
            icon,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textSecondary,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              text,
              style: UnifiedText.caption(color: UnifiedColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// [6차 지시서 §4 "폴백 응답이 그대로 화면에 노출되는 경우 절대 금지"]
/// rule_fallback 리포트의 일부 PART(3 숨겨진 성향·6 인간관계·8 현재 운
/// 등)는 서버가 `f"관계 구조(합충형파해 등): {json.dumps(rel, ...)}"`
/// 처럼 원본 딕셔너리를 그대로 문자열로 박아 보낸다(엔진 쪽 파일이라
/// ai_layer/report_service.py 수정 없이 이 화면에서 방어). 이 함수는
/// "레이블: {json...}" 패턴을 감지해 JSON 중괄호 이후를 잘라내고
/// "계산 결과를 정리 중이에요" 같은 안내로 바꾼다. JSON이 아닌 정상
/// 문장은 그대로 통과시킨다(원본 값 가공/재계산이 아니라 화면 표시
/// 형식만 다듬는 것).
String _humanizeFallbackPara(String p) {
  final braceIdx = p.indexOf('{');
  if (braceIdx <= 0) return p;
  // "레이블: {...}" 형태인지 확인 — 콜론 뒤에 중괄호가 오는 케이스만
  // 대상으로 한다(사람이 쓴 일반 문장에 우연히 '{'가 들어갈 일은
  // 이 리포트 문맥상 없다).
  final head = p.substring(0, braceIdx).trimRight();
  if (!head.endsWith(':')) return p;
  final label = head.substring(0, head.length - 1).trim();
  if (label.isEmpty) return p;
  return '$label 데이터를 계산해 반영했어요(자세한 문장은 곧 업데이트돼요).';
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
    required this.focusNarrativeState,
    required this.onRetryInterpret,
    required this.onRetryNarrative,
  });

  final SajuReportPart part;
  final String displayName;
  final bool isFocused;
  final InterpretationResult? focusInterpret;
  final LoadState<InterpretationResult>? focusInterpretState;
  // [버그 수정 — 2026-09-27] 강조된 PART일 때, 9-PART report의 원본
  // paras(rule_fallback이면 "관계 구조(합충형파해 등): {"liuhe": [], ...}"
  // 같은 JSON 나열 문구)를 사용자에게 그대로 보여주지 않고, 이 카테고리
  // 전용으로 서버가 만들어준 이야기형 줄글(narrative.text)을 우선 노출한다.
  final LoadState<NarrativeResult>? focusNarrativeState;
  final VoidCallback onRetryInterpret;
  final VoidCallback onRetryNarrative;

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
          // [버그 수정 — 2026-09-27] 강조된 카드에서 이야기형(줄글) 해석이
          // 준비돼 있으면, 원본 9-PART paras(rule_fallback이면 JSON을 그대로
          // 문자열로 박은 "관계 구조(합충형파해 등): {"liuhe": [], ...}" 같은
          // 문구)를 사용자에게 노출하지 않고 그 자리에 자연스러운 줄글을
          // 보여준다. 강조되지 않은 카드는 기존과 동일하게 paras 그대로.
          if (isFocused &&
              focusNarrativeState != null &&
              (focusNarrativeState!.isLoading ||
                  focusNarrativeState!.isInitial))
            // [6차 지시서 §4] 줄글이 오기 전 문단 모양의 스켈레톤을 먼저
            // 그려서, 도착 시 같은 자리에서 텍스트로 바뀌듯 전환되게 한다
            // (스피너+한 줄 문구 방식은 실제 문단 분량과 높이가 달라 텍스트
            // 도착 시 카드가 갑자기 커지는 문제가 있었다).
            Padding(
              padding: const EdgeInsets.only(bottom: HanjiSpacing.xs + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HanjiSkeletonBox(height: 14, radius: 4),
                  const SizedBox(height: HanjiSpacing.sm),
                  const _HanjiSkeletonBox(height: 14, radius: 4),
                  const SizedBox(height: HanjiSpacing.sm),
                  const _HanjiSkeletonBox(
                    height: 14,
                    width: 160,
                    radius: 4,
                  ),
                  const SizedBox(height: HanjiSpacing.sm),
                  Text(
                    '풀이를 준비하고 있어요...',
                    style: HanjiTextStyles.bodySmall(color: HanjiColors.muted),
                  ),
                ],
              ),
            )
          else if (isFocused &&
              focusNarrativeState != null &&
              focusNarrativeState!.isSuccess &&
              (focusNarrativeState!.data?.text.trim().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(bottom: HanjiSpacing.xs + 2),
              child: NarrativeTermText(
                text: focusNarrativeState!.data!.text,
                style: HanjiTextStyles.body(color: HanjiColors.fg),
              ),
            )
          else
            ...part.paras.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: HanjiSpacing.xs + 2),
                child: Text(
                  _humanizeFallbackPara(p),
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
      // [6차 지시서 §4] 스피너 대신 실제 headline/section 모양의
      // 스켈레톤 블록을 먼저 그려 레이아웃 흔들림을 줄인다.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HanjiSkeletonBox(height: 13, width: 96, radius: 4),
          const SizedBox(height: HanjiSpacing.sm),
          const _HanjiSkeletonBox(height: 20, width: 220, radius: 4),
          const SizedBox(height: HanjiSpacing.md),
          const _HanjiSkeletonBox(height: 15, radius: 4),
          const SizedBox(height: HanjiSpacing.sm),
          const _HanjiSkeletonBox(height: 15, width: 200, radius: 4),
          const SizedBox(height: HanjiSpacing.sm),
          Text(
            '핵심 상세 분석을 준비하고 있어요...',
            style: HanjiTextStyles.bodySmall(color: HanjiColors.muted),
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

/// [옵션 B] 9 PART 중 어느 것에도 대응하지 않는 20종(건강/궁합/개운
/// 아이템)을 위한 별도 심층 분석 블록. PART 카드와 시각적으로 동일한
/// 톤을 쓰되, "9 PART 다음에 이어지는 추가 심층"이라는 위치를 명확히
/// 보이도록 살짝 다른 라벨을 쓴다.
class _JeontongV3StandaloneDeepDive extends StatelessWidget {
  const _JeontongV3StandaloneDeepDive({
    required this.entry,
    required this.displayName,
    required this.interpretState,
    required this.narrativeState,
    required this.onRetry,
    required this.onRetryNarrative,
  });

  final JeontongCategoryEntry entry;
  final String displayName;
  final LoadState<InterpretationResult> interpretState;
  final LoadState<NarrativeResult> narrativeState;
  final VoidCallback onRetry;
  final VoidCallback onRetryNarrative;

  @override
  Widget build(BuildContext context) {
    final narrativeText = narrativeState.isSuccess
        ? narrativeState.data?.text.trim()
        : null;
    final hasNarrative = narrativeText != null && narrativeText.isNotEmpty;
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
          // [버그 수정 — 2026-09-27] 건강/궁합/개운 아이템류(9 PART 대응
          // 없음)도 이야기형 줄글(narrative)이 준비돼 있으면 우선 보여준다.
          if (hasNarrative) ...[
            NarrativeTermText(
              text: narrativeText,
              style: HanjiTextStyles.body(color: HanjiColors.fg),
            ),
            const SizedBox(height: HanjiSpacing.md),
            Container(height: 1, color: HanjiColors.line),
            const SizedBox(height: HanjiSpacing.md),
          ] else if (narrativeState.isLoading || narrativeState.isInitial) ...[
            // [6차 지시서 §4] 위 강조 카드와 동일한 스켈레톤 패턴 적용.
            const _HanjiSkeletonBox(height: 14, radius: 4),
            const SizedBox(height: HanjiSpacing.sm),
            const _HanjiSkeletonBox(height: 14, radius: 4),
            const SizedBox(height: HanjiSpacing.sm),
            const _HanjiSkeletonBox(height: 14, width: 160, radius: 4),
            const SizedBox(height: HanjiSpacing.sm),
            Text(
              '풀이를 준비하고 있어요...',
              style: HanjiTextStyles.bodySmall(color: HanjiColors.muted),
            ),
            const SizedBox(height: HanjiSpacing.md),
          ],
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
