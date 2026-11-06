/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S06~S08] "운세 보관함" 7종
/// (사주/타로/관상/손금/운세 기록/보관한 풀이/궁합)의 공용 화면 틀.
///
/// design_handoff_mypage_minimal.zip README §4 "S06 운세 보관함 목록
/// (공용)" / "S08 빈 상태" 스펙을 Flutter 공용 위젯으로 포팅한다.
///
/// [범위 결정 — 로직은 그대로, 시각 틀만 공용화] 7개 화면은 백엔드 데이터
/// 구조가 서로 다르다(로컬 SharedPreferences 저장소 2종 — SavedFortuneRecord
/// /ReadingArtifact, Provider 기반 서버 결과 모델 3종 — Tarot/Face/
/// PalmResultModel, 서버 Map 응답 1종 — Gunghap myResults). README가 요구한
/// "화면 7개를 템플릿 1개로 통합"은 **시각적 틀**(상단바·리드 문구·행
/// 레이아웃·빈 상태)을 의미하는 것으로 해석해, 각 화면의 기존 데이터
/// 조회/상태관리 로직(Provider.loadHistory(), 로컬 스토어 읽기, 서버
/// fetchMyResults() 등)은 전혀 건드리지 않고, 그 결과를 아래 공용 위젯에
/// 꽂아 렌더링만 교체한다("로직은 그대로, 스킨만 교체" 원칙의 연장).
///
/// [S07(풀이 상세) 범위 제외] 타로/관상/손금/궁합은 이미 각자 전용의
/// 정교한 상세 화면(TarotResultScreen/FaceResultScreen/PalmResultScreen/
/// GunghapResultScreen — 카드 이미지, 부위별 해석, 등급 8분야 등 매우
/// 다른 도메인 UI)을 갖고 있다. README의 범용 S07 틀(큰 글리프+제목+
/// 요약+본문+인용구)로 이들을 교체하는 것은 각 카테고리의 기존 상세
/// 경험을 크게 단순화시키는 별도 대형 작업이 되므로, 이번 S06/S08
/// 작업 범위에서는 제외하고 기존 상세 화면을 무수정으로 유지한다.
library;

import 'package:flutter/material.dart';
import 'mypage_minimal_theme.dart';

/// README §S06 공용 리스트 화면의 Scaffold 틀.
/// 서브화면 공통 셸(상단바 52/12/10, 그리드 44·1fr·44) + 리드 문구
/// "{n}개의 풀이가 담겨 있어요" + 본문(슬롯)을 조합한다.
class MyPageArchiveScaffold extends StatelessWidget {
  const MyPageArchiveScaffold({
    super.key,
    required this.title,
    required this.itemCount,
    required this.isLoading,
    required this.body,
    this.onRefresh,
    this.trailing,
  });

  final String title;

  /// null이면 리드 문구를 숨긴다(로딩 중 또는 빈 상태일 때).
  final int? itemCount;
  final bool isLoading;
  final Widget body;
  final Future<void> Function()? onRefresh;

  /// 상단바 우측 옵션 액션(예: S07의 ☆ 보관 토글류). 공용 리스트 화면은
  /// 기본적으로 비워둔다.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 40,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: MyPageColors.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: MyPageTextStyles.header,
                    ),
                  ),
                  SizedBox(width: 44, child: trailing),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              MyPageSpacing.subX,
              6,
              MyPageSpacing.subX,
              120,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!isLoading && itemCount != null && itemCount! > 0) ...[
                  Text(
                    '$itemCount개의 풀이가 담겨 있어요',
                    style: MyPageTextStyles.body,
                  ),
                  const SizedBox(height: 12),
                ],
                body,
              ]),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: onRefresh == null
          ? content
          : RefreshIndicator(
              color: MyPageColors.red,
              onRefresh: onRefresh!,
              child: content,
            ),
    );
  }
}

