// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_home_screen.dart
// [궁합지도 Star Map 디자인 적용] design_handoff_gunghap_map.zip
// `design_files/gunghap/gh-screens-a.jsx` ScreenHome(01 메인 홈) 포팅본.
//
// ⚠️ 범위: 사용자의 최종 지시("궁합지도 클릭시 지금 디자인 나오게
// 만들어주면됨")에 따라 이번 턴은 **디자인/클릭 흐름만** 구현한다.
// 실제 사주 FACT 엔진·초대장 토큰 발급·복주머니 차감 등 정식
// 개발지시서(15섹션)의 백엔드 기능은 포함하지 않는다. 대분류→세부
// 카테고리까지는 실제 화면 전환이 동작하며, 그 다음 단계(나의 정보
// 입력 이후)는 아직 백엔드가 없어 "준비 중" 안내로 멈춘다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/router/main_bottom_nav_bar.dart';
import '../application/gunghap_provider.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';
import '../widgets/cat_icon.dart';
import '../domain/gunghap_data.dart';
import 'gunghap_major_screen.dart';
import 'gunghap_result_screen.dart';
import 'gunghap_story_screen.dart';

class GunghapHomeScreen extends StatelessWidget {
  const GunghapHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GHScreen(
      // [하단바 누락 수정] 신통방통 공용 하단 네비게이션 바
      // (홈/신당부적/복주머니/마이)를 그대로 재사용한다. 궁합지도는
      // 홈 화면 "전체보기"에서 진입하므로 다른 push 화면들(정통사주/
      // 타로/귀인지도 등)과 동일하게 currentIndex: 0(홈)을 쓴다 —
      // 전용 하단바를 새로 만들지 않고 기존 [MainBottomNavBar] 그대로.
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(
        leading: Row(
          children: const [
            _GHMark(),
            SizedBox(width: 7),
            Text('궁합지도', style: TextStyle()),
          ],
        ),
        actions: [
          GHIconButton(
            glyph: '◈',
            label: '내 궁합',
            // [궁합지도 Phase 4 §3] "준비 중" 플레이스홀더를 실제
            // 궁합스토리 화면(서버 DB 실데이터)으로 교체.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GunghapStoryScreen()),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // hero badge + title
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: GHColors.lineSoft),
                  color: GHColors.bg2.withValues(alpha: .6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: GHColors.gold,
                        boxShadow: [
                          BoxShadow(color: GHColors.gold.withValues(alpha: .8), blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '정통 사주로 보는 두 사람의 궁합',
                      style: GHText.ui(size: 12, weight: FontWeight.w600, color: GHColors.gold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '두 사람의 인연을\n확인해 보세요',
                textAlign: TextAlign.center,
                style: GHText.display(size: 28),
              ),
            ],
          ),

          // key graphic — full bleed-ish
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Stack(
              alignment: Alignment.center,
              children: [
                FractionallySizedBox(
                  widthFactor: .78,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            GHColors.violet.withValues(alpha: .16),
                            GHColors.gold.withValues(alpha: .06),
                            Colors.transparent,
                          ],
                          stops: const [0, .45, .7],
                        ),
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: StarMap(aName: '나', bName: '그 사람', big: true),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 0, bottom: 14),
            child: Text(
              '두 사람의 운명을 잇는 별의 지도',
              textAlign: TextAlign.center,
              style: GHText.ui(size: 14, color: GHColors.gray),
            ),
          ),

          // primary CTA
          GHButton(
            label: '궁합 시작하기',
            size: GHButtonSizeT.xl,
            leading: const Text('✦', style: TextStyle(fontSize: 15)),
            onPressed: () => _goMajor(context, method: 'direct'),
          ),
          const SizedBox(height: 8),
          GHButton(
            label: '궁합 초대장 보내기',
            variant: GHButtonVariant.secondary,
            size: GHButtonSizeT.md,
            leading: const Text('✉', style: TextStyle(color: GHColors.gold)),
            onPressed: () => _goMajor(context, method: 'invite'),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (i, t) in const ['분야 선택', '두 사람 정보', '무료 결과'].indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${i + 1}', style: GHText.mono(color: GHColors.gold, size: 10)),
                    const SizedBox(width: 6),
                    Text(t, style: GHText.ui(size: 12, color: GHColors.gray)),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 38),
          GHSectionHead(mono: 'CATEGORY · 08', title: '어떤 인연이 궁금하세요'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.9,
            children: [
              for (final m in ghMajors)
                _MajorTile(major: m, onTap: () => _goSub(context, m.id)),
            ],
          ),

          const SizedBox(height: 34),
          GHSectionHead(
            mono: 'RECENT',
            title: '최근 살펴본 궁합',
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GunghapStoryScreen()),
              ),
              child: Text('내 궁합 관리 ›', style: GHText.ui(size: 13, color: GHColors.gray)),
            ),
          ),
          // [궁합지도 Phase 4 §3] 디자인 미리보기 전용 하드코딩
          // ghRecentHistory 더미를 제거하고, 실제 서버 결과(최대 2건
          // 미리보기)를 보여준다. 로딩/빈 상태는 이 섹션 특성상 과하지
          // 않게 처리 — 비어 있으면 섹션 자체를 숨기고, 전체 목록은
          // 위 "내 궁합 관리 ›"에서 확인하게 한다.
          const _RecentGunghapPreview(),
        ],
      ),
    );
  }

  void _goMajor(BuildContext context, {required String method}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GunghapMajorScreen(method: method)),
    );
  }

  void _goSub(BuildContext context, String majorId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GunghapMajorScreen(method: 'direct', initialMajorId: majorId, skipToSub: true),
      ),
    );
  }
}

