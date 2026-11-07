// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_guest_result_screen.dart
// [신통방통 궁합지도 개발 지시서 §2③/§3] 게스트(초대받은 사람) 본인 화면.
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

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/widgets/result_text_scale_overlay.dart';
import '../domain/gunghap_data.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/cat_icon.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';
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
    final grade = result['grade'] as String?;
    final chemistryScore = result['chemistryScore'];
    final categoriesRaw = result['categories'];
    final categories = categoriesRaw is List
        ? categoriesRaw.whereType<Map>().toList()
        : const <Map>[];

    return ResultTextScaleOverlay(
      child: GHScreen(
        bottomNav: const MainBottomNavBar(currentIndex: 0),
        appBar: const GHAppBar(title: '우리 둘의 궁합'),
        footer: GHButton(
          label: '나도 궁합지도 만들기',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const GunghapHomeScreen()),
            (route) => false,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GHSteps(step: 4, labels: ['분야', '나', '상대', '분석']),
            GHTitle(
              mono: 'STEP 04 · RESULT',
              title: '$ownerName님과 $guestName님의\n궁합 결과예요',
              center: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: StarMap(aName: ownerName, bName: guestName, draw: true),
              ),
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              relationTypeLabel: relationTypeLabel,
              relationTypeDesc: relationTypeDesc,
              grade: grade,
              chemistryScore: chemistryScore,
            ),
            const SizedBox(height: 22),
            const GHSectionHead(mono: 'FREE RESULT', title: '8개 분야 궁합 등급'),
            for (final c in categories) ...[
              _CategoryGradeRow(
                categoryId: c['categoryId'] as String?,
                grade: c['grade'] as String?,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GHColors.lineSoft),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✦',
                    style: TextStyle(fontSize: 13, color: GHColors.gold),
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
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.relationTypeLabel,
    required this.relationTypeDesc,
    required this.grade,
    required this.chemistryScore,
  });
  final String? relationTypeLabel;
  final String? relationTypeDesc;
  final String? grade;
  final dynamic chemistryScore;

  @override
  Widget build(BuildContext context) => GHCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (grade != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: GHColors.gold.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: GHColors.gold),
                ),
                child: Text(
                  grade!,
                  style: GHText.ui(
                    size: 13,
                    weight: FontWeight.w800,
                    color: GHColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (chemistryScore != null)
              Text(
                '$chemistryScore점',
                style: GHText.ui(
                  size: 13,
                  weight: FontWeight.w700,
                  color: GHColors.ivory,
                ),
              ),
          ],
        ),
        if (relationTypeLabel != null) ...[
          const SizedBox(height: 10),
          Text(relationTypeLabel!, style: GHText.cardTitle(size: 16)),
        ],
        if (relationTypeDesc != null) ...[
          const SizedBox(height: 6),
          Text(
            relationTypeDesc!,
            style: GHText.ui(size: 13, height: 1.6, color: GHColors.gray),
          ),
        ],
      ],
    ),
  );
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
