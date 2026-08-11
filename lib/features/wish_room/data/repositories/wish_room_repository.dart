import '../../domain/enums/prayer_type.dart';
import '../models/wish_item_model.dart';
import '../models/wish_room_model.dart';
import '../models/fortune_pouch_status_model.dart';
import '../models/daily_message_model.dart';
import '../models/prayer_session_model.dart';
import '../models/customize_item_model.dart';
import '../models/guide_slide_model.dart';

/// 화면이 최초 진입 시 한 번에 받는 데이터 묶음.
class WishRoomBundle {
  final WishRoom room;
  final FortunePouchStatus pouchStatus;
  final DailyMessage dailyMessage;
  final bool isFirstVisit;

  const WishRoomBundle({
    required this.room,
    required this.pouchStatus,
    required this.dailyMessage,
    required this.isFirstVisit,
  });
}

/// [소원방 Riverpod 실험판] Repository 인터페이스.
///
/// 교체 지점: 실 API 연동 시 이 인터페이스의 새 구현체(예:
/// HttpWishRoomRepository)를 만들어 providers/wish_room_providers.dart의
/// wishRoomRepositoryProvider 한 줄만 바꾸면 된다. Controller/위젯은
/// 항상 이 인터페이스로만 접근하므로 다른 코드는 변경할 필요가 없다.
abstract class WishRoomRepository {
  Future<WishRoomBundle> fetchInitialData();

  Future<WishItem> addWish({
    required String title,
    required WishCategory category,
  });

  Future<void> setRepresentative(
    String wishId, {
    required bool isRepresentative,
  });

  /// [치성 시스템] 통합 치성 실행 API. [type]에 따라 필요 복주머니 수량과
  /// 성장 포인트 증가량이 결정된다(PrayerTypeX 참고). daily는 하루 1회
  /// 무료이므로 호출측(Controller)이 hasPrayedToday를 먼저 확인해야 한다.
  Future<PrayerSession> prayForWish({
    required String wishId,
    required PrayerType type,
  });

  Future<void> markGuideSeen();

  /// [가이드 슬라이드] 관리자 CMS가 편집한 "이용 방법" 풀스크린 슬라이드
  /// 목록을 가져온다. 문구/이미지/노출순서는 전부 서버가 확정한다
  /// (§ "관리자 설정값 하드코딩 금지" 원칙).
  Future<List<GuideSlide>> fetchGuideSlides();

  /// [슬롯 시스템] 서브 슬롯 1개를 해금한다. [viaPouch]가 true면 복주머니
  /// 결제로 즉시 해금(정책표 ① 참고), false면 스트릭 조건 충족으로 무료 해금.
  /// 반환값: 해금 후 소원방 최신 상태.
  Future<WishRoom> unlockSubSlot({required bool viaPouch});

  /// [꾸미기 시스템] 전체 카탈로그(보유/적용 상태 포함)를 가져온다.
  Future<List<CustomizeItem>> fetchCustomizeCatalog();

  /// [꾸미기 시스템] 복주머니로 아이템을 구매한다(성공 시 isOwned=true로 갱신).
  Future<List<CustomizeItem>> purchaseCustomizeItem(String itemId);

  /// [꾸미기 시스템] 보유 중인 아이템을 방에 적용한다. 같은 카테고리의
  /// 기존 적용 아이템은 자동 해제된다(장식 카테고리는 다중 적용 허용).
  Future<List<CustomizeItem>> applyCustomizeItem(String itemId);
}
