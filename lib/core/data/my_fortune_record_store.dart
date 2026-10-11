import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// [오늘의 운세 표준 플로우 §6 후속연결] "저장 → 마이 → 내 운세 기록에 카드 저장".
///
/// 카테고리 무관 공용 저장소로 설계해, 사주/궁합/타로/관상/손금 결과 화면도
/// 동일한 저장 로직을 그대로 재사용할 수 있게 한다(표준 플로우 확장 원칙).
class SavedFortuneRecord {
  const SavedFortuneRecord({
    required this.id,
    required this.categoryLabel,
    required this.title,
    required this.summary,
    this.score,
    required this.date,
    required this.savedAt,
    this.cardImageAssetPath,
  });

  final String id;

  /// 예: '오늘의 운세', '사주', '타로' ...
  final String categoryLabel;
  final String title;
  final String summary;

  /// [마이페이지 리뉴얼 · 2026-10-11] 시안 "사주 히스토리" 연결 요구에 따라
  /// 사주(saju_renewal) 기록도 이 공용 저장소에 저장한다. saju_renewal은
  /// 점수(score) 개념이 없으므로 nullable로 바꾼다(기존 타로/일반 운세는
  /// 여전히 int를 전달하므로 동작 변화 없음).
  final int? score;
  final DateTime date;
  final DateTime savedAt;

  /// [카드 이미지 교체] 타로 등 카드 기반 결과를 저장할 때만 채워지는
  /// 카드 썸네일 이미지 경로(nullable). 카드와 무관한 카테고리(사주 등)
  /// 기록은 항상 null이며, 기존 저장된 레코드(이 필드가 없던 시절 JSON)와도
  /// 하위 호환되도록 [fromJson]에서 안전하게 파싱한다.
  final String? cardImageAssetPath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryLabel': categoryLabel,
    'title': title,
    'summary': summary,
    if (score != null) 'score': score,
    'date': date.toIso8601String(),
    'savedAt': savedAt.toIso8601String(),
    if (cardImageAssetPath != null) 'cardImageAssetPath': cardImageAssetPath,
  };

  factory SavedFortuneRecord.fromJson(Map<String, dynamic> json) {
    return SavedFortuneRecord(
      id: json['id'] as String,
      categoryLabel: json['categoryLabel'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      score: json['score'] as int?,
      date: DateTime.parse(json['date'] as String),
      savedAt: DateTime.parse(json['savedAt'] as String),
      cardImageAssetPath: json['cardImageAssetPath'] as String?,
    );
  }
}

class MyFortuneRecordStore {
  MyFortuneRecordStore._();

  static const _key = 'my_fortune_records_v1';

  /// [MORE·08 버그 수정 개발지시서 2026-10-11 REQ-08] 비로그인(게스트)
  /// 상태에서 저장한 기록을 담는 별도 버킷. 기본안(8절 Q2)은 "기기 로컬
  /// 저장 후 로그인 시 히스토리로 이관(동기화)"이므로, 게스트 저장을
  /// 곧바로 메인 저장소([_key])에 섞지 않고 이 임시 버킷에 모아둔다 —
  /// 그래야 로그인 전까지는 "내 기록"이 아니라 "이 기기에 임시로 남은
  /// 기록"으로 명확히 구분되고, 로그인 시 [migrateGuestRecordsToAccount]가
  /// 안전하게 메인 저장소로 옮길 수 있다.
  static const _guestKey = 'my_fortune_records_guest_v1';

