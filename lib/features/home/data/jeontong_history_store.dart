// 2026-08-14. 정통사주 결과 열람 이력을 in-memory 로만 기록/조회.
// dart:core 만 사용 (HTTP/AI/IO 없음). 영속화 없음 — 앱 재시작 시 초기화됨.
//
// [STEP 0-C 실측 결과] 미션 템플릿이 가정한 경로
// (lib/features/fortune/jeontong/data/, widget.userId/categoryCode/
// reportTitle/reportSubtitle)는 실제 코드베이스에 존재하지 않는다.
// 실제로는 lib/features/home/presentation/jeontong_eighty_result_screen.dart
// 하나뿐이며, JeontongEightyResultScreen은 categoryId(String?)만 받고,
// title/subtitle에 해당하는 값은 _ResultBody.build() 내부의 지역 변수
// entry(JeontongCategoryEntry)/report(FortuneReport)로만 존재한다.
// 이에 맞춰 record() 호출부는 그 지역 변수들에서 값을 취한다(STEP 1-D 참고).

/// 화면 카드 표시용 최소 이력 항목. 원본 스키마와 무관.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.subtitle,
    required this.createdAtUtc,
  });

  final String id;
  final String categoryId;
  final String title;
  final String subtitle;
  final DateTime createdAtUtc;
}

/// 정통사주 결과 열람 이력의 in-memory singleton store.
/// 새 Provider/Repository/Service 가 아니라 순수 dart:core 클래스.
class JeontongHistoryStore {
  JeontongHistoryStore._();

  static final JeontongHistoryStore instance = JeontongHistoryStore._();

  final Map<String, List<HistoryEntry>> _byUser =
      <String, List<HistoryEntry>>{};

  /// 결과 화면 진입 시 1회 호출. 같은 (userId, categoryId) 조합이 이미
  /// 있으면 새로 push 하지 않고 기존 1건을 최신 값으로 갱신한다(dedup).
  /// 이에 따라 사용자당 categoryId 1건 = 최대 80건(A01~H10)으로 자연
  /// 상한된다.
  void record({
    required String userId,
    required String categoryId,
    required String title,
    required String subtitle,
    required DateTime createdAtUtc,
  }) {
    _byUser.putIfAbsent(userId, () => <HistoryEntry>[]);
    final list = _byUser[userId]!;
    // dedup: 같은 categoryId 가 이미 있으면 1건으로 갱신
    for (var i = 0; i < list.length; i++) {
      if (list[i].id.startsWith('$categoryId-$userId-')) {
        list[i] = HistoryEntry(
          id: '$categoryId-$userId-${createdAtUtc.microsecondsSinceEpoch}',
          categoryId: categoryId,
          title: title,
          subtitle: subtitle,
          createdAtUtc: createdAtUtc,
        );
        return;
      }
    }
    list.add(
      HistoryEntry(
        id: '$categoryId-$userId-${createdAtUtc.microsecondsSinceEpoch}',
        categoryId: categoryId,
        title: title,
        subtitle: subtitle,
        createdAtUtc: createdAtUtc,
      ),
    );
  }

  /// 해당 userId 의 이력 스냅샷(불변 복사본)을 반환한다.
  List<HistoryEntry> list(String userId) {
    final list = _byUser[userId];
    if (list == null) return const <HistoryEntry>[];
    return List<HistoryEntry>.unmodifiable(list);
  }

  /// 테스트 전용 — 상태 초기화.
  void clearForTest() => _byUser.clear();
}