class _GHMark extends StatelessWidget {
  const _GHMark();
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(20, 20),
    painter: _GHMarkPainter(),
  );
}

class _GHMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);
    canvas.drawCircle(
      const Offset(12, 12),
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = GHColors.gold.withValues(alpha: .6),
    );
    canvas.drawLine(
      const Offset(6.5, 15),
      const Offset(17.5, 8.5),
      Paint()
        ..strokeWidth = .9
        ..color = GHColors.gold,
    );
    canvas.drawCircle(const Offset(6.5, 15), 2.2, Paint()..color = GHColors.gold);
    canvas.drawCircle(const Offset(17.5, 8.5), 2.2, Paint()..color = GHColors.violet);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MajorTile extends StatelessWidget {
  const _MajorTile({required this.major, required this.onTap});
  final GHMajor major;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: GHColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GHColors.lineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GHColors.bg2.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GHColors.lineSoft),
            ),
            alignment: Alignment.center,
            child: CatIcon(kind: major.icon, size: 32, active: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  major.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GHText.cardTitle(size: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ghSubs[major.id]?.length ?? 0}가지',
                  style: GHText.ui(size: 11, color: GHColors.gray),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// [궁합지도 Phase 4 §3] "최근 살펴본 궁합" — 실제 서버 데이터 전용.
//
// [절대 원칙] 더 이상 gunghap_data.dart의 하드코딩 ghRecentHistory를
// 쓰지 않는다. GunghapProvider.fetchMyResults()(GET /my-results)를
// 호출해 실제 DIRECT+INVITE 결과를 가져오고, 최신 2건만 미리보기로
// 보여준다. 전체 목록은 "내 궁합 관리 ›"에서 GunghapStoryScreen으로.
// ═══════════════════════════════════════════════════════════════
class _RecentGunghapPreview extends StatefulWidget {
  const _RecentGunghapPreview();

  @override
  State<_RecentGunghapPreview> createState() => _RecentGunghapPreviewState();
}

class _RecentGunghapPreviewState extends State<_RecentGunghapPreview> {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requested = true;
      context.read<GunghapProvider>().fetchMyResults();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();

    if (!_requested || (provider.isLoadingMyResults && provider.myResults.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: GHColors.gold),
          ),
        ),
      );
    }

    if (provider.myResults.isEmpty) {
      // [빈 상태] 이 섹션 자체를 숨긴다 — 하드코딩 더미로 대체하지 않는다.
      return const SizedBox.shrink();
    }

    final recent = provider.myResults.take(2).toList();
    return Column(
      children: [
        for (final item in recent) ...[
          _HistoryRow(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  /// `GET /gunghap/my-results` 응답 items[i] (실제 서버 데이터).
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    // [상대방 이름 원칙] DIRECT는 ownerName이 항상 null이므로 resultType과
    // 무관하게 항상 guestName을 사용한다(gunghap_repository.dart 참고).
    final guestName = item['guestName'] as String? ?? '상대방';
    final relationTypeLabel = item['relationTypeLabel'] as String?;
    final grade = item['grade'] as String?;
    final resultType = item['resultType'] as String?;
    final createdAtRaw = item['createdAt'] as String?;
    final dateLabel = _formatDate(createdAtRaw);
    final resultId = item['resultId'] as String?;

    return GestureDetector(
      onTap: resultId == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GunghapResultScreen(resultId: resultId),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: GHColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GHColors.lineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: GHColors.bg2.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GHColors.divider),
              ),
              alignment: Alignment.center,
              child: const CatIcon(kind: 'heart', size: 30, active: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GHText.cardTitle(size: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (relationTypeLabel != null) ...[
                        Flexible(
                          child: Text(
                            relationTypeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GHText.ui(size: 12, color: GHColors.gold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('·', style: GHText.ui(size: 12, color: GHColors.gray)),
                        const SizedBox(width: 6),
                      ],
                      if (dateLabel != null)
                        Text(dateLabel, style: GHText.mono(size: 9.5, color: GHColors.gray)),
                    ],
                  ),
                ],
              ),
            ),
            if (resultType == 'DIRECT')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GHColors.violet.withValues(alpha: .4)),
                ),
                child: Text(
                  'DIRECT',
                  style: GHText.mono(size: 8.5, color: GHColors.violetText),
                ),
              )
            else if (grade != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GHColors.mint.withValues(alpha: .4)),
                ),
                child: Text(
                  grade,
                  style: GHText.mono(size: 8.5, color: GHColors.mint),
                ),
              ),
            const SizedBox(width: 6),
            Text('›', style: GHText.ui(size: 18, color: GHColors.gray)),
          ],
        ),
      ),
    );
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    return DateFormat('yyyy · MM · dd').format(parsed.toLocal());
  }
}
