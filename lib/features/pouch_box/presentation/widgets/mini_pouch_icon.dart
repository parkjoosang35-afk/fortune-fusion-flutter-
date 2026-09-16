import 'package:flutter/material.dart';
import '../../../../theme/lucky_box_tokens.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §3-1 `<MiniPouch>` →
/// `MiniPouchIcon` 매핑. 원본 스펙은 SVG asset을 지정했으나, 이 프로젝트에는
/// 전용 복주머니 SVG 벡터 에셋이 없어(하단바 아이콘은 PNG) 브랜드 이모지
/// (🧧, dev-spec.md §0 원칙6 "이모지는 오직 아이콘 자리에만" 허용 범위 내)로
/// 대체한다. lit=true일 때만 골드 글로우를 추가해 "발광" 느낌을 재현한다.
class MiniPouchIcon extends StatelessWidget {
  final double size;
  final bool lit;

  const MiniPouchIcon({super.key, this.size = 20, this.lit = false});

  @override
  Widget build(BuildContext context) {
    final content = Text('🧧', style: TextStyle(fontSize: size));
    if (!lit) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: LuckyBoxTokens.accentGold.withValues(alpha: 0.55),
            blurRadius: size * 0.6,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
      child: content,
    );
  }
}
