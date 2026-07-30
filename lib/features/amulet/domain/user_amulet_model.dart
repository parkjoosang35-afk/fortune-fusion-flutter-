import 'amulet_item_model.dart';

/// 04A 도메인H `user_amulets`(H-3, status: held/used/expired/gifted) 대응 모델
enum UserAmuletStatus { held, used, expired, gifted }

UserAmuletStatus _statusFromCode(String code) {
  return UserAmuletStatus.values.firstWhere(
    (s) => s.name == code,
    orElse: () => UserAmuletStatus.held,
  );
}

class UserAmuletModel {
  final String id;
  final AmuletItemModel item;
  final UserAmuletStatus status;
  final DateTime acquiredAt;
  final DateTime? expiresAt;
  final String sourceType; // purchase/event/gift/luckybag
  // [실API 전환] admin_web UserAmulet 스키마에 isEquipped 컬럼이 없어(H-3 도메인표
  // 승인 시 미포함) 서버에 저장되지 않는다. 장착 UI는 클라이언트 로컬 상태로만
  // 유지하며(앱 재시작 시 초기화), 향후 서버 지원이 필요하면 컬럼 추가 검토.
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

  /// GET /api/public/amulets/my 대응 — 응답에 pricePoint/isLimited가 없으므로
  /// 보유 목록 표시에는 영향 없는 기본값(0/false)으로 채운다.
  factory UserAmuletModel.fromJson(Map<String, dynamic> json) {
    final gradeCode = json['gradeCode'] as String? ?? 'common';
    return UserAmuletModel(
      id: json['id'] as String,
      item: AmuletItemModel(
        id: json['itemId'] as String,
        name: json['itemName'] as String,
        grade: AmuletGrade.byCode(gradeCode),
        effectDescription: json['effectDescription'] as String? ?? '',
        iconEmoji: AmuletItemModel.iconForGrade(gradeCode, false),
        pricePoint: 0,
      ),
      status: _statusFromCode(json['status'] as String? ?? 'held'),
      acquiredAt: DateTime.parse(json['acquiredAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      sourceType: json['sourceType'] as String? ?? 'purchase',
    );
  }

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
