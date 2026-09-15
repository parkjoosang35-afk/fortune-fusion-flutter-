// ═══════════════════════════════════════════════════════════════
// FILE: sintong_service_tile.dart
// [신통방통 메인 매핑] C-06 · ServiceTile — Handoff.html §06
// 썸네일(56×56, radius12) + 서비스명(Fraunces italic 18) + 설명
// (Pretendard 11px inkMute) + 우측 원형 액션 버튼(34×34).
// card-warm 변형(손금·관상)은 배경 cardTint(#FAF6EE) + border 투명.
//
// [4번째 카드 = 손금/관상 통합] index.html 실제 목업 기준으로 4번째
// 서비스는 "손금/관상" 통합 카드이며, 탭하면 기존 관상·손금 선택
// 바텀시트([showFacePalmSelectSheet])를 그대로 띄운다(라우팅 변경 없음).
//
// [그리드 모드] ModeChipRow의 그리드 스위치를 눌렀을 때는 2열 그리드로
// 배치되는 컴팩트 버전(_SintongServiceGridTile)을 함께 제공한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../sintong_home_tokens.dart';

enum SintongActionStyle { primary, dark, rose }

class SintongServiceSpec {
  const SintongServiceSpec({
    required this.thumbAsset,
    required this.name,
    required this.description,
    required this.actionStyle,
    required this.onTap,
    this.cardWarm = false,
  });

  final String thumbAsset;
  final String name;
  final String description;
  final SintongActionStyle actionStyle;
  final VoidCallback onTap;
  final bool cardWarm;
}

Color _actionBg(SintongActionStyle style) {
  switch (style) {
    case SintongActionStyle.primary:
      return SintongHomeColors.ctaGreen;
    case SintongActionStyle.dark:
      return SintongHomeColors.ink;
    case SintongActionStyle.rose:
      return SintongHomeColors.rose;
  }
}

Color _actionFg(SintongActionStyle style) {
  switch (style) {
    case SintongActionStyle.primary:
      return const Color(0xFF4A5A1A);
    case SintongActionStyle.dark:
    case SintongActionStyle.rose:
      return Colors.white;
  }
}

/// 리스트형(라이브러리 스타일) 서비스 카드 — 기본 뷰.
class SintongServiceTile extends StatelessWidget {
  const SintongServiceTile({super.key, required this.spec});

  final SintongServiceSpec spec;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: spec.onTap,
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(SintongHomeSpacing.cardInteriorPad),
        decoration: BoxDecoration(
          color: spec.cardWarm
              ? SintongHomeColors.cardTint
              : SintongHomeColors.background,
          borderRadius: BorderRadius.circular(SintongHomeRadii.lg),
          border: spec.cardWarm
              ? null
              : Border.all(color: SintongHomeColors.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(SintongHomeRadii.md),
              child: Image.asset(
                spec.thumbAsset,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(spec.name, style: SintongHomeText.serviceName()),
                  const SizedBox(height: 4),
                  Text(
                    spec.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SintongHomeText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _actionBg(spec.actionStyle),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _actionFg(spec.actionStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 그리드형(2열) 서비스 카드 — ModeChipRow 스위치로 전환 시 사용.
class SintongServiceGridTile extends StatelessWidget {
  const SintongServiceGridTile({super.key, required this.spec});

  final SintongServiceSpec spec;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: spec.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: spec.cardWarm
              ? SintongHomeColors.cardTint
              : SintongHomeColors.background,
          borderRadius: BorderRadius.circular(SintongHomeRadii.lg),
          border: spec.cardWarm
              ? null
              : Border.all(color: SintongHomeColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(SintongHomeRadii.md),
                  child: Image.asset(
                    spec.thumbAsset,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _actionBg(spec.actionStyle),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: _actionFg(spec.actionStyle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(spec.name, style: SintongHomeText.serviceName()),
            const SizedBox(height: 3),
            Text(
              spec.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SintongHomeText.caption,
            ),
          ],
        ),
      ),
    );
  }
}
