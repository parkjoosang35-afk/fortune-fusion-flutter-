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

  // 실측 결과 JeontongHistoryStore 미존재(MyFortuneRecordStore는 비동기
  // Future 이며 이 미션의 동기 시그니처와 불일치) → 폴백.
  List<HistoryReadOnlyEntry> readJeontong() {
    return const <HistoryReadOnlyEntry>[];
  }
}

const historyReadOnlyAdapter = HistoryReadOnlyAdapter();
