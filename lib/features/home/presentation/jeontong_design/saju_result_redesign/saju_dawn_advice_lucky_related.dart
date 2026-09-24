// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper] 伍(FIVE) 실전 조언 +
// 陸(SIX) 행운 요소 + 柒(SEVEN) 관련 운세 + Footer/BottomActions.
//
// HTML `.advice-grid`(吉/忌 2열 카드) · `.lucky-grid`(2×2 Color/
// Direction/Number/Keyword) · `.rel-list`(2열 카드) · `.footer-meta`·
// `.actions`(하단 고정 CTA)를 그대로 옮긴다. 값은 모두
// `saju_dawn_data_builder.dart`가 이미 실계산으로 채운
// [SajuResultData.doList]/[.avoidList]/[.lucky]/[.related]/[.userRefId]를
// 그대로 그린다(재계산 없음 — 순수 렌더링).
// ============================================================

import 'package:flutter/material.dart';

import 'saju_dawn_data_models.dart';
import 'saju_dawn_ilgan_theme.dart';
import 'saju_dawn_tokens.dart';

// ------------------------------------------------------------
// 伍(FIVE) 실전 조언 — 吉(이롭게 하는 일) / 忌(조심할 점) 2열.
// ------------------------------------------------------------
class SajuDawnAdviceGrid extends StatelessWidget {
  final List<String> doList;
  final List<String> avoidList;
  final IlganTheme ilganTheme;

