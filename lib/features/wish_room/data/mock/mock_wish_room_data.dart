import '../../domain/enums/customize_category.dart';
import '../models/customize_item_model.dart';
import '../models/wish_item_model.dart';
import '../models/wish_room_model.dart';
import '../models/fortune_pouch_status_model.dart';
import '../models/daily_message_model.dart';

/// [소원방 Riverpod 실험판] 서버 없이 화면을 바로 렌더링하기 위한 초기 mock 데이터.
///
/// [슬롯 시스템 반영] 대표 소원 1개(wish_1, 정성 누적치가 가장 높아 "환한
/// 촛불" 단계를 바로 보여줌) + 서브 소원 2개(wish_2는 성장 초기 "불씨",
/// wish_3은 "안정된 촛불") 구성. unlockedSubSlotCount=2로 두어 신규 화면
/// (꾸미기/슬롯 해금)의 "이미 서브 슬롯을 다 채운 사용자" 상태를 기본값으로
/// 보여준다 — 빈 상태/잠김 상태를 보고 싶으면 아래 값을 낮춰서 확인한다.
WishRoom buildMockWishRoom() {
  final now = DateTime.now();
  return WishRoom(
    userId: 'mock_user_1',
    wishes: [
      WishItem(
        id: 'wish_1',
        title: '건강하게 한 해를 보내게 해주세요',
        category: WishCategory.health,
        createdAt: now.subtract(const Duration(days: 12)),
        lastPrayedAt: now.subtract(const Duration(days: 1)),
        prayerCount: 5,
        isRepresentative: true,
        growthPoint: 135, // 환한 촛불(brightCandle) 단계 시연용
      ),
      WishItem(
        id: 'wish_2',
        title: '이번 시험에 꼭 합격하고 싶어요',
        category: WishCategory.exam,
        createdAt: now.subtract(const Duration(days: 6)),
        prayerCount: 2,
        isRepresentative: false,
        growthPoint: 10, // 불씨(ember) 단계 시연용
      ),
      WishItem(
        id: 'wish_3',
        title: '가족 모두 평안하게 지내게 해주세요',
        category: WishCategory.family,
        createdAt: now.subtract(const Duration(days: 20)),
        prayerCount: 9,
        isRepresentative: false,
        growthPoint: 75, // 안정된 촛불(steadyCandle) 단계 시연용
      ),
    ],
    totalPrayerCount: 16,
    consecutivePrayerDays: 3,
    unlockedSubSlotCount: 2,
    lastVisitedAt: now.subtract(const Duration(hours: 5)),
    // 오늘은 아직 기도하지 않은 상태로 시작(기본 상태 UI 확인용).
    lastPrayedDate: now.subtract(const Duration(days: 1)),
  );
}

FortunePouchStatus buildMockPouchStatus() => const FortunePouchStatus(
  totalCount: 6,
  usedToday: 0,
  earnedToday: 1,
  dailyFreeQuota: 1,
);

DailyMessage buildMockDailyMessage() => DailyMessage(
  id: 'msg_today',
  date: DateTime.now(),
  text: '마음이 향하는 곳에, 빛이 머뭅니다.',
  mood: MessageMood.warm,
);

/// [꾸미기 시스템] 초기 mock 카탈로그. 카테고리별 최소 2개(적용 중 1개
/// 포함)로 구성해 꾸미기 화면의 "보유/미보유/적용중" 3가지 상태를 모두
/// 화면에서 바로 확인할 수 있게 한다.
List<CustomizeItem> buildMockCustomizeCatalog() => const [
  CustomizeItem(
    id: 'obj_default',
    name: '기본 촛불',
    category: CustomizeCategory.objectSkin,
    unlockType: CustomizeUnlockType.growthReward,
    previewEmoji: '🕯️',
    isOwned: true,
    isApplied: true,
  ),
  CustomizeItem(
    id: 'obj_lotus_candle',
    name: '연꽃 촛대',
    category: CustomizeCategory.objectSkin,
    unlockType: CustomizeUnlockType.purchase,
    previewEmoji: '🪷',
    pouchPrice: 12,
  ),
  CustomizeItem(
    id: 'altar_wood',
    name: '나무 제단',
    category: CustomizeCategory.altar,
    unlockType: CustomizeUnlockType.growthReward,
    previewEmoji: '🪵',
    isOwned: true,
    isApplied: true,
  ),
  CustomizeItem(
    id: 'altar_marble',
    name: '대리석 제단',
    category: CustomizeCategory.altar,
    unlockType: CustomizeUnlockType.purchase,
    previewEmoji: '⬜',
    pouchPrice: 20,
  ),
  CustomizeItem(
    id: 'bg_night_sky',
    name: '밤하늘',
    category: CustomizeCategory.background,
    unlockType: CustomizeUnlockType.growthReward,
    previewEmoji: '🌌',
    isOwned: true,
    isApplied: true,
  ),
  CustomizeItem(
    id: 'bg_temple',
    name: '고요한 사찰',
    category: CustomizeCategory.background,
    unlockType: CustomizeUnlockType.streakReward,
    unlockThreshold: 7,
    previewEmoji: '⛩️',
  ),
  CustomizeItem(
    id: 'fx_gold_sparkle',
    name: '금빛 파동',
    category: CustomizeCategory.effect,
    unlockType: CustomizeUnlockType.growthReward,
    previewEmoji: '✨',
    isOwned: true,
    isApplied: true,
  ),
  CustomizeItem(
    id: 'fx_petal',
    name: '꽃잎 흩날림',
    category: CustomizeCategory.effect,
    unlockType: CustomizeUnlockType.purchase,
    previewEmoji: '🌸',
    pouchPrice: 15,
  ),
  CustomizeItem(
    id: 'deco_lantern',
    name: '작은 초롱',
    category: CustomizeCategory.decoration,
    unlockType: CustomizeUnlockType.purchase,
    previewEmoji: '🏮',
    pouchPrice: 8,
    isOwned: true,
    isApplied: true,
  ),
  CustomizeItem(
    id: 'deco_crane',
    name: '종이 학',
    category: CustomizeCategory.decoration,
    unlockType: CustomizeUnlockType.purchase,
    previewEmoji: '🕊️',
    pouchPrice: 10,
  ),
  CustomizeItem(
    id: 'season_lunar_new_year',
    name: '설맞이 테마',
    category: CustomizeCategory.seasonalTheme,
    unlockType: CustomizeUnlockType.eventLimited,
    previewEmoji: '🧧',
  ),
];
