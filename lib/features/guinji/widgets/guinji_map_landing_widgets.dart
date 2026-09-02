import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import 'guinji_map_widgets.dart';

/// [2026-09 새 디자인 리스킨] L(Landing) 화면 전용 조립 위젯. 새 디자인 zip
/// `lib/guiindo/widgets/hero_section.dart` 등을 그대로 이식했으며, 마케팅성
/// 콘텐츠(예시 비율·미리보기 카드)는 새 디자인의 하드코딩 값을 그대로
/// 유지한다(실제 지도 생성 전이라 실데이터가 없음 — 새 디자인 원본도 동일
/// 전제).

enum GmHeroVariant { host, participant }

class GmHeroSection extends StatelessWidget {
  const GmHeroSection({
    super.key,
    required this.variant,
    required this.hostName,
  });

  final GmHeroVariant variant;
  final String hostName;

  @override
  Widget build(BuildContext context) {
    final isParticipant = variant == GmHeroVariant.participant;
    return Stack(
      children: [
        const Positioned.fill(child: GmStarsBackground(opacity: 0.6)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GmChip(
                label: isParticipant ? '$hostName님이 초대했어요' : '신통방통 · 귀인지도',
                background: GmColors.rose50,
                borderColor: GmColors.rose100,
                foreground: GmColors.rose700,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: const GmDot(),
                fontSize: 11,
              ),
              const SizedBox(height: 16),
              Text(
                isParticipant ? '$hostName님의' : '나의',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: GmColors.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (r) =>
                    GmColors.gradientRoseText.createShader(r),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  '귀인 지도',
                  style: TextStyle(
                    fontFamily: GmFonts.serif,
                    fontSize: 40,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '당신의 인연과 관계를\n지도로 담았어요',
                style: TextStyle(fontSize: 14, height: 1.5, color: GmColors.inkSoft),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.asset(
                        'assets/images/hero-hanbok.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: GmColors.bgCream,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 96,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, GmColors.bgIvory],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _GmBodyText(
                '내 주변을 살펴보면 유난히 자신의 성장에만 힘이 되는, 나와 다른 인연이라 인식하지 못했던 ',
                bold: '귀인지도',
                boldTail: '가 있어요.',
              ),
              const SizedBox(height: 8),
              const _GmBodyText('귀인, 인연, 힘이 되는 사람, 서로 보완하는 관계까지 명확히 확인할 수 있어요.'),
              const SizedBox(height: 12),
              const Text(
                '친구가 참여하면\n내 관계 지도가 더 선명해져요.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: GmColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GmBodyText extends StatelessWidget {
  const _GmBodyText(this.text, {this.bold, this.boldTail});

  final String text;
  final String? bold;
  final String? boldTail;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13.5, height: 1.6, color: GmColors.inkSoft),
        children: [
          TextSpan(text: text),
          if (bold != null)
            TextSpan(
              text: bold,
              style: const TextStyle(fontWeight: FontWeight.w700, color: GmColors.ink),
            ),
          if (boldTail != null) TextSpan(text: boldTail),
        ],
      ),
    );
  }
}

/// 오늘 사주 미리보기 카드(마케팅용, L 화면 전용 예시 텍스트).
class GmPreviewCard extends StatelessWidget {
  const GmPreviewCard({super.key, required this.hostName});

  final String hostName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          border: Border.all(color: GmColors.line),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x26A6795E), blurRadius: 20, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GmChip(
              label: '오늘 사주 미리보기',
              background: Colors.white,
              borderColor: GmColors.rose200,
              foreground: GmColors.rose700,
            ),
            const SizedBox(height: 8),
            Text(
              '$hostName님은\n부드럽게 스미는\n불꽃형 🔥',
              style: const TextStyle(
                fontFamily: GmFonts.serif,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: GmColors.ink,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '타로/사주는 만세력 기반 결과예요. 짧은 힌트로 오늘의 관계 방향을 확인해요.',
              style: TextStyle(fontSize: 12, color: GmColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                GmChip(label: '#감성발달'),
                GmChip(label: '#절제'),
                GmChip(label: '#관계형 지도자'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 관계 요약(귀인/인연/보완/조심 4카드) — [guinjiCategoryOrder] 기반.
class GmRelationOverview extends StatelessWidget {
  const GmRelationOverview({super.key, required this.hostName});

  final String hostName;

  static const _ratios = {'boost': 92, 'path': 88, 'warm': 85, 'care': 35};
  static const _descs = {
    'boost': '서로 기운을 복돋는 최상위 관계',
    'path': '같이 걷기 좋은 방향의 사이',
    'warm': '서로 부족함을 채우는 결',
    'care': '거리와 리듬을 조율할 사이',
  };
  static const _symbols = {'boost': '✦', 'path': '❋', 'warm': '♡', 'care': '◈'};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        children: [
          const GmLabelMini('관계 요약'),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$hostName님과 나는\n서로 기운을 복돋우는\n', style: GmText.h2),
                TextSpan(
                  text: '귀인형 관계',
                  style: GmText.h2.copyWith(color: GmColors.rose700),
                ),
                TextSpan(text: '예요', style: GmText.h2),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '$hostName님과 함께 있으면\n어색함이 스르르 풀리고\n가슴 깊이 안심이 되는 특별한 인연이에요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, height: 1.6, color: GmColors.inkSoft),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: guinjiCategoryOrder
                .map(
                  (c) => _GmCategoryCard(
                    title: '${c.title} 관계',
                    ratio: _ratios[c.key] ?? 0,
                    desc: _descs[c.key] ?? c.subtitle,
                    color: GmColors.categoryColor(c.key),
                    symbol: _symbols[c.key] ?? '✦',
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _GmCategoryCard extends StatelessWidget {
  const _GmCategoryCard({
    required this.title,
    required this.ratio,
    required this.desc,
    required this.color,
    required this.symbol,
  });

  final String title;
  final int ratio;
  final String desc;
  final Color color;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(symbol, style: TextStyle(fontSize: 18, color: color)),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GmColors.ink)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 10.5, height: 1.3, color: GmColors.inkSoft)),
          const SizedBox(height: 6),
          Text('$ratio%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// 랜딩용 미니 노드 그래프(인터랙션 없음, 시각 요약).
class GmNodeMapPreview extends StatelessWidget {
  const GmNodeMapPreview({super.key, required this.hostName});

  final String hostName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GmColors.bgCream.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GmLabelMini('관계 지도'),
          const SizedBox(height: 4),
          const Text(
            '주요 관계 지도예요. 원의 크기와 거리로 관계의 결을 보여줘요.',
            style: TextStyle(fontSize: 13, color: GmColors.inkSoft),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              border: Border.all(color: GmColors.line),
              borderRadius: BorderRadius.circular(24),
            ),
            child: AspectRatio(
              aspectRatio: 320 / 240,
              child: CustomPaint(painter: _GmMiniGraphPainter(hostName: hostName)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '관계 한눈에 보기',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GmColors.ink),
          ),
          const SizedBox(height: 8),
          const _GmInsightRow(icon: '✦', title: '함께 있으면 좋은 순간', desc: '새로운 도전, 감정의 위로'),
          const _GmInsightRow(icon: '❋', title: '서로에게 힘이 되는 방향', desc: '배려가 관계를 유지시켜요'),
          const _GmInsightRow(icon: '◈', title: '관계를 위한 조언 한 마디', desc: '솔직한 대화가 관계의 열쇠예요'),
        ],
      ),
    );
  }
}

class _GmInsightRow extends StatelessWidget {
  const _GmInsightRow({required this.icon, required this.title, required this.desc});

  final String icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: GmColors.rose50, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 10, color: GmColors.rose700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: GmColors.ink)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: GmColors.inkSoft, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GmMiniGraphPainter extends CustomPainter {
  _GmMiniGraphPainter({required this.hostName});

  final String hostName;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = GmColors.line;
    _dashedCircle(canvas, Offset(cx, cy), size.width * 0.28, ringPaint);
    _dashedCircle(canvas, Offset(cx, cy), size.width * 0.17, ringPaint);

    final nodes = <_GmMiniNode>[
      _GmMiniNode(dx: -0.22, dy: -0.20, r: 12, color: GmColors.rose500, label: '귀인'),
      _GmMiniNode(dx: 0.22, dy: -0.24, r: 10, color: GmColors.gold, label: '인연'),
      _GmMiniNode(dx: -0.28, dy: 0.16, r: 9, color: GmColors.blush, label: '보완'),
      _GmMiniNode(dx: 0.25, dy: 0.24, r: 8, color: GmColors.rose800, label: '조심'),
      _GmMiniNode(dx: 0, dy: -0.30, r: 9, color: GmColors.rose500, label: '인연'),
    ];

    for (final n in nodes) {
      final x = cx + size.width * n.dx;
      final y = cy + size.height * n.dy;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(x, y),
        Paint()
          ..color = GmColors.rose300.withValues(alpha: 0.7)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), n.r, Paint()..color = n.color);
      _drawLabel(canvas, Offset(x, y), n.label, 6.5, Colors.white);
    }

    canvas.drawCircle(Offset(cx, cy), 22, Paint()..color = GmColors.ink);
    _drawLabel(canvas, Offset(cx, cy - 3), '$hostName님', 8.5, GmColors.ivory, weight: FontWeight.w700);
    _drawLabel(canvas, Offset(cx, cy + 8), '나', 7, GmColors.gold);
  }

  void _dashedCircle(Canvas c, Offset center, double radius, Paint paint) {
    const step = 6 / 180 * math.pi;
    for (double a = 0; a < math.pi * 2; a += step * 2) {
      final start = Offset(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius);
      final end = Offset(center.dx + math.cos(a + step) * radius, center.dy + math.sin(a + step) * radius);
      c.drawLine(start, end, paint);
    }
  }

  void _drawLabel(Canvas c, Offset o, String text, double size, Color color, {FontWeight weight = FontWeight.w600}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(c, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GmMiniNode {
  const _GmMiniNode({required this.dx, required this.dy, required this.r, required this.color, required this.label});

  final double dx, dy, r;
  final Color color;
  final String label;
}

/// 12라벨 카테고리 소개 섹션 — [guinjiRelationKeysByCategory] 기반.
class GmLabelCategoriesSection extends StatelessWidget {
  const GmLabelCategoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        children: [
          const GmLabelMini('라벨 시스템'),
          const SizedBox(height: 4),
          const Text(
            '12가지 결의 인연을\n결마다 다르게 읽어드려요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: GmFonts.serif,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: GmColors.ink,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          ...guinjiCategoryOrder.map((c) => _GmCategoryGroup(category: c)),
        ],
      ),
    );
  }
}

class _GmCategoryGroup extends StatelessWidget {
  const _GmCategoryGroup({required this.category});

  final GuinjiCategoryMeta category;

  @override
  Widget build(BuildContext context) {
    final color = GmColors.categoryColor(category.key);
    final keys = guinjiRelationKeysByCategory[category.key] ?? const [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          border: Border.all(color: GmColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(
                            category.title,
                            style: const TextStyle(fontFamily: GmFonts.serif, fontSize: 15, fontWeight: FontWeight.w700, color: GmColors.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(category.subtitle, style: const TextStyle(fontSize: 11, color: GmColors.inkSoft)),
                    ],
                  ),
                ),
                Text(
                  category.key.toUpperCase(),
                  style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: keys.map((key) {
                final meta = guinjiRelationTypes[key];
                return GmChip(
                  label: meta?.label ?? key,
                  background: color.withValues(alpha: 0.08),
                  foreground: color,
                  borderColor: color.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// L 하단 대형 CTA — 결과를 아직 안 본 시점이므로 내부 흐름(I 화면)으로만
/// 이동한다.
class GmUpsellCta extends StatelessWidget {
  const GmUpsellCta({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: GmDarkCtaShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GmFreeBadge(),
            const SizedBox(height: 12),
            const Text(
              '지금 바로, 나의 귀인지도를 만들어보세요',
              style: TextStyle(fontSize: 11, color: GmColors.gold, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              '내 귀인지도 만들기',
              style: TextStyle(fontFamily: GmFonts.serif, fontSize: 26, fontWeight: FontWeight.w700, color: GmColors.ivory, height: 1.15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '가입·결제 없이 바로 시작할 수 있어요.',
              style: TextStyle(fontSize: 12, color: GmColors.ivory.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GmRoseButton(label: '무료로 지금 시작하기', icon: Icons.arrow_forward, onPressed: onStart),
          ],
        ),
      ),
    );
  }
}

/// 소원방/타로/정통사주/오늘의 운세 그리드. 클릭 시 즉시 신통방통 내부
/// 라우트로 이동한다(딥링크 라우팅 존재 확인 완료 — `/wish-room`,
/// `/tarot/intro`, `/jeontong/eighty`; 오늘의 운세는 현재 안내 스텁으로
/// 대체되어 있다 — `/fortune/today/intro`).
class GmServiceGrid extends StatelessWidget {
  const GmServiceGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GmColors.bgCream.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        children: [
          const GmLabelMini('신통방통 다른 서비스'),
          const SizedBox(height: 4),
          const Text(
            '신통방통에서 더 많은 운세를 만나보세요',
            style: TextStyle(fontFamily: GmFonts.serif, fontSize: 18, fontWeight: FontWeight.w700, color: GmColors.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text.rich(
            const TextSpan(
              style: TextStyle(fontSize: 11.5, color: GmColors.inkSoft),
              children: [
                TextSpan(text: '모든 서비스 '),
                TextSpan(text: '100% 무료', style: TextStyle(color: GmColors.rose700, fontWeight: FontWeight.w700)),
                TextSpan(text: ' · 결제·구독 없음'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
            children: [
              _GmServiceCard(
                title: '소원방',
                desc: '간절한 소망을\n담아 빌어봐요',
                color: GmColors.blush,
                icon: Icons.local_fire_department_outlined,
                onTap: () => Navigator.of(context).pushNamed('/wish-room'),
              ),
              _GmServiceCard(
                title: '타로',
                desc: '오늘의 마음\n방향을 살펴요',
                color: GmColors.gold,
                icon: Icons.style_outlined,
                onTap: () => Navigator.of(context).pushNamed('/tarot/intro'),
              ),
              _GmServiceCard(
                title: '정통사주',
                desc: '만세력 기반\n정통 사주 풀이',
                color: GmColors.rose500,
                icon: Icons.brightness_5_outlined,
                onTap: () => Navigator.of(context).pushNamed('/jeontong/eighty'),
              ),
              _GmServiceCard(
                title: '오늘의 운세',
                desc: '매일 새롭게\n갱신되는 운세',
                color: GmColors.rose800,
                icon: Icons.wb_sunny_outlined,
                onTap: () => Navigator.of(context).pushNamed('/fortune/today/intro'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GmServiceCard extends StatelessWidget {
  const _GmServiceCard({
    required this.title,
    required this.desc,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title, desc;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          border: Border.all(color: GmColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: GmColors.rose500, borderRadius: BorderRadius.circular(9999)),
                child: const Text('FREE', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GmColors.ink)),
                const SizedBox(height: 2),
                Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: GmColors.inkSoft, height: 1.25)),
                const SizedBox(height: 4),
                const Text('바로가기 →', style: TextStyle(fontSize: 9.5, color: GmColors.rose700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GmFooterSection extends StatelessWidget {
  const GmFooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      color: GmColors.bgCream.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [GmColors.rose300, GmColors.rose600]),
                ),
                alignment: Alignment.center,
                child: const Text('신', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1)),
              ),
              const SizedBox(width: 8),
              const Text('신통방통', style: TextStyle(fontFamily: GmFonts.serif, fontSize: 13, fontWeight: FontWeight.w700, color: GmColors.ink)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '신통방통은 자체 만세력·관계 엔진을 기반으로 정확한 사주 콘텐츠를 제공합니다.',
            style: TextStyle(fontSize: 11, height: 1.6, color: GmColors.inkSoft),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Text('이용약관', style: TextStyle(fontSize: 11, color: GmColors.inkSoft)),
              SizedBox(width: 8),
              Text('·', style: TextStyle(color: GmColors.line)),
              SizedBox(width: 8),
              Text('개인정보처리방침', style: TextStyle(fontSize: 11, color: GmColors.inkSoft)),
              SizedBox(width: 8),
              Text('·', style: TextStyle(color: GmColors.line)),
              SizedBox(width: 8),
              Text('고객문의', style: TextStyle(fontSize: 11, color: GmColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('© 2026 Sintongbangtong. All rights reserved.', style: TextStyle(fontSize: 10, color: GmColors.inkFaint)),
        ],
      ),
    );
  }
}
