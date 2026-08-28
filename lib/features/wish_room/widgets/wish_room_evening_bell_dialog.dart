import 'package:flutter/material.dart';

import '../domain/evening_bell_notification_service.dart';
import '../theme/wish_room_theme.dart';

/// [Phase C-1] 저녁 7시 종소리 알림 — 온보딩 마지막 단계에서 노출되는
/// 옵트인 다이얼로그.
///
/// [UI 원칙] 절대원칙(UI 느낌표 금지)을 지켜 문구에 "!"를 사용하지 않는다.
/// [설계] 이 다이얼로그는 결과와 무관하게(권한 거부 포함) 항상 정상적으로
/// 닫히며, 온보딩 흐름 자체를 막지 않는다 — 리마인더는 부가 기능이다.
Future<void> showEveningBellOptInDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => const _EveningBellOptInDialog(),
  );
}

class _EveningBellOptInDialog extends StatefulWidget {
  const _EveningBellOptInDialog();

  @override
  State<_EveningBellOptInDialog> createState() =>
      _EveningBellOptInDialogState();
}

class _EveningBellOptInDialogState extends State<_EveningBellOptInDialog> {
  bool _processing = false;

  Future<void> _accept() async {
    setState(() => _processing = true);
    await EveningBellNotificationService.enable();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _decline() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: WishRoomColors.backgroundSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            const Text(
              '저녁 종소리를 들려드릴까요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoSerifKRWish',
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: WishRoomColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '매일 저녁 7시, 소원방에서\n은은한 종소리로 알려드려요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: WishRoomColors.textSecondary,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: WishRoomColors.glow,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _processing ? null : _accept,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: _processing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFF2A1A0A),
                            ),
                          )
                        : const Text(
                            '종소리 받기',
                            style: TextStyle(
                              fontFamily: 'GowunBatangWish',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF2A1A0A),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _processing ? null : _decline,
                child: const Text(
                  '나중에 할게요',
                  style: TextStyle(color: WishRoomColors.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
