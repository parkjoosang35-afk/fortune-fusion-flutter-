import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/wish_post_provider.dart';

/// [소원성(Wish Castle) 확장] "성취 후기" 작성 바텀시트.
///
/// 서버(reviews API)가 candleLevel<4인 소원은 400으로 거부하므로, 호출부(UI)는
/// `post.isMaxLevel`일 때만 진입점을 노출한다(wish_detail_screen 참고). 관리자가
/// CMS에서 수동 선정(isFeatured)한 후기만 "명예의 전당"에 노출되며, 이 시트는
/// 등록까지만 담당하고 선정 여부는 이 화면에서 확인할 수 없다(과설계 방지).
Future<bool> showWishReviewSheet(
  BuildContext context, {
  required String wishId,
}) async {
  final content = await showAppBottomSheet<String>(
    context,
    title: '성취 후기 남기기',
    child: const _WishReviewForm(),
  );
  if (content == null || content.trim().isEmpty || !context.mounted) {
    return false;
  }

  final ok = await context.read<WishPostProvider>().submitReview(
    wishId,
    content.trim(),
  );
  if (!context.mounted) return ok;

  AppToast.show(
    context,
    ok ? '후기가 등록되었어요. 소중한 이야기 감사해요 🌟' : '후기 등록에 실패했습니다.',
    isError: !ok,
  );
  return ok;
}

class _WishReviewForm extends StatefulWidget {
  const _WishReviewForm();

  @override
  State<_WishReviewForm> createState() => _WishReviewFormState();
}

class _WishReviewFormState extends State<_WishReviewForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '가장 밝은 불꽃에 도달한 소원의 이야기를 남겨주세요.\n관리자가 선정한 후기는 소원성 명예의 전당에 소개될 수 있어요.',
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: '소원을 이루기까지의 이야기를 자유롭게 남겨보세요.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: '후기 등록하기',
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
