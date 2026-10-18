// ═══════════════════════════════════════════════════════════════
// FILE: fortune_engine_intro_screen.dart
// [운세 엔진 안내 페이지] 신통방통 메인 화면(v2) 하단 시트의 "전체보기"
// 버튼을 "운세 엔진"으로 교체하면서 새로 추가된 안내 전용 화면.
//
// [배경] 사용자가 첨부한 디자인(README 없이 스크린샷만 전달) — 다크
// 네이비 히어로 + "운세 엔진 / 감으로 보는 운세가 아닙니다. 전통의
// 기준으로 계산하고, 그 근거를 보여드립니다." 카피 + 6개 엔진 카드
// (정통사주/귀인지도/타로/관상/손금/대조) + "여섯 가지 관점으로 함께
// 봅니다" 섹션(표현력/사고력/추진력/재물감각/방향성/귀인 조력) + 하단
// 약속 문구를 그대로 재현한다.
//
// [주의 — 이 화면은 순수 안내/설명용 정적 콘텐츠다] 각 카드를 탭해도
// 실제 기능 화면으로 이동시키지 않는다(사용자가 요청한 범위는 "안내
// 페이지 연결"까지이며, 각 카드별 개별 라우팅은 이번 작업 범위 밖).
// 기존 기능(정통사주/귀인지도/타로/관상/손금)의 실제 진입 경로는 이미
// sintong_chip_row.dart/sintong_v2_sheet.dart의 카드들이 담당하고
// 있으므로 중복 라우팅을 추가하지 않는다 — 혼선 방지.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

/// 안내 페이지 전용 다크 네이비 톤(첨부 디자인 그대로) — 홈 v2의
/// 골드/시트 톤과는 별개 팔레트라 이 파일 안에서만 쓰는 로컬 토큰으로
/// 둔다(다른 화면에 영향 없음).
class _EngineIntroColors {
  _EngineIntroColors._();

  static const Color bg = Color(0xFF0B0F1E); // 최상단 배경(짙은 남색)
  static const Color heroTop = Color(0xFF151B33);
  static const Color heroBottom = Color(0xFF0B0F1E);
  static const Color gold = Color(0xFFE8C77A);
  static const Color textPrimary = Color(0xFFF5F3EE);
  static const Color textSecondary = Color(0xB3F5F3EE); // 70%
  static const Color cardBorder = Color(0x26FFFFFF); // 15%
  static const Color footerBg = Color(0xFF14101C);
}

class _EngineCardData {
  const _EngineCardData({
    required this.no,
    required this.title,
    required this.lines,
    required this.gradientColors,
    required this.icon,
  });

  final String no;
  final String title;
  final List<String> lines;
  final List<Color> gradientColors;
  final IconData icon;
}

class _PerspectiveData {
  const _PerspectiveData(this.icon, this.label);
  final IconData icon;
  final String label;
}

const List<_EngineCardData> _kEngineCards = [
  _EngineCardData(
    no: '01',
    title: '정통사주',
    lines: [
      '생년월일시를 입춘·12절기로',
      '경계와 60갑자 원리로 환산하고,',
      '오행 분포·십성 구조·신강신약을',
      '정해진 득점 규칙으로 산출합니다.',
    ],
    gradientColors: [Color(0xFF3B3350), Color(0xFF1C1830)],
    icon: Icons.auto_awesome,
  ),
  _EngineCardData(
    no: '02',
    title: '귀인지도',
    lines: [
      '일간·월지에 천을·문창·천덕·월덕',
      '귀인 구결(한자 원문)을 대입해,',
      '여덟 글자 안에 귀인이 뜨는',
      '자리와 그 궁위·방위를 판정합니다.',
    ],
    gradientColors: [Color(0xFF1E3A5F), Color(0xFF0E1E33)],
    icon: Icons.auto_graph,
  ),
  _EngineCardData(
    no: '03',
    title: '타로',
    lines: [
      '라이더-웨이트 원전(1911)의',
      '카드 정의에 따라 78장을',
      '중복 없이 셔플해 배치하고,',
      '자리 의미 × 카드 의미로 해석합니다.',
      '(시드로 재현·검증 가능)',
    ],
    gradientColors: [Color(0xFF2E2350), Color(0xFF160F2E)],
    icon: Icons.style,
  ),
  _EngineCardData(
    no: '04',
    title: '관상',
    lines: [
      '얼굴 랜드마크에서 삼정관',
      '비율과 인당·재백궁·관록궁을',
      '측정해 전통 관상 기준에',
      '대응시킵니다(같은 입력, 같은 판정).',
    ],
    gradientColors: [Color(0xFF4A3D43), Color(0xFF241C20)],
    icon: Icons.face_retouching_natural,
  ),
  _EngineCardData(
    no: '05',
    title: '손금',
    lines: [
      '생명·지혜·감정·운명 네 선의',
      '길이·휘어짐·끝점·분지를 측정해',
      '수상 주선 해석표에 대응시킵니다',
      '(생명선은 수명과 무관).',
    ],
    gradientColors: [Color(0xFF203A2E), Color(0xFF0F1D17)],
    icon: Icons.back_hand,
  ),
  _EngineCardData(
    no: '06',
    title: '대조',
    lines: [
      '관점별 판정을 여섯 차원',
      '(표현력·사고력·추진력·',
      '재물감각·방향성·조력)으로',
      '환산해 나란히 놓고,',
      '강함=2·보통=1·약함=0의',
      '최대편차로 일치·보완·긴장을 판별합니다.',
    ],
    gradientColors: [Color(0xFF2E2420), Color(0xFF160F0D)],
    icon: Icons.radar,
  ),
];

