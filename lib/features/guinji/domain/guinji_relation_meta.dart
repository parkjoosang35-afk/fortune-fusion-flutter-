import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';

/// 관계 유형(V2 6종) 메타데이터.
///
/// [V2 전환 — 4단계, 12종→6종 전면 교체] 기존 12종(CHEON_GWII/NA_SALRIDA/
/// JORYEOK/GACHI_GA/NA_SALJINDA/CHANG_GYIM/GAMJEONG/DEUNGDEUNG/KKEURIDA/
/// GACHI_BICH/JAGEUKJE/GINGJANG) 체계는 완전히 폐기되었다 — admin_web의
/// 관계 판정 엔진(`guinji-v2/relation.ts` `computeRelation()`)이 더 이상
/// 12종을 반환하지 않고, 공식 V2 6종(`GuinjiV2RelationType`)만 반환한다
/// (병행노출 금지 — 12종·6종을 동시에 노출하면 안 됨, 기획 확정사항).
///
/// V2 6종: CHEON_GWII(천생귀인) / HAP(인연합) / SANG_SAENG(상생동행) /
/// SANG_GEUK(상극조율) / BI_HWA(동류동반) / CHUNG(충돌극복).
/// label/desc의 기준값은 admin_web `guinji-v2/relation.ts`의
/// `RELATION_TYPES`와 동일(단일 소스 — 이 파일이 Flutter 쪽 1차 참조).
class GuinjiRelationMeta {
  const GuinjiRelationMeta({
    required this.key,
    required this.label,
    required this.hanja,
    required this.subtitle,
    required this.color,
    required this.orbit,
    required this.description,
    required this.category,
    required this.short,
    required this.long,
    required this.specialInsight,
    required this.tips,
  });

  final String key;
  final String label;
  final String hanja;
  final String subtitle;
  final Color color;

  /// 궤도 인덱스(0~5, V2 6종 각각에 1:1 대응 — 궤도 배열도 6칸으로
  /// 맞춘다. `guinji_orbit_map.dart`의 `guinjiOrbitRadii` 참고).
  final int orbit;
  final String description;

  /// 3대 카테고리: 'boost'(귀인·상생) / 'path'(인연·동류) / 'care'(조율·충돌).
  /// [V2 6종 재설계] 기존 12종 4카테고리(boost/path/warm/care, 3개씩)를
  /// 6종에 맞춰 3카테고리(2개씩)로 재편했다 — 6은 4로 균등히 나뉘지
  /// 않으므로, 의미가 가장 가까운 유형끼리 묶어 3그룹×2종 구조로 확정.
  final String category;

  /// 카드용 한 줄 요약.
  final String short;

  /// 해금 후 카드에 쓰이는 관계 유형별 심층 해설(2~3문장).
  final String specialInsight;

  /// 관계 유형별 실전 팁 2개(짧은 행동 지침).
  final List<String> tips;

  /// 상세 설명.
  final String long;
}

