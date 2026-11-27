// lib/features/guinji/character/guinji_character.dart
// [귀인지도 v2 리스킨 — 핸드오프 이식] 캐릭터 자동 지정 — 성별 × 연령대(5)
// × 2벌(A/B) = 20종 (+ 호스트 데모 전용 f20 1종). 순수 클라이언트 표시
// 로직. 엔진 입력/결과와 무관. `귀인지도_최종_핸드오프.html`
// `window.GJ_CODE_FILES`의
// `lib/features/guinji_map/character/guinji_character.dart`를 1:1 이식.
//
// [에셋 경로] 핸드오프 원본은 `assets/guinji/chars/`를 가리키나, 이 프로젝트
// pubspec.yaml의 기존 관례(`assets/images/guinji/...`)에 맞춰
// `assets/images/guinji/chars/`로 둔다 — 이미지 생성/등록 단계(TODO item 4)에서
// 이 경로에 실제 파일 21종(얼굴+상반신)을 채워 넣는다.
enum GuinjiGender { female, male }

class GuinjiCharacter {
  final String id; // 예: f30b
  final String band; // 표시용 '30대'
  const GuinjiCharacter(this.id, this.band);

  String get face =>
      'assets/images/guinji/chars/${id}_face.jpg'; // 256×256 (원형 크롭)
  String get body =>
      'assets/images/guinji/chars/${id}_body.jpg'; // 600×800 (상반신)

  /// 만 나이 → 연령대 키.
  static String bandKey(DateTime birth, {DateTime? now}) {
    final n = now ?? DateTime.now();
    var age = n.year - birth.year;
    if (n.month < birth.month ||
        (n.month == birth.month && n.day < birth.day)) {
      age--;
    }
    if (age < 20) return '10';
    if (age < 30) return '20';
    if (age < 40) return '30';
    if (age < 60) return '40';
    return '60';
  }

  static const _bandLabel = {
    '10': '10대',
    '20': '20대',
    '30': '30대',
    '40': '40·50대',
    '60': '60·70대',
  };

  /// A벌 파일명 (20대만 접미사 a, 나머지는 접미사 없음) — 에셋 실제 파일명과 일치.
  static const _fileA = {
    'F10': 'f10',
    'F20': 'f20a',
    'F30': 'f30',
    'F40': 'f40',
    'F60': 'f60',
    'M10': 'm10',
    'M20': 'm20a',
    'M30': 'm30',
    'M40': 'm40',
    'M60': 'm60',
  };

  /// 문자열 해시 (JS 시안과 동일: h = (h*31 + code) >>> 0).
  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0xFFFFFFFF;
    }
    return h;
  }

  /// [성별 캐릭터 버그 수정 — 2026-10-14] 서버/화면 문자열('male'/'female')을
  /// [GuinjiGender]로 변환한다. 모르는 값·null은 null(해시 폴백 유지).
  static GuinjiGender? fromKey(String? g) {
    if (g == 'male') return GuinjiGender.male;
    if (g == 'female') return GuinjiGender.female;
    return null;
  }

  /// [stableKey] = memberId (없으면 이름). 같은 사람은 항상 같은 얼굴.
  /// [gender]가 null이면 해시 짝/홀로 성별 폴백.
  /// [overrideId] = 사용자가 '바꾸기'로 직접 고른 캐릭터.
  static GuinjiCharacter of({
    required DateTime birth,
    GuinjiGender? gender,
    required String stableKey,
    String? overrideId,
    DateTime? now,
  }) {
    final band = bandKey(birth, now: now);
    if (overrideId != null)
      return GuinjiCharacter(overrideId, _bandLabel[band]!);
    final h = _hash(stableKey);
    final g = gender ?? (h % 2 == 0 ? GuinjiGender.female : GuinjiGender.male);
    final base = _fileA[(g == GuinjiGender.female ? 'F' : 'M') + band]!;
    final variantB = h % 2 == 1; // A/B 두 벌 중 해시로 고정
    final id = variantB ? '${base.replaceAll(RegExp(r'a$'), '')}b' : base;
    return GuinjiCharacter(id, _bandLabel[band]!);
  }

  /// 앱 시작 시 미리 읽기 (지도 첫 렌더 깜빡임 방지).
  static List<String> allFaces() => [
    for (final g in ['f', 'm'])
      for (final b in ['10', '20', '30', '40', '60'])
        for (final v in ['A', 'B'])
          'assets/images/guinji/chars/${v == 'A' ? (b == '20' ? '$g${b}a' : '$g$b') : '$g${b}b'}_face.jpg',
  ];
}

/// 화면 표기 규칙: 캐릭터가 보이는 곳에는 반드시 소유자 이름을 붙인다.
/// 예) '서연님의 캐릭터 · 30대' · '하늘님의 캐릭터' · '도윤님의 캐릭터'.
String characterCaption(String name, GuinjiCharacter c) =>
    '$name님의 캐릭터 · ${c.band}';
