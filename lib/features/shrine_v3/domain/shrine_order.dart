import 'talisman_item.dart';

/// admin_web `toOrderDto()`/`toBoxItemDto()`/box 상세 응답과 1:1 매핑되는
/// 唯一(unique) 부적 주문 1건. 서버가 계산한 값(일련번호/사주/만료일/남은
/// 일수)을 그대로 표시만 한다 — 클라이언트는 어떤 값도 재계산하지 않는다.
class ShrineOrder {
  const ShrineOrder({
    required this.orderId,
    required this.serial,
    required this.ownerName,
    required this.sajuPillars,
    required this.wish,
    required this.issuedDateKey,
    required this.expiresDateKey,
    required this.daysRemaining,
    required this.displayStatus,
    required this.incenseLitToday,
    required this.talisman,
  });

  final int orderId;
  final String serial;
  final String ownerName;
  final String sajuPillars;
  final String wish;
  final String issuedDateKey;
  final String expiresDateKey;
  final int daysRemaining;

  /// 'ACTIVE' | 'EXPIRED' | 'ARCHIVED' (README §1 10행 상태 표기).
  final String displayStatus;

  final bool incenseLitToday;

  final ShrineOrderTalismanRef talisman;

  bool get isActive => displayStatus == 'ACTIVE';
  bool get isExpired => displayStatus == 'EXPIRED';
  bool get isArchived => displayStatus == 'ARCHIVED';

  factory ShrineOrder.fromJson(Map<String, dynamic> json) => ShrineOrder(
    orderId: json['orderId'] as int,
    serial: json['serial'] as String,
    ownerName: json['ownerName'] as String,
    sajuPillars: json['sajuPillars'] as String,
    wish: json['wish'] as String,
    issuedDateKey: json['issuedDateKey'] as String,
    expiresDateKey: json['expiresDateKey'] as String,
    daysRemaining: json['daysRemaining'] as int,
    displayStatus:
        json['displayStatus'] as String? ?? json['status'] as String? ?? 'ACTIVE',
    incenseLitToday: json['incenseLitToday'] as bool? ?? false,
    talisman: ShrineOrderTalismanRef.fromJson(
      json['talisman'] as Map<String, dynamic>,
    ),
  );
}

/// box/order 응답 내 `talisman` 하위 객체(카탈로그 전체 [TalismanItem]보다
/// 필드가 적은 축약형 — slug/category/hanja/name/imagePath/thumbPath 등).
class ShrineOrderTalismanRef {
  const ShrineOrderTalismanRef({
    required this.slug,
    required this.category,
    required this.hanja,
    required this.name,
    this.aim,
    required this.imagePath,
    this.thumbPath,
  });

  final String slug;
  final String category;
  final String hanja;
  final String name;
  final String? aim;
  final String imagePath;
  final String? thumbPath;

  factory ShrineOrderTalismanRef.fromJson(Map<String, dynamic> json) =>
      ShrineOrderTalismanRef(
        slug: json['slug'] as String,
        category: json['category'] as String,
        hanja: json['hanja'] as String,
        name: json['name'] as String,
        aim: json['aim'] as String?,
        imagePath: json['imagePath'] as String? ?? '',
        thumbPath: json['thumbPath'] as String?,
      );
}

/// GET /shrine/box 응답의 summary 블록.
class ShrineBoxSummary {
  const ShrineBoxSummary({
    required this.active,
    required this.expired,
    required this.archived,
  });

  final int active;
  final int expired;
  final int archived;

  factory ShrineBoxSummary.fromJson(Map<String, dynamic> json) =>
      ShrineBoxSummary(
        active: json['active'] as int? ?? 0,
        expired: json['expired'] as int? ?? 0,
        archived: json['archived'] as int? ?? 0,
      );
}

/// GET /shrine/box/:id 상세 응답 — [ShrineOrder] 필드 + 부적 상세 설명.
class ShrineOrderDetail {
  const ShrineOrderDetail({required this.order, required this.talismanDetail});

  final ShrineOrder order;

  /// 상세 화면(10)이 필요로 하는 부적 전체 설명(§6 설명 섹션).
  final TalismanItem talismanDetail;

  factory ShrineOrderDetail.fromJson(Map<String, dynamic> json) {
    final talismanJson = Map<String, dynamic>.from(
      json['talisman'] as Map<String, dynamic>,
    );
    // TalismanItem.fromJson은 'id'(slug) 키를 요구하지만 이 응답은 'slug' 키로
    // 내려온다 — 상세 응답 스키마에 맞춰 보정한다.
    talismanJson['id'] ??= talismanJson['slug'];
    return ShrineOrderDetail(
      order: ShrineOrder.fromJson(json),
      talismanDetail: TalismanItem.fromJson(talismanJson),
    );
  }
}

/// POST /shrine/box/:id/incense 응답.
class ShrineIncenseResult {
  const ShrineIncenseResult({
    required this.orderId,
    required this.daysBefore,
    required this.daysAfter,
    required this.expiresDateKey,
  });

  final int orderId;
  final int daysBefore;
  final int daysAfter;
  final String expiresDateKey;

  factory ShrineIncenseResult.fromJson(Map<String, dynamic> json) =>
      ShrineIncenseResult(
        orderId: json['orderId'] as int,
        daysBefore: json['daysBefore'] as int,
        daysAfter: json['daysAfter'] as int,
        expiresDateKey: json['expiresDateKey'] as String,
      );
}
