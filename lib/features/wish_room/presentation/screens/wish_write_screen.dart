import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wish_item_model.dart';
import '../providers/wish_room_providers.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/category_chip_group.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';

/// [소원방 Riverpod 실험판] 소원 작성/선택 화면.
/// 직접 입력 + 추천 카테고리 칩 선택 지원. 저장 시 메인으로 복귀한다.
class WishWriteScreen extends ConsumerStatefulWidget {
  const WishWriteScreen({super.key});

  @override
  ConsumerState<WishWriteScreen> createState() => _WishWriteScreenState();
}

class _WishWriteScreenState extends ConsumerState<WishWriteScreen> {
  final _controller = TextEditingController();
  WishCategory? _selectedCategory;
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _selectedCategory == null || _isSaving) return;

    setState(() => _isSaving = true);
    await ref
        .read(wishRoomControllerProvider.notifier)
        .addWish(title: title, category: _selectedCategory!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        _controller.text.trim().isNotEmpty && _selectedCategory != null;

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      // [디자인 핸드오프 — "마법진이 소환되는 신전"] README `3. Compose Wish`
      // 스펙: 다른 화면들과 동일한 대기(atmosphere) 배경(마법진+먼지 파티클)
      // 위에 콘텐츠가 놓인다. 기존 단색 그라디언트(DecoratedBox)를
      // [WishRoomBackground]로 교체하고, 콘텐츠 전체에 화면 진입 연출
      // [DramaticEntrance]를 적용한다. 내부 로직(TextEditingController,
      // 카테고리 선택, _save 등)은 전혀 건드리지 않는다.
      body: Stack(
        children: [
          const Positioned.fill(child: WishRoomBackground()),
          SafeArea(
          child: DramaticEntrance(
          child: Padding(
            padding: const EdgeInsets.all(WishRoomSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: WishRoomColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: WishRoomSpacing.sm),
                Text(
                  '오늘의 마음을 담아\n조용히 소원을 빌어보세요',
                  style: WishRoomTextStyles.titleLg,
                ),
                const SizedBox(height: WishRoomSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(WishRoomSpacing.md),
                  decoration: BoxDecoration(
                    color: WishRoomColors.surfaceCard,
                    borderRadius: BorderRadius.circular(WishRoomRadius.md),
                    border: Border.all(color: WishRoomColors.surfaceCardBorder),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: 3,
                    maxLength: 60,
                    style: WishRoomTextStyles.bodyMd.copyWith(
                      color: WishRoomColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '이루고 싶은 소원을 적어보세요',
                      hintStyle: WishRoomTextStyles.caption,
                      counterStyle: WishRoomTextStyles.caption,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: WishRoomSpacing.lg),
                Text('어떤 마음에 정성을 담고 싶으신가요?', style: WishRoomTextStyles.bodySm),
                const SizedBox(height: WishRoomSpacing.sm),
                CategoryChipGroup(
                  selected: _selectedCategory,
                  onSelected: (category) =>
                      setState(() => _selectedCategory = category),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSave
                          ? WishRoomColors.gold
                          : WishRoomColors.surfaceCard,
                      padding: const EdgeInsets.symmetric(
                        vertical: WishRoomSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          WishRoomRadius.pill,
                        ),
                      ),
                    ),
                    onPressed: canSave ? _save : null,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '소원 담기',
                            style: WishRoomTextStyles.ctaLabel.copyWith(
                              color: canSave
                                  ? WishRoomColors.backgroundDeep
                                  : WishRoomColors.textTertiary,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          ),
          ),
        ],
      ),
    );
  }
}