const List<_PerspectiveData> _kPerspectives = [
  _PerspectiveData(Icons.forum_rounded, '표현력'),
  _PerspectiveData(Icons.psychology_alt_rounded, '사고력'),
  _PerspectiveData(Icons.rocket_launch_rounded, '추진력'),
  _PerspectiveData(Icons.paid_rounded, '재물감각'),
  _PerspectiveData(Icons.explore_rounded, '방향성'),
  _PerspectiveData(Icons.diversity_3_rounded, '귀인 조력'),
];

class FortuneEngineIntroScreen extends StatelessWidget {
  const FortuneEngineIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _EngineIntroColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _HeroHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _EngineCardGrid(),
                    ),
                    const SizedBox(height: 24),
                    const _PerspectiveSection(),
                    const SizedBox(height: 24),
                    const _FooterPromise(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단 "뒤로가기" 바 — 사용자 요청 "안내페이지 상단에는 소비자가
/// 이전 화면으로 돌아갈 수 있도록 「뒤로가기」 버튼을 추가해 주세요"를
/// 그대로 반영. 첨부 디자인의 "< 뒤로가기 / 운세 엔진" 헤더 레이아웃.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          color: _EngineIntroColors.textPrimary,
                          size: 24,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '뒤로가기',
                          style: TextStyle(
                            color: _EngineIntroColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Text(
              '운세 엔진',
              style: TextStyle(
                color: _EngineIntroColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 히어로 영역 — "운세 엔진" 큰 타이틀 + 설명 카피 + 별/달 장식.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _EngineIntroColors.heroTop,
            _EngineIntroColors.heroBottom,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: 0,
            child: Icon(
              Icons.auto_awesome,
              size: 72,
              color: _EngineIntroColors.gold.withValues(alpha: 0.35),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '운세 엔진',
                style: TextStyle(
                  color: _EngineIntroColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '감으로 보는 운세가 아닙니다.',
                style: TextStyle(
                  color: _EngineIntroColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const Text(
                '전통의 기준으로 계산하고,\n그 근거를 보여드립니다.',
                style: TextStyle(
                  color: _EngineIntroColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 6개 엔진 카드 — 2열 그리드(첨부 디자인과 동일한 2x3 배치).
class _EngineCardGrid extends StatelessWidget {
  const _EngineCardGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kEngineCards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => _EngineCard(data: _kEngineCards[index]),
    );
  }
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({required this.data});
  final _EngineCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _EngineIntroColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _EngineIntroColors.gold.withValues(alpha: 0.18),
                  border: Border.all(
                    color: _EngineIntroColors.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  data.no,
                  style: const TextStyle(
                    color: _EngineIntroColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                data.icon,
                size: 18,
                color: _EngineIntroColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.title,
            style: const TextStyle(
              color: _EngineIntroColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              data.lines.join('\n'),
              style: const TextStyle(
                color: _EngineIntroColors.textSecondary,
                fontSize: 10.5,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "여섯 가지 관점으로 함께 봅니다" 섹션.
class _PerspectiveSection extends StatelessWidget {
  const _PerspectiveSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _EngineIntroColors.cardBorder),
        ),
        child: Column(
          children: [
            const Text(
              '여섯 가지 관점으로 함께 봅니다',
              style: TextStyle(
                color: _EngineIntroColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '사주, 귀인, 타로, 관상, 손금과 같은 여섯 가지 차원으로 정리해\n'
              '나란히 비교합니다. 서로 맞는 점과 보완되는 점, 주의할 점을\n'
              '한눈에 확인할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _EngineIntroColors.textSecondary,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _kPerspectives.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final p = _kPerspectives[index];
                return Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _EngineIntroColors.gold.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        p.icon,
                        size: 22,
                        color: _EngineIntroColors.gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.label,
                      style: const TextStyle(
                        color: _EngineIntroColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 "신통방통의 약속" 문구 배너.
class _FooterPromise extends StatelessWidget {
  const _FooterPromise();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: _EngineIntroColors.footerBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _EngineIntroColors.gold.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 4,
                  color: _EngineIntroColors.gold.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                const Text(
                  '신통방통의 약속',
                  style: TextStyle(
                    color: _EngineIntroColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.circle,
                  size: 4,
                  color: _EngineIntroColors.gold.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '운세를 지어내지 않습니다.',
              style: TextStyle(
                color: _EngineIntroColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '계산하고, 대조하고, 근거를 보여드립니다.',
              style: TextStyle(
                color: _EngineIntroColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