/// README §S06 공용 리스트 행: 좌측 썸네일(46×46 radius15, 4톤 순환) +
/// 날짜(mono 10px) + 제목(16px/800) + 요약(12px/600, 1줄 말줄임) + 우측 ›.
/// `tileIndex`는 README의 4톤 팔레트(tile1~4)를 순환 사용하기 위한 색
/// 인덱스로, 각 화면이 자신의 고정 톤(예: 사주=tile1, 타로=tile2 등)을
/// 넘긴다.
class MyPageArchiveRow extends StatelessWidget {
  const MyPageArchiveRow({
    super.key,
    required this.glyph,
    required this.tileIndex,
    required this.dateLabel,
    required this.title,
    required this.summary,
    required this.onTap,
    this.trailing,
  });

  final String glyph;
  final int tileIndex;
  final String dateLabel;
  final String title;
  final String summary;
  final VoidCallback? onTap;

  /// 우측 ‹›  자리를 대체할 위젯(예: 삭제 버튼). null이면 기본 chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bg = MyPageColors.tileBg[tileIndex % MyPageColors.tileBg.length];
    final fg = MyPageColors.tileFg[tileIndex % MyPageColors.tileFg.length];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MyPageRadius.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(MyPageRadius.tile),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    glyph,
                    style: TextStyle(
                      fontFamily: MyPageFonts.hanja,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: fg,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontFamily: MyPageFonts.mono,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: MyPageColors.ink3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: MyPageTextStyles.row.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: const TextStyle(
                            fontFamily: MyPageFonts.ui,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: MyPageColors.ink3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: MyPageColors.ink3,
                    ),
              ],
            ),
            const SizedBox(height: 2),
            Container(height: 1, color: MyPageColors.hair),
          ],
        ),
      ),
    );
  }
}

/// README §S08 빈 상태: 140×84 점선 부적 + 세로쓰기 글리프 + 제목/서브 +
/// "{종류} 보러 가기 ›" pill 버튼.
class MyPageArchiveEmptyState extends StatelessWidget {
  const MyPageArchiveEmptyState({
    super.key,
    required this.glyph,
    required this.ctaLabel,
    required this.onCta,
    this.title = '아직 담긴 풀이가 없어요',
    this.subtitle = '첫 풀이를 받으면 이곳에 차곡차곡 쌓여요',
  });

  final String glyph;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CustomPaint(
            painter: _DashedCharmPainter(),
            child: SizedBox(
              width: 140,
              height: 84,
              child: Center(
                child: Text(
                  glyph,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: MyPageFonts.hanja,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    height: 1.1,
                    color: Color(0x478B2C1F),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: MyPageTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: MyPageTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onCta,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: MyPageColors.ink,
                borderRadius: BorderRadius.circular(MyPageRadius.pill),
              ),
              child: Text(
                ctaLabel,
                style: const TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFFFFFAF0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// S08 "140×84 점선 부적(1.5px dashed rgba(139,44,31,.35))" 렌더링.
/// S02/S04의 [MyPageDashedBorderBox]는 RRect 전체 테두리용이라, 부적
/// 모양(위쪽이 둥근 사다리꼴에 가까운 실루엣)에는 맞지 않아 전용
/// CustomPainter를 별도로 둔다(간소화: 라운드 사각형 점선으로 근사).
class _DashedCharmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x598B2C1F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 5.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 로딩 중 공용 자리표시자. README §6 "로딩/에러" — "스켈레톤 UI는 쓰지
/// 않습니다. 로딩 중에는 ... 리스트 자리에 S08과 같은 점선 부적을
/// opacity .4로 보여줍니다".
class MyPageArchiveLoadingPlaceholder extends StatelessWidget {
  const MyPageArchiveLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CustomPaint(
            painter: _DashedCharmPainter(),
            child: const SizedBox(width: 140, height: 84),
          ),
        ),
      ),
    );
  }
}
