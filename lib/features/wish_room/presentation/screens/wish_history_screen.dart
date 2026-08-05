import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wish_room_providers.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/growth_progress_card.dart';
import '../widgets/wish_card.dart';

/// [소원방 Riverpod 실험판] 내 소원 기록/히스토리 화면.
/// 전체 소원 리스트(대표 소원 포함)를 노출한다.
class WishHistoryScreen extends ConsumerWidget {
  const WishHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(wishRoomControllerProvider);

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('내 소원 기록', style: WishRoomTextStyles.titleLg),
        iconTheme: const IconThemeData(color: WishRoomColors.textPrimary),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: WishRoomColors.backgroundGradient,
        ),
        child: SafeArea(
          top: false,
          child: asyncData.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: WishRoomColors.gold),
            ),
            error: (err, st) => Center(
              child: Text('잠시 후 다시 시도해주세요', style: WishRoomTextStyles.bodyMd),
            ),
            data: (data) {
              if (data.room.wishes.isEmpty) {
                return Center(
                  child: Text(
                    '지금까지 당신이 품어온 마음들',
                    style: WishRoomTextStyles.bodyMd,
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(WishRoomSpacing.md),
                itemCount: data.room.wishes.length,
                itemBuilder: (context, index) {
                  final wish = data.room.wishes[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: WishRoomSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: WishCard(wish: wish),
                        ),
                        const SizedBox(height: WishRoomSpacing.sm),
                        GrowthProgressCard(wish: wish),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