/// V2 6종 순서(admin_web `GUINJI_V2_RELATION_TYPE_ORDER`와 동일 순서) —
/// [orbit]은 이 순서 인덱스(0~5)를 그대로 사용한다.
const Map<String, GuinjiRelationMeta> guinjiRelationTypes = {
  'CHEON_GWII': GuinjiRelationMeta(
    key: 'CHEON_GWII',
    label: '천생귀인',
    hanja: '貴',
    subtitle: '타고난 인연 · 서로를 살림',
    color: GuinjiColors.relationCheonGwii,
    orbit: 0,
    description: '타고난 인연으로 서로를 살리고 크게 이끌어 주는 관계예요.',
    category: 'boost',
    short: '태어날 때부터 나를 돕는 사람',
    long:
        '일간 오행이 상생하고 일지가 합을 이루는, V2 엔진이 찾아낸 가장 높은 등급의 인연이에요. '
        '오행 보완과 합의 기운이 동시에 강하게 작용해, 어려울 때 결정적인 방향을 제시해주는 존재입니다.',
    specialInsight:
        '천생귀인은 일간의 생(生) 관계와 일지의 합(合)이 겹칠 때만 나오는, 명리학적으로 가장 귀한 조합이에요. '
        '이 사람의 조언은 흘려듣지 말고 메모해두는 게 좋아요 — 당장은 이해되지 않아도 나중에 결정적인 순간에 도움이 되는 경우가 많거든요. '
        '특히 이직·이사·결혼처럼 인생의 큰 갈림길에서 이 사람과 상의하면 후회가 적은 선택을 하게 됩니다.',
    tips: ['중요한 결정 전에는 꼭 먼저 의견을 물어보세요.', '이 사람이 먼저 건네는 조언은 가볍게 넘기지 마세요.'],
  ),
  'HAP': GuinjiRelationMeta(
    key: 'HAP',
    label: '인연합',
    hanja: '緣',
    subtitle: '일지가 합을 이룸',
    color: GuinjiColors.relationHap,
    orbit: 1,
    description: '일지가 합을 이루어 자연스럽게 끌리고 정이 깊어지는 관계예요.',
    category: 'path',
    short: '자연스레 마음이 향하는 사람',
    long: '일지(日支)끼리 육합 또는 삼합을 이루는 궁합으로, 이유를 딱히 설명하기 어려운데도 자꾸 끌리는 관계예요.',
    specialInsight:
        '일지가 합(合)을 이루면 서로의 결이 자연스럽게 맞물려, 따로 있을 때보다 함께 있을 때 분위기와 운의 흐름이 더 좋아져요. '
        '여행·창업·새로운 시작을 앞두고 있다면 이 사람과 함께 계획을 세워보세요. '
        '다만 끌림과 안정감은 별개라는 점도 함께 기억하면, 이 인연을 더 길게 이어갈 수 있어요.',
    tips: [
      '새로운 시작은 이 사람과 함께 해보면 흐름이 좋아요.',
      '끌리는 감정과 별개로 말과 행동의 일관성도 함께 살펴보세요.',
    ],
  ),
  'SANG_SAENG': GuinjiRelationMeta(
    key: 'SANG_SAENG',
    label: '상생동행',
    hanja: '生',
    subtitle: '한쪽이 다른 쪽을 살림',
    color: GuinjiColors.relationSangSaeng,
    orbit: 2,
    description: '한쪽이 다른 쪽을 살리고 키워주는 상생의 관계예요.',
    category: 'boost',
    short: '서로의 부족함을 채워주는 사람',
    long: '일간 오행이 생(生)하는 방향으로 흘러, 한쪽의 기운이 다른 쪽에게 자연스럽게 전해지는 관계입니다.',
    specialInsight:
        '사주 원국에 부족한 오행을 상대가 자연스럽게 채워주는 상생(相生) 관계예요. '
        '함께 있으면 이유 없이 든든하고 컨디션이 좋아지는 느낌을 받는다면 바로 이 기운 때문입니다. '
        '지치고 힘 빠질 때 먼저 연락해보세요 — 억지로 애쓰지 않아도 서로에게 자연스럽게 힘이 되는 사이라 부담 없이 기대도 괜찮습니다.',
    tips: ['힘든 시기일수록 먼저 연락해서 만나보세요.', '이 사람 앞에서는 약한 모습을 숨기지 않아도 괜찮아요.'],
  ),
  'SANG_GEUK': GuinjiRelationMeta(
    key: 'SANG_GEUK',
    label: '상극조율',
    hanja: '剋',
    subtitle: '서로 극하는 기운의 조율',
    color: GuinjiColors.relationSangGeuk,
    orbit: 3,
    description: '서로 극하는 기운으로 긴장과 조율이 공존하는 관계예요.',
    category: 'care',
    short: '나를 흔들어 깨우는 사람',
    long: '일간 오행이 서로 극(剋)하는 방향으로 작용해, 편하지만은 않은 자극을 주는 관계입니다.',
    specialInsight:
        '극(剋)하는 오행 관계라 이 사람 앞에서는 나도 모르게 긴장하거나 신경이 쓰일 수 있어요. '
        '하지만 그 긴장감이 오히려 나를 더 단단하게 성장시키는 계기가 되는 경우가 많습니다. '
        '불편함을 무조건 피하기보다, 이 관계가 나에게 어떤 자극과 배움을 주는지 곱씹어보면 의외의 성장 포인트를 발견하게 될 거예요.',
    tips: ['불편한 감정을 무조건 피하지 말고 원인을 들여다보세요.', '이 사람과의 마찰이 곧 성장의 신호일 수 있어요.'],
  ),
  'BI_HWA': GuinjiRelationMeta(
    key: 'BI_HWA',
    label: '동류동반',
    hanja: '比',
    subtitle: '같은 오행 · 결이 비슷함',
    color: GuinjiColors.relationBiHwa,
    orbit: 4,
    description: '같은 오행으로 결이 비슷해 편안하게 동행하는 관계예요.',
    category: 'path',
    short: '결이 비슷해 편안한 사람',
    long: '일간 오행이 똑같은 비화(比化) 관계로, 서로의 입장을 가장 잘 이해하는 사이예요.',
    specialInsight:
        '같은 오행의 기운을 나눠 갖고 있어 서로의 입장을 누구보다 잘 이해하는 사이예요. '
        '경쟁보다는 협력할 때 훨씬 큰 시너지가 나는 조합이라, 같은 목표를 두고 함께 일하거나 프로젝트를 진행하면 성과가 배가 됩니다. '
        '단, 이해관계가 정확히 겹치는 일(같은 자리를 두고 경쟁하는 상황 등)은 되도록 피하는 게 관계를 오래 유지하는 비결이에요.',
    tips: ['같은 목표를 두고 협업하면 시너지가 커요.', '이해관계가 정면으로 겹치는 일은 피하는 게 좋아요.'],
  ),
  'CHUNG': GuinjiRelationMeta(
    key: 'CHUNG',
    label: '충돌극복',
    hanja: '沖',
    subtitle: '일지가 충함 · 그만큼 성장',
    color: GuinjiColors.relationChung,
    orbit: 5,
    description: '일지가 충하여 부딪히지만 그만큼 성장을 만드는 관계예요.',
    category: 'care',
    short: '가까울수록 예민해지는 사람',
    long: '일지(日支)끼리 충(沖)을 이루는 궁합으로, 부딪히면서도 쉽게 놓지 못하는 관계입니다.',
    specialInsight:
        '일지가 충(沖)하는 관계라 가까이 있을수록 사소한 일에도 예민해지기 쉬워요. '
        '적당한 거리를 두고 서로의 공간을 존중하는 게 오히려 관계를 오래 지속시키는 비결입니다. '
        '다투더라도 쉽게 놓지 못하는 인연이라는 점을 기억하고, 감정이 격해질 땐 잠시 시간을 두는 습관을 들여보세요.',
    tips: ['너무 가까이 붙어 있기보다 적당한 거리를 유지하세요.', '감정이 격해지면 바로 반응하지 말고 잠시 시간을 두세요.'],
  ),
};

