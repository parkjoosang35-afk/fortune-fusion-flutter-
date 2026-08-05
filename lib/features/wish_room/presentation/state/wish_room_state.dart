import '../../data/models/wish_room_model.dart';
import '../../data/models/wish_item_model.dart';
import '../../data/models/fortune_pouch_status_model.dart';
import '../../data/models/daily_message_model.dart';
import '../../data/models/wish_room_visual_state_model.dart';
import '../../data/models/customize_item_model.dart';

/// AsyncNotifier가 들고 있는 "성공 시 데이터 전체" — 서버/영속 상태 묶음.
class WishRoomData {
  final WishRoom room;
  final FortunePouchStatus pouchStatus;
  final DailyMessage dailyMessage;
  final bool isFirstVisit;

  /// [꾸미기 시스템] 꾸미기 카탈로그. 메인 화면 진입 시점에는 비어 있을 수
  /// 있으며(꾸미기 화면 진입 시 최초 로드), 로드 후에는 여기에 캐시되어
  /// 메인 화면의 "적용된 배경/이펙트" 표시에도 재사용된다.
  final List<CustomizeItem> customizeCatalog;

  const WishRoomData({
    required this.room,
    required this.pouchStatus,
    required this.dailyMessage,
    required this.isFirstVisit,
    this.customizeCatalog = const [],
  });

  /// 서버 데이터로부터 파생되는 시각 상태(매번 재계산, 별도 저장하지 않음).
  WishRoomVisualState get visualState => WishRoomVisualState.fromRoom(
    consecutivePrayerDays: room.consecutivePrayerDays,
    hasPrayedToday: room.hasPrayedToday,
    representativeGrowthStage:
        room.representativeWish?.growthStage ?? WishGrowthStage.ember,
  );

  WishRoomData copyWith({
    WishRoom? room,
    FortunePouchStatus? pouchStatus,
    DailyMessage? dailyMessage,
    bool? isFirstVisit,
    List<CustomizeItem>? customizeCatalog,
  }) {
    return WishRoomData(
      room: room ?? this.room,
      pouchStatus: pouchStatus ?? this.pouchStatus,
      dailyMessage: dailyMessage ?? this.dailyMessage,
      isFirstVisit: isFirstVisit ?? this.isFirstVisit,
      customizeCatalog: customizeCatalog ?? this.customizeCatalog,
    );
  }
}
