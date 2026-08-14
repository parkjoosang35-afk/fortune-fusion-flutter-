// 2026-08-14. 사용자 히스토리 5개 섹션을 화면 소비용 값 객체로만 노출.
// 원본 컬렉션/스키마 무수정, 편집 API 미노출.
//
// [STEP 0-B/C/D 실측 결과] 이 미션이 가정한 정적 store 클래스
// (TarotHistoryStore/CounselHistoryStore/FaceHistoryStore/PalmHistoryStore/
// JeontongHistoryStore)는 실제 코드베이스에 존재하지 않는다. 실측된 실제
// 구조는 다음과 같다:
//   · 타로/관상/손금/AI사주: XxxProvider.history (ChangeNotifier 필드,
//     BuildContext 필요, loadHistory() 비동기 호출 후에만 채워짐 —
//     "dart:core 만, 새 Provider/Repository/Service 금지" 원칙 위반 없이는
//     이 화면 밖에서 동기적으로 끌어올 방법이 없다).
//   · 상담(wish_counsel): 영속 히스토리 저장소 자체가 없다(세션은
//     WishCounselProvider._session 단일 필드로만 존재, 리스트 아님).
//   · 정통사주: MyFortuneRecordStore.list()가 유일한 실제 저장소이나
//     Future<List<SavedFortuneRecord>>(SharedPreferences 비동기)이며, 이
//     미션이 요구하는 동기 `List<HistoryReadOnlyEntry> readXxx()` 시그니처와
//     근본적으로 맞지 않는다(await 없이 값을 꺼낼 수 없음).
//
// 미션 원칙 "존재하지 않는 클래스는 해당 섹션을 빈 리스트 반환으로 폴백"에
// 따라, 5개 섹션 모두 원본을 새로 손대지 않고 빈 리스트로 폴백한다.
//
// [2026-08-14 추가] 정통사주 vertical slice: JeontongHistoryStore
// (lib/features/home/data/jeontong_history_store.dart, dart:core 전용
// in-memory singleton)가 신설되어 readJeontong() 1개 메서드만 실제 데이터를
// 반환하도록 갱신한다. 나머지 4개 메서드(readTarot/readCounsel/readFace/
// readPalm)는 이전 미션 상태(빈 리스트 폴백) 그대로 무수정.

import '../../home/data/jeontong_history_store.dart' as jeontong_store;

/// 화면 전용 read-only 카드 표시 값. 원본 스키마와 무관하게 최소 필드만.
class HistoryReadOnlyEntry {
  const HistoryReadOnlyEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });
  final String id;
  final String title;
  final String subtitle;
  final DateTime createdAt; // UTC
}

class HistoryReadOnlyAdapter {
  const HistoryReadOnlyAdapter();

  // 실측 결과 TarotHistoryStore 미존재 → 폴백.
  List<HistoryReadOnlyEntry> readTarot() {
    return const <HistoryReadOnlyEntry>[];
  }

  // 실측 결과 CounselHistoryStore 미존재(영속 히스토리 저장소 자체 없음) → 폴백.
  List<HistoryReadOnlyEntry> readCounsel() {
    return const <HistoryReadOnlyEntry>[];
  }

  // 실측 결과 FaceHistoryStore 미존재 → 폴백.
  List<HistoryReadOnlyEntry> readFace() {
    return const <HistoryReadOnlyEntry>[];
  }

  // 실측 결과 PalmHistoryStore 미존재 → 폴백.
  List<HistoryReadOnlyEntry> readPalm() {
    return const <HistoryReadOnlyEntry>[];
  }

  // [2026-08-14 갱신] JeontongHistoryStore(in-memory, dart:core 전용)가
  // 신설됨. 실제 조회 자체는 동기(Map 스냅샷)이지만, 미션 STEP 1-B/1-C 요구에
  // 따라 화면이 FutureBuilder 로 소비할 수 있도록 Future 시그니처를 유지한다
  // (await 는 없음 — 값은 이미 준비돼 있고 Future.value 로만 감쌈).
  Future<List<HistoryReadOnlyEntry>> readJeontong(String userId) async {
    return jeontong_store.JeontongHistoryStore.instance
        .list(userId)
        .map(
          (e) => HistoryReadOnlyEntry(
            id: e.id,
            title: e.title,
            subtitle: e.subtitle,
            createdAt: e.createdAtUtc,
          ),
        )
        .toList();
  }
}

const historyReadOnlyAdapter = HistoryReadOnlyAdapter();
