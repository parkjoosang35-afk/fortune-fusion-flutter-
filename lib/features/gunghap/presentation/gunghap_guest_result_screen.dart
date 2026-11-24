// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_guest_result_screen.dart
// [귀인지도 궁합지도 개발 지시서 §2③/§3] 게스트(초대받은 사람) 본인 화면.
//
// `GunghapGuestInputScreen._handleSubmit()`가 성공 직후 pushReplacement로
// 도달한다. 전달받는 [result]는 `POST /gunghap/g/{token}/join` 응답을
// 그대로 담은 Map — 이 화면은 그 데이터를 추가 네트워크 호출 없이
// 즉시 렌더링한다.
//
// [권한 원칙 — 절대 준수] 상세 보고서 잠금해제(`/unlock`)와 결과 재조회
// (`GET /results/{resultId}`)는 모두 "초대자 본인 인증" 전용 API다
// (서버가 소유자 여부를 검증). 이 화면은 게스트 본인의 화면이므로
// 어떤 형태로도 잠금해제 버튼이나 상세 보고서 열람 동선을 제공하지
// 않는다 — 대신 "나도 궁합지도 만들기" CTA로 게스트가 스스로 홈에서
// 새 초대를 시작하도록 안내한다(§6 "기존 서비스 기능을 임의로 변경하지
// 않는다" 원칙 — 새 동선을 추가할 뿐, 권한 정책을 우회하는 어떤 기능도
// 추가하지 않는다).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../../core/widgets/result_text_scale_overlay.dart';
import '../domain/gunghap_data.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/cat_icon.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_score_ring.dart';
import '../widgets/gh_screen.dart';
import '../widgets/person_pair.dart';
import 'gunghap_home_screen.dart';

class GunghapGuestResultScreen extends StatelessWidget {
  const GunghapGuestResultScreen({super.key, required this.result});

  /// `POST /gunghap/g/{token}/join` 응답 전체(resultId, ownerName,
  /// guestName, relationType, relationTypeLabel, relationTypeDesc,
  /// chemistryScore, grade, gradeCode, timeUnknown, dayMasterKr,
  /// dayMasterElement, categories: [8x {categoryId, grade, gradeCode}],
  /// unlockCost, joined).
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final ownerName = result['ownerName'] as String? ?? '초대한 사람';
    final guestName = result['guestName'] as String? ?? '나';
    final relationTypeLabel = result['relationTypeLabel'] as String?;
    final relationTypeDesc = result['relationTypeDesc'] as String?;
    final chemistryScore = result['chemistryScore'];
    final score = chemistryScore is num ? chemistryScore.toInt() : null;
    final band = score != null ? GHBand.of(score) : null;
    // [v4 S16] 게스트 결과 전용 PersonPair/ElementBars — `owner`/`member`
    // 신규 필드(하위호환 추가, 이번 핸드오프에서 admin_web 3개 라우트에
    // 함께 추가됨)가 없는 구버전 응답이면 두 위젯 모두 조용히 생략된다.
    final ownerSaju = GhPersonSaju.fromMap(result['owner']);
    final memberSaju = GhPersonSaju.fromMap(result['member']);
    final categoriesRaw = result['categories'];
    final categories = categoriesRaw is List
        ? categoriesRaw.whereType<Map>().toList()
        : const <Map>[];
    // [버그 수정 — 대표 신고 "궁합지도 초대장 주제에 맞는 궁합을 본다고
    // 해야지 8개본다고 돼어있잔아"] 서버(`toFreeCategoryView()`)가 초대
    // 생성 시 선택된 majorId 기준으로 이미 categories를 1개로 필터링해
    // 내려주므로, 화면도 majorId가 있으면 선택된 주제 라벨만 보여준다.
    final majorId = result['majorId'] as String?;
    final sectionTitle = majorId != null
        ? '${ghMajorById(majorId).shortName} 궁합 등급'
        : '8개 분야 궁합 등급';

    // [v4 S16 명세 §3-2] 「웹 · 비로그인」 화면(S14/S16 공통) — GHAppBar와
    // 하단바(MainBottomNavBar)를 쓰지 않고, 화면 맨 위에 자체 URL 잠금
    // 바([GHUrlBar])만 둔다. 뒤로가기는 OS/브라우저 제스처에 맡긴다.
    return ResultTextScaleOverlay(
      child: GHScreen(
        appBar: null,
        footer: GHButton(
          label: '✦ 나도 궁합지도 만들기',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const GunghapHomeScreen()),
            (route) => false,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GHUrlBar(),
            const SizedBox(height: 18),
            // [v4 S16] 「○ 무료 결과」 칩 — S17의 GHTier(유료)와 대비되는
            // 무료 결과 전용 표시. 아직 공용 GHTier 컴포넌트가 없어
            // 가장 가까운 기존 부품인 [GHChip](비활성 스타일)으로 대체한다.
            Center(
              child: GHChip(label: '○ 무료 결과', active: false),
            ),
            const SizedBox(height: 14),
            GHTitle(
              title: '$ownerName님과의 인연을\n살펴보았습니다',
              center: true,
            ),
            if (score != null && band != null)
              Center(
                child: GHScoreRing(score: score, sub: band.label),
              ),
            const SizedBox(height: 22),
            PersonPair(
              ownerName: ownerName,
              memberName: guestName,
              owner: ownerSaju,
              member: memberSaju,
            ),
            if (ownerSaju != null && memberSaju != null)
              const SizedBox(height: 22),
            if (relationTypeDesc != null) ...[
              _GlowSummaryCard(
                relationTypeLabel: relationTypeLabel,
                relationTypeDesc: relationTypeDesc,
              ),
              const SizedBox(height: 18),
            ],
            if (ownerSaju != null && memberSaju != null) ...[
              _ElementHarmonyCard(
                ownerName: ownerName,
                memberName: guestName,
                owner: ownerSaju,
                member: memberSaju,
              ),
              const SizedBox(height: 18),
            ],
            // [v4 S16] 점선 민트 박스 — 게스트 본인 생년월일 비공개 안내.
            _DashedMintNotice(ownerName: ownerName),
            const SizedBox(height: 22),
            GHSectionHead(mono: 'FREE RESULT', title: sectionTitle),
            for (final c in categories) ...[
              _CategoryGradeRow(
                categoryId: c['categoryId'] as String?,
                grade: c['grade'] as String?,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            // [v4 S16] fieldBg 해금 안내 박스(기존 lineSoft 테두리 박스를
            // fieldBg 배경 채움으로 교체 — 명세 「◇ fieldBg 박스」).
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: GHColors.fieldBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '◇',
                    style: TextStyle(fontSize: 13, color: GHColors.violetText),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '분야별 상세 보고서는 초대를 보낸 $ownerName님이 복주머니로\n'
                      '잠금해제한 뒤 확인할 수 있어요.',
                      style: GHText.ui(
                        size: 12,
                        height: 1.6,
                        color: GHColors.gray,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // [v4 S16 §12-6] 「내 정보 삭제」 텍스트 버튼은 게스트 전용
            // 삭제 API가 현재 admin_web에 없어 명세 §12 표 6번
            // ("API 없으면 숨김") 규칙에 따라 생략한다.
          ],
        ),
      ),
    );
  }
}

