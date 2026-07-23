import 'amulet_item_model.dart';

/// 04A 도메인H `user_amulets`(H-3, status: held/used/expired/gifted) 대응 모델
enum UserAmuletStatus { held, used, expired, gifted }

class UserAmuletModel {
  final String id;
  final AmuletItemModel item;
  final UserAmuletStatus status;
  final DateTime acquiredAt;
  final DateTime? expiresAt;
  final String sourceType; // purchase/event/gift/luckybag
  final bool isEquipped;

  const UserAmuletModel({
    required this.id,
    required this.item,
    required this.status,
    required this.acquiredAt,
    this.expiresAt,
    required this.sourceType,
    this.isEquipped = false,
  });

  UserAmuletModel copyWith({UserAmuletStatus? status, bool? isEquipped}) {
    return UserAmuletModel(
      id: id,
      item: item,
      status: status ?? this.status,
      acquiredAt: acquiredAt,
      expiresAt: expiresAt,
      sourceType: sourceType,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }
}

/// 04A `amulet_collections`(H-6) 대응 - 도감 진행률 표시용
class AmuletCollectionEntry {
  final AmuletItemModel item;
  final DateTime firstAcquiredAt;
  final int totalCount;

  const AmuletCollectionEntry({
    required this.item,
    required this.firstAcquiredAt,
    required this.totalCount,
  });
}