  const SajuDawnAdviceGrid({
    super.key,
    required this.doList,
    required this.avoidList,
    required this.ilganTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _AdviceCard(
            hanja: '吉',
            title: '이롭게 하는 일',
            items: doList.isEmpty ? const ['아직 정리된 항목이 없습니다.'] : doList,
            badgeColor: ilganTheme.main,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AdviceCard(
            hanja: '忌',
            title: '조심할 점',
            items: avoidList.isEmpty ? const ['아직 정리된 항목이 없습니다.'] : avoidList,
            badgeColor: SajuDawnColors.terracotta,
          ),
        ),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final String hanja;
  final String title;
  final List<String> items;
  final Color badgeColor;

  const _AdviceCard({
    required this.hanja,
    required this.title,
    required this.items,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: SajuDawnColors.paper,
        border: Border.all(color: SajuDawnColors.line),
        borderRadius: BorderRadius.circular(SajuDawnRadius.small),
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
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hanja,
                  style: const TextStyle(
                    fontFamily: SajuDawnFonts.serif,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.72,
                    color: SajuDawnColors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '· ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SajuDawnColors.ink3,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: SajuDawnColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 陸(SIX) 행운 요소 — Color / Direction / Number / Keyword 2×2.
// ------------------------------------------------------------
class SajuDawnLuckyGrid extends StatelessWidget {
  final LuckyItems lucky;
  final IlganTheme ilganTheme;

  const SajuDawnLuckyGrid({super.key, required this.lucky, required this.ilganTheme});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.05,
      children: [
        _LuckyCell(
          label: 'COLOR',
          value: lucky.color.name,
          sub: lucky.color.note,
          visual: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colorFromHex(lucky.color.hex),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(-1, -1)),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            ),
          ),
        ),
        _LuckyCell(
          label: 'DIRECTION',
          value: lucky.direction.name,
          sub: lucky.direction.note,
          visual: _CompassIcon(angle: lucky.direction.angle),
        ),
        _LuckyCell(
          label: 'NUMBER',
          value: lucky.numbers.join(' · '),
          sub: '오행에 이로운 수',
          visual: Text(
            lucky.numbers.isNotEmpty ? '${lucky.numbers.first}' : '-',
            style: const TextStyle(
              fontFamily: SajuDawnFonts.serif,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: SajuDawnColors.goldDeep,
              height: 1,
            ),
          ),
        ),
        _LuckyCell(
          label: 'KEYWORD',
          value: lucky.keyword.name,
          sub: lucky.keyword.note,
          visual: Text(
            lucky.keyword.hanja,
            style: TextStyle(
              fontFamily: SajuDawnFonts.serif,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ilganTheme.main,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Color _colorFromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16) ?? 0xB8A6D8;
    return Color(0xFF000000 | value);
  }
}

class _CompassIcon extends StatelessWidget {
  final double angle;
  const _CompassIcon({required this.angle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: SajuDawnColors.fire, width: 1.2),
            ),
          ),
          Transform.rotate(
            angle: angle,
            child: Container(
              width: 2,
              height: 9,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: SajuDawnColors.fire,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LuckyCell extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Widget visual;

  const _LuckyCell({
    required this.label,
    required this.value,
    required this.sub,
    required this.visual,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: SajuDawnColors.paper,
        border: Border.all(color: SajuDawnColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SajuDawnColors.paper2,
              border: Border.all(color: SajuDawnColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: visual,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: SajuDawnColors.ink3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: SajuDawnFonts.serif,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.14,
                    color: SajuDawnColors.ink,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: SajuDawnColors.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 柒(SEVEN) 관련 운세 — 2열 카드, 탭하면 [onTap] 콜백(라우팅은 호출부).
// ------------------------------------------------------------
class SajuDawnRelatedGrid extends StatelessWidget {
  final List<RelatedFortune> related;
  final void Function(RelatedFortune)? onTap;

  const SajuDawnRelatedGrid({super.key, required this.related, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (related.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '관련 운세가 아직 준비되지 않았습니다.',
          style: TextStyle(fontSize: 13, color: SajuDawnColors.ink3),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: related.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (context, i) {
        final item = related[i];
        return Material(
          color: SajuDawnColors.paper,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap == null ? null : () => onTap!(item),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: SajuDawnColors.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: SajuDawnColors.goldDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: SajuDawnFonts.serif,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.14,
                      color: SajuDawnColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '보기 →',
                    style: TextStyle(fontSize: 11, color: SajuDawnColors.ink3),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Footer meta — "내 사주 반영 · #userRefId" + 카피라이트.
// ------------------------------------------------------------
class SajuDawnFooterMeta extends StatelessWidget {
  final String userRefId;
  const SajuDawnFooterMeta({super.key, required this.userRefId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
      child: Column(
        children: [
          Container(width: 24, height: 1, color: SajuDawnColors.line2),
          const SizedBox(height: 12),
          Text(
            '내 사주 반영 · $userRefId',
            style: const TextStyle(fontSize: 11, height: 1.7, color: SajuDawnColors.ink3, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 6),
          const Text(
            '신통 정통사주는 참고 자료로 활용해 주세요.',
            style: TextStyle(fontSize: 11, height: 1.7, color: SajuDawnColors.ink3),
          ),
          const SizedBox(height: 2),
          const Text(
            '© SINTONG · 神通',
            style: TextStyle(fontSize: 11, height: 1.7, color: SajuDawnColors.ink3),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Bottom action bar — "다른 운세 보러가기" + 저장/공유 아이콘 버튼.
// ------------------------------------------------------------
class SajuDawnBottomActionBar extends StatelessWidget {
  final VoidCallback? onPrimary;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const SajuDawnBottomActionBar({
    super.key,
    this.onPrimary,
    this.onSave,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 20 + bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SajuDawnColors.bg.withValues(alpha: 0),
            SajuDawnColors.bg.withValues(alpha: 0.96),
          ],
          stops: const [0.0, 0.3],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SajuDawnColors.ink,
                  foregroundColor: SajuDawnColors.paper,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SajuDawnRadius.button),
                  ),
                ),
                child: const Text(
                  '다른 운세 보러가기',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SquareIconButton(icon: Icons.bookmark_border_rounded, onTap: onSave),
          const SizedBox(width: 8),
          _SquareIconButton(icon: Icons.share_outlined, onTap: onShare),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SquareIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SajuDawnColors.paper,
      borderRadius: BorderRadius.circular(SajuDawnRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(SajuDawnRadius.button),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: SajuDawnColors.line),
            borderRadius: BorderRadius.circular(SajuDawnRadius.button),
          ),
          child: Icon(icon, size: 20, color: SajuDawnColors.ink2),
        ),
      ),
    );
  }
}
