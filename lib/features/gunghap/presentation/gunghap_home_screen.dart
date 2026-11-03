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
import '../../../core/router/main_bottom_nav_bar.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';
import '../widgets/cat_icon.dart';
import '../domain/gunghap_data.dart';
import 'gunghap_major_screen.dart';

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
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('내 궁합 관리 화면은 준비 중이에요.')),
              );
            },
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
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('내 궁합 관리 화면은 준비 중이에요.')),
              ),
              child: Text('내 궁합 관리 ›', style: GHText.ui(size: 13, color: GHColors.gray)),
            ),
          ),
          Column(
            children: [
              for (final h in ghRecentHistory) ...[
                _HistoryRow(item: h),
                const SizedBox(height: 10),
              ],
            ],
          ),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final GHHistoryItem item;
  @override
  Widget build(BuildContext context) {
    final major = ghMajorById(item.majorId);
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('궁합 결과 화면은 준비 중이에요.')),
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
              child: CatIcon(kind: major.icon, size: 30, active: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.a,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GHText.cardTitle(size: 15),
                        ),
                      ),
                      Text(' ✦ ', style: GHText.ui(size: 14, color: GHColors.gold)),
                      Flexible(
                        child: Text(
                          item.b,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GHText.cardTitle(size: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(item.sub, style: GHText.ui(size: 12, color: GHColors.gold)),
                      const SizedBox(width: 6),
                      Text('·', style: GHText.ui(size: 12, color: GHColors.gray)),
                      const SizedBox(width: 6),
                      Text(item.date, style: GHText.mono(size: 9.5, color: GHColors.gray)),
                    ],
                  ),
                ],
              ),
            ),
            if (item.paid)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GHColors.mint.withValues(alpha: .4)),
                ),
                child: Text(
                  'REPORT',
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
}
