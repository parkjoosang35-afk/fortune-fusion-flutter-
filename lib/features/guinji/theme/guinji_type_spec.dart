// lib/features/guinji/theme/guinji_type_spec.dart
// [2026 디자인 핸드오프 v5 — "심야의 신전" 전면 교체] 관계 유형 6종 — 색 +
// 한자 인장 + 이름 + 선 모양 (색만으로 구분하지 않기). 키는 엔진 결과
// relationType 문자열 그대로(DB String 컬럼과 호환).
// `design_handoff_guinji_map_v5/design_files/guinji-data.js`의 `TYPES`를
// 1:1 이식한다 — v5 README §3 지시에 따라 한자는 코드 문서 그대로
// (比·剋·沖) 사용한다(기존 同·調·衝은 폐기).
//
// [주의] 이 파일은 기존 `guinji_relation_meta.dart`(GuinjiRelationMeta,
// 12→6종 전환 당시 작성된 상세 해설 포함 버전)와는 별개의 "최종 v2" 경량
// 스펙이다. 화면 교체 작업 시 이 파일을 1차 참조로 사용하고,
// `guinjiRelationTypes`(상세 해설)는 계속 유지한다 — 둘 다 같은 6종 키를
// 쓰므로 혼용 가능. 단, `guinjiRelationMetaOf()`의 `hanja`/`color`도 v5 값과
// 어긋나지 않도록 같은 턴에 맞춰 둔다(아래 `guinji_relation_meta.dart` 참고).
import 'package:flutter/material.dart';

class GuinjiTypeSpec {
  final String code;
  final String label; // 천생귀인
  final String short; // 귀인
  final String hanja; // 貴
  final Color color;
  final List<double>? dash; // null = 실선
  final String desc; // relationTypeDesc 폴백
  const GuinjiTypeSpec(
    this.code,
    this.label,
    this.short,
    this.hanja,
    this.color,
    this.dash,
    this.desc,
  );
}

/// 방향 순서 = 12시부터 시계방향 (지도 배치 · 필터 · 범례 공통).
/// [v5 "심야의 신전" 지도 재작성 — 2026] `design_handoff_guinji_map_v5/
/// design_files/guinji-data.js`의 `TYPE_ORDER`(코드 카테고리 순: 귀인(boost)
/// → 인연(path) → 조율(care))와 정확히 동일한 순서로 교정했다. 이전 값은
/// `HAP`과 `SANG_SAENG` 위치가 바뀐 구버전(v2/v3)이었다 — `tpPlace()`가
/// `k*60-90`(고정 60도 방향)으로 배치하므로, 이 순서가 바뀌면 지도의
/// "2시 방향 = 인연합" 같은 방향 약속 자체가 깨진다.
/// [중요] 기존 `guinji_person.dart`의 `guinjiRelationOrder`는 순서가 다르므로
/// (SANG_GEUK↔BI_HWA 위치가 반대) 지도 배치 각도 계산에는 반드시 이
/// `guinjiTypeOrder`를 사용한다.
const guinjiTypeOrder = [
  'CHEON_GWII',
  'SANG_SAENG',
  'HAP',
  'BI_HWA',
  'SANG_GEUK',
  'CHUNG',
];

const guinjiTypes = <String, GuinjiTypeSpec>{
  'CHEON_GWII': GuinjiTypeSpec(
    'CHEON_GWII',
    '천생귀인',
    '귀인',
    '貴',
    Color(0xFFF5CF6A),
    null,
    '타고난 인연으로 서로를 살리고 크게 이끌어 주는 관계',
  ),
  'HAP': GuinjiTypeSpec(
    'HAP',
    '인연합',
    '인연',
    '緣',
    Color(0xFFF08AA6),
    null,
    '일지가 합을 이루어 자연스럽게 끌리고 정이 깊어지는 관계',
  ),
  'SANG_SAENG': GuinjiTypeSpec(
    'SANG_SAENG',
    '상생동행',
    '상생',
    '生',
    Color(0xFF6FD3A0),
    null,
    '한쪽이 다른 쪽을 살리고 키워주는 상생의 관계',
  ),
  'BI_HWA': GuinjiTypeSpec(
    'BI_HWA',
    '동류동반',
    '동반',
    '比',
    Color(0xFF8DBFD6),
    null,
    '같은 오행으로 결이 비슷해 편안하게 동행하는 관계',
  ),
  'SANG_GEUK': GuinjiTypeSpec(
    'SANG_GEUK',
    '상극조율',
    '조율',
    '剋',
    Color(0xFFB59CF0),
    [9, 7],
    '서로 극하는 기운으로 긴장과 조율이 공존하는 관계',
  ),
  'CHUNG': GuinjiTypeSpec('CHUNG', '충돌극복', '극복', '沖', Color(0xFFEF7A55), [
    2,
    7,
  ], '일지가 충하여 부딪히지만 그만큼 성장을 만드는 관계'),
};

/// 알 수 없는 값(레거시 12종 등)이 와도 크래시 없이 폴백.
GuinjiTypeSpec guinjiTypeOf(String? code) =>
    guinjiTypes[code] ??
    const GuinjiTypeSpec(
      'UNKNOWN',
      '인연',
      '인연',
      '人',
      Color(0xFF9A9AA0),
      null,
      '',
    );

String gradeOf(int score) => score >= 90
    ? 'S'
    : score >= 75
    ? 'A'
    : score >= 60
    ? 'B'
    : score >= 45
    ? 'C'
    : 'D';
