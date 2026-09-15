// ═══════════════════════════════════════════════════════════════
// FILE: sintong_healing_bar.dart
// [신통방통 메인 매핑] C-03 · HealingBar — Handoff.html §06
// 🌿 아이콘 + "오늘의 힐링 한마디" 라벨(sage 11px/600) + 본문 2줄
// (inkSoft 12.5px/1.5).
//
// [기능 보존] admin_web `/api/public/healing-quotes` 기반 자동 순환 로직
// (HealingQuoteProvider)과 로그인 시 닉네임 개인화("{닉네임}님, ...")는
// 기존 `_HealingQuoteCard`와 완전히 동일하게 유지한다. 변경된 것은 오직
// 시각 스타일(배경/패딩 없는 순수 텍스트 블록 → 새 스펙 레이아웃, 본문
// 2줄 허용)뿐이다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../auth/application/auth_provider.dart';
import '../../../../healing_quote/application/healing_quote_provider.dart';
import '../sintong_home_tokens.dart';

class SintongHealingBar extends StatelessWidget {
  const SintongHealingBar({super.key});

  @override
  Widget build(BuildContext context) {
    final healing = context.watch<HealingQuoteProvider>();
    final quote = healing.current;

    final auth = context.watch<AuthProvider>();
    final nickname = auth.isLoggedIn ? auth.currentUser?.nickname : null;
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final labelText = hasNickname ? '$nickname님, 오늘의 힐링 한마디' : '오늘의 힐링 한마디';
    final quoteText = quote?.content ?? '힘들다고 느끼는 그 순간, 당신은 이미 성장하고 있는 중입니다.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Text('🌿', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labelText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SintongHomeText.healingLabel,
              ),
              const SizedBox(height: 3),
              Text(
                quoteText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SintongHomeText.body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
