import '../domain/wish_wall_models.dart';
import 'wish_room_seal.dart';

/// [공유 매핑] 기존 [WishCategory](9종, 소원벽 데이터 모델)를 V2 디자인의
/// 6종 [WishSeal](願/合/康/福/緣/財)로 사상한다.
///
/// [wish_room_home_screen.dart]에 이미 있던 private `_sealForCategory`
/// 함수와 동일한 매핑을 공유 위치로 옮겨, 03 Compose/05 Detail/06 Feed
/// 신규 화면들도 같은 규칙을 재사용하도록 한다(발명 금지 — 이미 검증된
/// 매핑 그대로 사용).
WishSeal sealForCategory(WishCategory c) {
  switch (c) {
    case WishCategory.exam:
    case WishCategory.job:
      return WishSeal.pass;
    case WishCategory.money:
      return WishSeal.wealth;
    case WishCategory.love:
    case WishCategory.family:
      return WishSeal.bond;
    case WishCategory.health:
      return WishSeal.health;
    case WishCategory.travel:
    case WishCategory.growth:
    case WishCategory.etc:
      return WishSeal.wish;
  }
}

/// 반대 방향(Seal → 대표 Category 1개) — 06 Feed의 필터칩(합격/건강/인연/
/// 재물/평안)이 내부적으로는 여전히 [WishCategory] 기반 API
/// ([WishWallProvider.loadFeed]의 categoryFilter 등)를 사용해야 하므로 필요.
/// '평안'은 디자인 원본에 대응하는 단일 카테고리가 없어 growth로 근사한다.
WishCategory primaryCategoryForSeal(WishSeal seal) {
  switch (seal) {
    case WishSeal.pass:
      return WishCategory.exam;
    case WishSeal.health:
      return WishCategory.health;
    case WishSeal.bond:
      return WishCategory.love;
    case WishSeal.wealth:
      return WishCategory.money;
    case WishSeal.wish:
      return WishCategory.growth;
    case WishSeal.fortune:
      return WishCategory.growth;
  }
}