/// [v4 S16] 핵심 요약 카드(glow) — mono 「SUMMARY · 핵심 요약」 +
/// 18/700 한 줄 요약(`relationTypeDesc`, 보기 기준으로 명세의 "나무가
/// 불을 키우듯, 서로를 밝혀 주는 인연" 같은 한 문단 해석에 대응).
/// 서버가 이미 내려주는 기존 필드를 그대로 쓰므로 추가 API 확장이
/// 필요 없다(§4 공용 데이터 표의 `result.summary{headline}`과 달리,
/// 이 화면은 `relationTypeDesc`를 그 역할로 재사용).
class _GlowSummaryCard extends StatelessWidget {
  const _GlowSummaryCard({
    required this.relationTypeLabel,
    required this.relationTypeDesc,
  });
  final String? relationTypeLabel;
  final String relationTypeDesc;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(GHRadius.card),
      border: Border.all(color: GHColors.line, width: GHBorder.width),
      boxShadow: [BoxShadow(color: GHColors.glowShadow, blurRadius: 22, offset: const Offset(0, 8))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GHMono('SUMMARY · 핵심 요약', color: GHColors.accent),
        const SizedBox(height: 10),
        Text(
          relationTypeDesc,
          textAlign: TextAlign.center,
          style: GHText.title(size: 18).copyWith(height: 1.4),
        ),
        if (relationTypeLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            relationTypeLabel!,
            textAlign: TextAlign.center,
            style: GHText.ui(size: 12.5, color: GHColors.gray),
          ),
        ],
      ],
    ),
  );
}

/// [v4 S16] 「☯ 오행 조화」 카드 — [ElementBars] 포함.
class _ElementHarmonyCard extends StatelessWidget {
  const _ElementHarmonyCard({
    required this.ownerName,
    required this.memberName,
    required this.owner,
    required this.member,
  });
  final String ownerName;
  final String memberName;
  final GhPersonSaju owner;
  final GhPersonSaju member;

  @override
  Widget build(BuildContext context) => GHCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('☯', style: TextStyle(fontSize: 14, color: GHColors.violetText)),
            const SizedBox(width: 6),
            Text('오행 조화', style: GHText.cardTitle(size: 14.5, color: GHColors.violetText)),
          ],
        ),
        const SizedBox(height: 14),
        ElementBars(owner: owner, member: member),
      ],
    ),
  );
}

/// [v4 S16] 점선 민트 박스 — 「✓ {초대자}님에게도 같은 결과가 전달됐어요.
/// 내 생년월일은 공개하지 않았어요.」 게스트 본인 정보 비공개 안내.
/// 패키지 의존 없이 `CustomPaint`로 점선 테두리를 직접 그린다.
class _DashedMintNotice extends StatelessWidget {
  const _DashedMintNotice({required this.ownerName});
  final String ownerName;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedRectPainter(color: GHColors.mint, radius: 14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✓', style: TextStyle(fontSize: 13, color: GHColors.mint, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$ownerName님에게도 같은 결과가 전달됐어요.\n내 생년월일은 공개하지 않았어요.',
              style: GHText.ui(size: 12, height: 1.6, color: GHColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = GHBorder.width;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        const dashLen = 5.0, gapLen = 3.5;
        final next = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _CategoryGradeRow extends StatelessWidget {
  const _CategoryGradeRow({required this.categoryId, required this.grade});
  final String? categoryId;
  final String? grade;

  @override
  Widget build(BuildContext context) {
    final major = ghMajorById(categoryId);
    return GHCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: GHRadius.cardSm,
      minHeight: 60,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GHColors.gold.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GHColors.divider),
            ),
            alignment: Alignment.center,
            child: CatIcon(kind: major.icon, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(major.name, style: GHText.cardTitle(size: 14.5)),
          ),
          if (grade != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: GHColors.cardSolid,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: GHColors.lineSoft),
              ),
              child: Text(
                grade!,
                style: GHText.ui(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: GHColors.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
