import 'package:flutter/material.dart';

import '../../domain/enums/prayer_type.dart';
import '../../data/models/fortune_pouch_status_model.dart';
import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';

/// [필수 화면 ④ 치성/정성 담기 화면] 어떤 방식으로 정성을 담을지 고르는
/// 바텀시트. 오늘의 치성(무료, 하루 1회)/깊은 치성(복주머니1개)/집중
/// 치성(복주머니3개) 3가지를 카드 형태로 나열하고, 각 카드에는 필요
/// 복주머니 수량과 예상 성장치 증가량을 함께 보여준다(정책표 ②③).
///
/// 반환값: 사용자가 선택한 [PrayerType], 취소 시 null.
class PrayerTypeSheet extends StatelessWidget {
  final WishItem wish;
  final FortunePouchStatus pouchStatus;
  final bool hasPrayedToday;

  const PrayerTypeSheet({
    super.key,
    required this.wish,
    required this.pouchStatus,
    required this.hasPrayedToday,
  });

  static Future<PrayerType?> show(
    BuildContext context, {
    required WishItem wish,
    required FortunePouchStatus pouchStatus,
    required bool hasPrayedToday,
  }) {
    return showModalBottomSheet<PrayerType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PrayerTypeSheet(
        wish: wish,
        pouchStatus: pouchStatus,
        hasPrayedToday: hasPrayedToday,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        WishRoomSpacing.lg,
        WishRoomSpacing.lg,
        WishRoomSpacing.lg,
        WishRoomSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: WishRoomColors.backgroundMid,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WishRoomRadius.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${wish.title}"에\n어떻게 정성을 담을까요?',
              style: WishRoomTextStyles.titleLg,
            ),
            const SizedBox(height: WishRoomSpacing.lg),
            _buildOption(
              context,
              type: PrayerType.daily,
              enabled: !hasPrayedToday,
              disabledReason: '오늘은 이미 다녀갔어요. 내일 다시 만나요',
            ),
            const SizedBox(height: WishRoomSpacing.sm),
            _buildOption(
              context,
              type: PrayerType.deep,
              enabled: pouchStatus.totalCount >= PrayerType.deep.pouchCost,
              disabledReason: '복주머니가 부족해요',
            ),
            const SizedBox(height: WishRoomSpacing.sm),
            _buildOption(
              context,
              type: PrayerType.focused,
              enabled: pouchStatus.totalCount >= PrayerType.focused.pouchCost,
              disabledReason: '복주머니가 부족해요',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required PrayerType type,
    required bool enabled,
    required String disabledReason,
  }) {
    final cost = type.pouchCost;
    final gain = type.growthPointGain;

    return GestureDetector(
      onTap: enabled ? () => Navigator.of(context).pop(type) : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(WishRoomSpacing.md),
          decoration: BoxDecoration(
            color: WishRoomColors.surfaceCard,
            borderRadius: BorderRadius.circular(WishRoomRadius.md),
            border: Border.all(color: WishRoomColors.surfaceCardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: WishRoomTextStyles.bodyMd.copyWith(
                        color: WishRoomColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: WishRoomSpacing.xs),
                    Text(
                      enabled
                          ? (cost == 0
                                ? '오늘 하루 무료로 마음을 전해요'
                                : '복주머니 $cost개로 정성을 더해요')
                          : disabledReason,
                      style: WishRoomTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (enabled)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+$gain',
                      style: WishRoomTextStyles.titleLg.copyWith(
                        color: WishRoomColors.goldSoft,
                        fontSize: 18,
                      ),
                    ),
                    Text('성장치', style: WishRoomTextStyles.caption),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
