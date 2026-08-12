import 'package:flutter/material.dart';

import '../domain/wish_counsel_models.dart';

/// 캐릭터 아바타 — `04_DESIGN_TOKENS.md` §5-6/부록 A `<Avatar>` 매핑.
/// conic-gradient 링은 ShaderMask 대신 카테고리 glow 컬러의 단색 원형
/// 테두리로 단순화(성능/구현 복잡도 절충).
class WishCounselAvatar extends StatelessWidget {
  const WishCounselAvatar({
    super.key,
    required this.character,
    this.size = 48,
    this.ring = true,
    this.online = false,
  });

  final CounselCharacter character;
  final double size;
  final bool ring;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final glow = character.theme.glow;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(ring ? 2 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: ring ? Border.all(color: glow, width: 1.6) : null,
          ),
          child: ClipOval(
            child: Image.asset(
              character.avatarAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: character.theme.bg2,
                child: Icon(Icons.person, color: glow),
              ),
            ),
          ),
        ),
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6FE3A0),
                border: Border.all(color: const Color(0xFF14141F), width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
