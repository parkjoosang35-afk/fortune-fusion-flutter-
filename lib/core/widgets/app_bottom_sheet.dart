import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 03단계 §9.1 공통 컴포넌트 - BottomSheet 표준 (Phase1-1 보강)
/// 드래그 핸들/제목/스크롤 가능 본문을 표준화하여 각 Phase(글쓰기, 필터,
/// 옵션 선택 등)에서 재사용한다. (community_screen의 인라인 BottomSheet도
/// 향후 이 헬퍼로 교체하여 중복 제거 가능 - 이번 소단위 범위 밖, 별도 제안)
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Theme.of(context).cardTheme.color ?? AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: Theme.of(
              ctx,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ),
  );
}
