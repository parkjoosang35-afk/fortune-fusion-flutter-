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
    // [반응형 화면 규격 통일 — 잘림 현상 수정] 공용 바텀시트 헬퍼가 높이
    // 제한 없이 Padding+Column(mainAxisSize:min)만 사용해, 본문(child)이
    // 길거나 글자 확대가 큰 조합에서 화면 높이를 초과했다. 실측(행운상자
    // 확률공개 시트 경유): 320x568@1.5 55px, @2.0 585px, @2.5 2152px
    // RenderFlex 오버플로. ConstrainedBox(maxHeight: 90%)+
    // SingleChildScrollView로 감싸 넘칠 때만 스크롤되게 한다(디자인/제목/
    // 본문 내용 변경 없음, 이 헬퍼를 쓰는 모든 화면에 공통 적용됨).
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.9,
      ),
      child: SingleChildScrollView(
        child: Padding(
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
      ),
    ),
  );
}