/// [V2 전환 — non-null assertion 제거] `guinjiRelationTypes[key]!` 형태의
/// 강제 단언은 키가 V2 6종 중 하나가 아니면(구형 12종 잔존값, DB에 남은
/// 과거 레코드, 알 수 없는 값 등) 즉시 크래시로 이어진다("화면은 뜨는데
/// 숫자가 틀리는 조용한 버그"가 아니라 "화면이 아예 죽는" 더 심각한
/// 버그). 이 헬퍼는 알 수 없는 키가 들어와도 절대 크래시하지 않고 항상
/// 유효한 [GuinjiRelationMeta]를 반환한다 — 폴백은 'BI_HWA'(동류동반,
/// V2 엔진 `decideType()`의 최종 폴백값과 동일하게 맞춤).
GuinjiRelationMeta guinjiRelationMetaOf(String key) {
  return guinjiRelationTypes[key] ?? guinjiRelationTypes['BI_HWA']!;
}

/// 3대 카테고리 메타 — [V2 6종 재설계] 기존 12종 4카테고리(boost/path/
/// warm/care)를 6종에 맞춰 3카테고리(2종씩)로 재편했다.
class GuinjiCategoryMeta {
  const GuinjiCategoryMeta({
    required this.key,
    required this.title,
    required this.subtitle,
  });

  final String key;
  final String title;
  final String subtitle;
}

const List<GuinjiCategoryMeta> guinjiCategoryOrder = [
  GuinjiCategoryMeta(key: 'boost', title: '귀인', subtitle: '나를 끌어올려주는 관계'),
  GuinjiCategoryMeta(key: 'path', title: '인연', subtitle: '함께 걸어갈 방향의 사람'),
  GuinjiCategoryMeta(key: 'care', title: '조율', subtitle: '거리 조절이 필요한 관계'),
];

/// 카테고리별 관계 키 목록(V2 6종, 2종씩).
const Map<String, List<String>> guinjiRelationKeysByCategory = {
  'boost': ['CHEON_GWII', 'SANG_SAENG'],
  'path': ['HAP', 'BI_HWA'],
  'care': ['SANG_GEUK', 'CHUNG'],
};
// 주의: 관계 순서 리스트(`guinjiRelationOrder`)는 `guinji_person.dart`에
// 정의되어 있다(중복 선언 방지).

/// 오행(五行) 메타데이터.
class GuinjiOhaengMeta {
  const GuinjiOhaengMeta({
    required this.key,
    required this.label,
    required this.name,
    required this.color,
  });

  final String key;

  /// 한자 라벨(木/火/土/金/水).
  final String label;
  final String name;
  final Color color;
}

const Map<String, GuinjiOhaengMeta> guinjiOhaengTypes = {
  'mok': GuinjiOhaengMeta(
    key: 'mok',
    label: '木',
    name: '목',
    color: GuinjiColors.ohaengMok,
  ),
  'hwa': GuinjiOhaengMeta(
    key: 'hwa',
    label: '火',
    name: '화',
    color: GuinjiColors.ohaengHwa,
  ),
  'to': GuinjiOhaengMeta(
    key: 'to',
    label: '土',
    name: '토',
    color: GuinjiColors.ohaengTo,
  ),
  'geum': GuinjiOhaengMeta(
    key: 'geum',
    label: '金',
    name: '금',
    color: GuinjiColors.ohaengGeum,
  ),
  'su': GuinjiOhaengMeta(
    key: 'su',
    label: '水',
    name: '수',
    color: GuinjiColors.ohaengSu,
  ),
};
