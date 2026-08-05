import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wish_item_model.dart';
import '../../data/repositories/wish_room_repository.dart';
import '../../data/mock/mock_wish_room_repository.dart';
import '../state/wish_room_state.dart';
import '../state/wish_room_ui_state.dart';
import '../controllers/wish_room_controller.dart';
import '../controllers/wish_room_ui_controller.dart';

/// [소원방 Riverpod 실험판] 전역 Provider 정의부.
///
/// 교체 지점: 실 API 연동 시 이 한 줄만 HttpWishRoomRepository 등으로
/// 바꾸면 Controller/위젯 코드는 전혀 손댈 필요가 없다.
final wishRoomRepositoryProvider = Provider<WishRoomRepository>((ref) {
  return MockWishRoomRepository();
});

/// 서버/영속 데이터(WishRoomData) — 로딩/에러/데이터를 AsyncValue로 표현.
final wishRoomControllerProvider =
    AsyncNotifierProvider<WishRoomController, WishRoomData>(
      WishRoomController.new,
    );

/// 화면 흐름/팝업/애니메이션 트리거 등 순수 UI 상태.
final wishRoomUiProvider =
    NotifierProvider<WishRoomUiController, WishRoomUiState>(
      WishRoomUiController.new,
    );

/// 파생 셀렉터 예시 — "오늘 기도 여부"만 구독하는 위젯이 room 전체 변경에
/// 불필요하게 rebuild 되지 않도록 별도 Provider로 분리한다.
final hasPrayedTodayProvider = Provider<bool>((ref) {
  final data = ref.watch(wishRoomControllerProvider).valueOrNull;
  return data?.room.hasPrayedToday ?? false;
});

/// [슬롯 시스템] 서브 슬롯을 스트릭만으로 무료 해금할 수 있는지(정책표 ①:
/// 연속 3일 방문 시 1번째 서브 슬롯, 7일 시 2번째 서브 슬롯 무료 해금).
/// 정책 임계값 자체는 [WishRoom.canUnlockNextSlotByStreak]에 일원화되어
/// 있으므로 이 Provider는 순수 위임만 한다.
final canUnlockSlotByStreakProvider = Provider<bool>((ref) {
  final data = ref.watch(wishRoomControllerProvider).valueOrNull;
  return data?.room.canUnlockNextSlotByStreak ?? false;
});

/// [소원 성장 시스템] 대표 소원 자체(없으면 null)만 구독하는 파생 셀렉터.
/// `WishRoomObject`/`GrowthProgressCard` 등 대표 소원 변경에만 반응해야
/// 하는 위젯이 room 전체 변경(예: pouchStatus만 바뀌는 경우)에 불필요하게
/// rebuild 되지 않도록 분리한다.
final representativeWishProvider = Provider<WishItem?>((ref) {
  final data = ref.watch(wishRoomControllerProvider).valueOrNull;
  return data?.room.representativeWish;
});

/// [소원 성장 시스템] 대표 소원의 성장 단계만 구독하는 파생 셀렉터.
/// 대표 소원이 없으면 가장 낮은 단계(ember)를 기본값으로 반환한다 —
/// `WishRoomVisualState.fromRoom()`과 동일한 기본값 규칙을 따른다.
final representativeGrowthStageProvider = Provider<WishGrowthStage>((ref) {
  final wish = ref.watch(representativeWishProvider);
  return wish?.growthStage ?? WishGrowthStage.ember;
});

/// [슬롯 시스템] 다음 서브 슬롯 해금까지 남은 연속 방문일수(이미 모두
/// 해금됐으면 null). 슬롯 확장 화면의 안내 문구 계산을 화면 코드에서
/// 분리해 재사용 가능하게 한다.
final remainingStreakForNextSlotProvider = Provider<int?>((ref) {
  final data = ref.watch(wishRoomControllerProvider).valueOrNull;
  if (data == null) return null;
  final required = data.room.requiredStreakForNextSlot;
  if (required == null) return null;
  final remaining = required - data.room.consecutivePrayerDays;
  return remaining > 0 ? remaining : 0;
});