  static Future<List<SavedFortuneRecord>> _readKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? const [];
    return raw
        .map((e) {
          try {
            return SavedFortuneRecord.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedFortuneRecord>()
        .toList();
  }

  static Future<void> _writeKey(
    String key,
    List<SavedFortuneRecord> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      key,
      records.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  static Future<List<SavedFortuneRecord>> list() async {
    final all = await _readKey(_key);
    return all..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  /// [마이페이지 리뉴얼 · 2026-10-11] 사주 히스토리 목록 화면에서 "사주"
  /// 카테고리만 따로 조회할 수 있도록 카테고리 필터 조회를 추가한다(기존
  /// [list]는 그대로 두고 신규 메서드만 더함 — 다른 호출부 영향 없음).
  static Future<List<SavedFortuneRecord>> listByCategory(
    String categoryLabel,
  ) async {
    final all = await list();
    return all.where((e) => e.categoryLabel == categoryLabel).toList();
  }

  /// [MORE·08 저장 기능 개발지시서 2026-10-11 REQ-07] 동일 id 레코드가 이미
  /// 저장돼 있는지 확인한다 — 호출부가 "이미 저장된 이야기예요." 중복 안내를
  /// 내보낼지 판단하는 용도.
  ///
  /// [REQ-08] `includeGuest`가 true(기본값)면 게스트 버킷도 함께 확인한다 —
  /// 비로그인 상태로 같은 이야기를 두 번 저장하려 할 때도 "이미 저장된
  /// 이야기예요."가 정상적으로 뜨도록 한다(REQ-07과 REQ-08의 상호작용).
  static Future<bool> exists(String id, {bool includeGuest = true}) async {
    final all = await list();
    if (all.any((e) => e.id == id)) return true;
    if (!includeGuest) return false;
    final guest = await _readKey(_guestKey);
    return guest.any((e) => e.id == id);
  }

  /// 이미 같은 id가 있으면 갱신, 없으면 새로 추가.
  ///
  /// [MORE·08 버그 수정 개발지시서 2026-10-11 REQ-08] `asGuest: true`로
  /// 호출하면 메인 저장소가 아니라 게스트 임시 버킷([_guestKey])에 쓴다 —
  /// 호출부(`more_stories_screen.dart`)가 저장 시점의 로그인 상태에 따라
  /// 분기한다. 기본값(false)은 기존 동작(로그인 사용자의 정상 저장)과
  /// 완전히 동일하므로 다른 호출부(타로/관상/손금 등) 동작은 바뀌지 않는다.
  static Future<void> save(
    SavedFortuneRecord record, {
    bool asGuest = false,
  }) async {
    final key = asGuest ? _guestKey : _key;
    final list = (await _readKey(key)).where((e) => e.id != record.id).toList();
    list.insert(0, record);
    await _writeKey(key, list);
  }

  static Future<void> remove(String id) async {
    final list = (await _readKey(_key)).where((e) => e.id != id).toList();
    await _writeKey(_key, list);
  }

  /// [MORE·08 버그 수정 개발지시서 2026-10-11 REQ-08 — 기본안 "기기 로컬
  /// 저장 후 로그인 시 히스토리로 이관(동기화)"]
  ///
  /// 게스트 버킷([_guestKey])에 쌓인 기록을 로그인 성공 직후 메인
  /// 저장소([_key])로 옮긴다. `AuthProvider.login`/`signup`/
  /// `loginWithSocial`이 성공한 직후 호출하는 것을 전제로 한다(로그아웃 시
  /// 호출 대상이 아님 — 로그아웃 콜백과는 반대 방향).
  ///
  /// 이관 규칙:
  /// - 게스트 버킷에 있던 레코드를 메인 저장소로 병합한다. 동일 id가 메인
  ///   저장소에 이미 있으면(예: 같은 기기에서 로그인 상태로 한 번 저장한
  ///   뒤 로그아웃하고 같은 이야기를 게스트로 다시 저장한 드문 경우)
  ///   **게스트 쪽을 버리고 기존 메인 레코드를 그대로 유지**한다 — 로그인
  ///   사용자가 서버에 이미 가진 정식 기록을 게스트 임시 기록으로
  ///   덮어쓰지 않기 위함(데이터 손실 방지 원칙).
  /// - 이관이 끝나면 게스트 버킷은 비운다(같은 기기에서 다른 계정으로 또
  ///   로그인했을 때 앞선 손님 기록이 새 계정으로 잘못 이관되지 않도록).
  /// - 게스트 버킷이 비어 있으면(가장 흔한 경우) 아무 작업도 하지 않고
  ///   조용히 반환한다.
  ///
  /// 반환값: 실제로 이관된 레코드 수(0이면 호출부가 토스트 등 후속 UX를
  /// 생략할 수 있음).
  static Future<int> migrateGuestRecordsToAccount() async {
    final guestRecords = await _readKey(_guestKey);
    if (guestRecords.isEmpty) return 0;

    final mainRecords = await _readKey(_key);
    final mainIds = mainRecords.map((e) => e.id).toSet();
    final toMigrate = guestRecords.where((e) => !mainIds.contains(e.id));

    final merged = [...mainRecords, ...toMigrate]
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    await _writeKey(_key, merged);
    await _writeKey(_guestKey, const []); // 게스트 버킷 비우기(계정 혼선 방지).

    return merged.length - mainRecords.length;
  }

  /// [REQ-08 보조] 현재 기기에 이관 대기 중인 게스트 기록이 있는지(배지
  /// 노출 등에 쓸 수 있도록 공개 — 당장은 내부 로직에서만 쓰여도 향후
  /// UI에서 활용 가능하도록 공개 API로 둔다).
  static Future<bool> hasPendingGuestRecords() async {
    final guest = await _readKey(_guestKey);
    return guest.isNotEmpty;
  }
}
