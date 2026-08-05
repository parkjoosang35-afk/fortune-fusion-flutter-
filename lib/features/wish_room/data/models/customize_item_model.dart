import '../../domain/enums/customize_category.dart';

/// [꾸미기 시스템] 방을 꾸미는 개별 아이템(스킨/제단/배경/이펙트/장식/시즌테마).
///
/// 소유(owned)와 적용(isApplied)은 분리된 상태다 — 구매/해금해도 자동으로
/// 적용되지 않으며, 사용자가 꾸미기 화면에서 명시적으로 "적용하기"를 눌러야
/// 방에 반영된다(단, [CustomizeCategory.allowsMultiple]인 장식류는 여러 개를
/// 동시에 적용 상태로 둘 수 있다).
class CustomizeItem {
  final String id;
  final String name;
  final CustomizeCategory category;
  final CustomizeUnlockType unlockType;

  /// purchase 타입일 때만 유효한 복주머니 가격. growthReward/streakReward/
  /// eventLimited 아이템은 항상 0(무료 해금 조건 충족 시 자동 획득).
  final int pouchPrice;

  /// growthReward/streakReward 해금에 필요한 임계값(성장 단계 인덱스 또는
  /// 연속일수). unlockType이 purchase/eventLimited면 사용하지 않음(null).
  final int? unlockThreshold;

  final bool isOwned;
  final bool isApplied;

  /// 미리보기/썸네일 표시용 이모지(MVP 단계는 실제 이미지 대신 이모지로
  /// 대체 — 정책표 ⑧ 참고, 실 아트 리소스 교체 전까지의 임시 표기).
  final String previewEmoji;

  const CustomizeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unlockType,
    required this.previewEmoji,
    this.pouchPrice = 0,
    this.unlockThreshold,
    this.isOwned = false,
    this.isApplied = false,
  });

  CustomizeItem copyWith({bool? isOwned, bool? isApplied}) {
    return CustomizeItem(
      id: id,
      name: name,
      category: category,
      unlockType: unlockType,
      previewEmoji: previewEmoji,
      pouchPrice: pouchPrice,
      unlockThreshold: unlockThreshold,
      isOwned: isOwned ?? this.isOwned,
      isApplied: isApplied ?? this.isApplied,
    );
  }
}
