// ═══════════════════════════════════════════════════════════════
// FILE: sintong_free_pass_bar.dart
// [신통방통 메인 매핑] C-07 · FreePassBar — Handoff.html §06
// 검정 pill(bg #0F0F0F, radius999, height50) — 좌측 자물쇠+"프리패스"
// 라벨, 우측 원형 green(ctaGreen) 화살표. 탭 시 구독/프리패스 화면 이동.
//
// [기능 보존] 기존 `_OpenPassBottomBar`의 실시간 남은시간 표시(1초 tick,
// AccessChecker.canAccessFortuneScope/openPassState) 로직을 그대로
// 유지하고 시각 스타일만 새 스펙으로 재구현한다.
// ═══════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/domain/access/access_checker.dart';
import '../../../../pass/presentation/pass_time_format.dart';
import '../sintong_home_tokens.dart';

class SintongFreePassBar extends StatefulWidget {
  const SintongFreePassBar({super.key});

  @override
  State<SintongFreePassBar> createState() => _SintongFreePassBarState();
}

class _SintongFreePassBarState extends State<SintongFreePassBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessChecker>();
    final isActive = access.canAccessFortuneScope();
    final remainingLabel = isActive
        ? formatPassHms(access.openPassState.remaining)
        : null;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/free-pass-gate'),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: SintongHomeColors.inkBlack,
          borderRadius: BorderRadius.circular(SintongHomeRadii.pill),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            const Text(
              '프리패스',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (isActive && remainingLabel != null) ...[
              const SizedBox(width: 6),
              Text(
                '· $remainingLabel',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SintongHomeColors.ctaGreen,
                ),
              ),
            ],
            const Spacer(),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: SintongHomeColors.ctaGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF4A5A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
