import 'package:shared_preferences/shared_preferences.dart';

import '../domain/wish_wall_models.dart';

/// 소원함 개봉(Box Opening) 자동 트리거 — 로컬 근사치 구현.
///
/// [Phase 01 · 2단계 · orphan 화면 연결] `03-dev-spec.html`의 원래 스펙은
/// 서버 `GET /wishes/pending-openings`(Prisma `unlockAt`/`openedBoxAt` 필드
/// 필요 — Phase02 스키마 확장 몫)를 조회해 결과 배열이 있으면 개봉 화면을
/// 띄우는 것이다. 아직 그 서버 필드가 없으므로, Phase01에서는 클라이언트
/// 전용 근사치로 구현한다:
/// - "100일 지난 소원" = [WishPost.createdAt] 기준 100일 이상 경과.
/// - 이미 개봉 화면을 보여준 소원은 [SharedPreferences]에 id를 저장해
///   다시 보여주지 않는다(서버 `openedBoxAt`의 로컬 대역).
/// Phase02에서 실제 `unlockAt`/`openedBoxAt`/`state` 필드가 생기면 이
/// 파일의 판정 로직만 서버 응답 기반으로 교체하면 된다(호출부인
/// [WishRoomHomeScreen]은 변경할 필요 없음).
///
/// [자동 트리거 안전장치 — 과거 버그 재발 방지] 이 체크는 반드시
/// `enableBoxOpeningCheck: true`로 명시적으로 생성된 [WishRoomHomeScreen]
/// 인스턴스에서만 호출되어야 한다(즉 [WishRoomEntryGate]를 통해 사용자가
/// 실제로 "소원방" 카드/라우트를 탭했을 때만). `AppShell`의 `IndexedStack`
/// 탭처럼 앱 시작 시점에 미리 생성되는 인스턴스에서 이 체크가 실행되면,
/// 사용자가 아무것도 누르지 않았는데 전체화면 개봉 연출이 갑자기
/// 뜨는(=과거에 고쳤던 "자동 복주머니 지급" 버그와 동일한 종류의) 문제가
/// 재발한다.
const String _kOpenedBoxIdsPrefsKey = 'wish_room_opened_box_ids';

/// 소원함 개봉으로 간주하는 최소 경과일.
const int wishRoomBoxOpeningThresholdDays = 100;

/// [wishes] 중 100일 이상 지났고 아직 로컬에서 "개봉 화면을 보여준 적
/// 없음"인 소원이 있으면 그 중 가장 오래된 것의 id를 반환한다. 없으면 null.
Future<String?> findPendingBoxOpeningWishId(List<WishPost> wishes) async {
  if (wishes.isEmpty) return null;
  Set<String> opened;
  try {
    final prefs = await SharedPreferences.getInstance();
    opened = (prefs.getStringList(_kOpenedBoxIdsPrefsKey) ?? const []).toSet();
  } catch (_) {
    opened = const {};
  }

  final now = DateTime.now();
  WishPost? oldest;
  for (final wish in wishes) {
    if (opened.contains(wish.id)) continue;
    final age = now.difference(wish.createdAt).inDays;
    if (age < wishRoomBoxOpeningThresholdDays) continue;
    if (oldest == null || wish.createdAt.isBefore(oldest.createdAt)) {
      oldest = wish;
    }
  }
  return oldest?.id;
}

/// [wishId]를 "개봉 화면을 이미 보여줬음"으로 로컬에 표시한다. 저장 실패는
/// 조용히 무시한다(다음 방문에 한 번 더 뜨는 정도는 허용 가능한 실패).
Future<void> markWishBoxOpened(String wishId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final opened = (prefs.getStringList(_kOpenedBoxIdsPrefsKey) ?? const [])
        .toSet();
    opened.add(wishId);
    await prefs.setStringList(_kOpenedBoxIdsPrefsKey, opened.toList());
  } catch (_) {
    // 저장 실패 - 무시.
  }
}
