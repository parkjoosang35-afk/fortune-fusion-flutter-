import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';

/// 관계 유형(12라벨) 메타데이터.
///
/// [2026-09 12라벨 전환] 기존 5종(貴/同/緣/養/師, guin/oreunpal/inyeon/
/// salrim/horang) 체계를 PRD("신통방통 · 귀인지도 섹션 PRD" v0.9) p.4
/// "4.1 관계 라벨 체계" 표 기준 12라벨로 전면 교체했다. 키(key)·라벨명
/// (label)·한자(hanja)·부제(subtitle)·설명(description)은 admin_web
/// `src/app/g/[token]/relation-meta.ts`의 `GUINJI_RELATION_TYPES`와
/// 정확히 동일한 값이며, 실제 판정 결과(`GuinjiPerson.relation`)의 값도
/// 백엔드 `GuinjiRelationType`(`guinji-relation-judger.ts`)의 코드값
/// (예: 'CHEON_GWII', 'NA_SALRIDA' 등)과 동일해야 한다.
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

  /// 궤도 인덱스(0=최내곽 貴 → 4=최외곽 師).
  final int orbit;
  final String description;

  /// 4대 카테고리: 'boost'(귀인) / 'path'(인연) / 'warm'(보완) / 'care'(조심).
  /// [2026-09 새 디자인 리스킨] 새 디자인 zip의 `labels.dart` `RelationCategory`
  /// enum과 1:1 대응. 12라벨명이 완전히 동일하여 이름 기준으로 매핑 확정.
  final String category;

  /// 새 디자인 카드용 한 줄 요약(새 디자인 `LabelTemplate.short`와 동일).
  final String short;

  /// [스페셜 해설 콘텐츠 풍부화 — 2026-09] "이 관계, 어떻게 대해야 할까"
  /// 해금 후 카드에 쓰이는 관계 유형별 심층 해설(2~3문장). 기존에는 12개
  /// 유형 모두 동일한 고정 문구("~의 결이에요. ~를 함께 상의하면 결이
  /// 풀려요")만 보여줘 "내용이 빈약하다"는 리포트를 받았다 — 유형마다
  /// 실제로 다른 조언을 담아 풍부하게 만든다.
  final String specialInsight;

  /// 관계 유형별 실전 팁 2개(짧은 행동 지침). 해금 카드 하단 Tip 배너에
  /// 사용한다.
  final List<String> tips;

  /// 새 디자인 상세 설명(새 디자인 `LabelTemplate.long`와 동일).
  final String long;
}

/// 12라벨 순서(priority 내림차순, admin_web `GUINJI_RELATION_TYPE_ORDER`와
/// 동일): CHEON_GWII → NA_SALRIDA → JORYEOK → GACHI_GA → NA_SALJINDA →
/// CHANG_GYIM → GAMJEONG → DEUNGDEUNG → KKEURIDA → GACHI_BICH → JAGEUKJE →
/// GINGJANG. [orbit]은 이 순서 인덱스(0~11)를 그대로 사용한다.
const Map<String, GuinjiRelationMeta> guinjiRelationTypes = {
  'CHEON_GWII': GuinjiRelationMeta(
    key: 'CHEON_GWII',
    label: '천생귀인',
    hanja: '貴',
    subtitle: '상대가 나를 살림',
    color: GuinjiColors.relationCheonGwii,
    orbit: 0,
    description: '이 사람은 내게 희소한 기운을 가져다줘요.',
    category: 'boost',
    short: '태어날 때부터 나를 돕는 사람',
    long: '사주의 근본에서부터 나에게 힘을 실어주는 관계예요. 어려울 때 결정적인 조언과 방향을 알려주는 존재입니다.',
    specialInsight:
        '천을귀인은 명리학에서 "하늘이 내린 은인"으로 불리는 가장 귀한 관계예요. 이 사람의 조언은 흘려듣지 말고 메모해두는 게 좋아요 — 당장은 이해되지 않아도 나중에 결정적인 순간에 도움이 되는 경우가 많거든요. 특히 이직·이사·결혼처럼 인생의 큰 갈림길에서 이 사람과 상의하면 후회가 적은 선택을 하게 됩니다.',
    tips: ['중요한 결정 전에는 꼭 먼저 의견을 물어보세요.', '이 사람이 먼저 건네는 조언은 가볍게 넘기지 마세요.'],
  ),
  'NA_SALRIDA': GuinjiRelationMeta(
    key: 'NA_SALRIDA',
    label: '나를 살리는 사람',
    hanja: '生',
    subtitle: '상대가 나를 살림',
    color: GuinjiColors.relationNaSalrida,
    orbit: 1,
    description: '힘들 때 절로 찾는, 나를 살리는 사람.',
    category: 'boost',
    short: '내 부족함을 채워주는 사람',
    long: '내 오행에 결핍된 기운을 정확히 보충해주는 관계입니다.',
    specialInsight:
        '사주 원국에 부족한 오행을 이 사람이 자연스럽게 채워주는 상생(相生) 관계예요. 함께 있으면 이유 없이 든든하고 컨디션이 좋아지는 느낌을 받는다면 바로 이 기운 때문입니다. 지치고 힘 빠질 때 먼저 연락해보세요 — 억지로 애쓰지 않아도 서로에게 자연스럽게 힘이 되는 사이라 부담 없이 기대도 괜찮습니다.',
    tips: ['힘든 시기일수록 먼저 연락해서 만나보세요.', '이 사람 앞에서는 약한 모습을 숨기지 않아도 괜찮아요.'],
  ),
  'JORYEOK': GuinjiRelationMeta(
    key: 'JORYEOK',
    label: '조력자',
    hanja: '助',
    subtitle: '쌍방 균형',
    color: GuinjiColors.relationJoryeok,
    orbit: 2,
    description: '서로의 약점을 채워주는 조력자.',
    category: 'boost',
    short: '실질적으로 나를 돕는 사람',
    long: '일이나 결정을 앞두고 있을 때 손을 내밀어주는 관계예요.',
    specialInsight:
        '비견·겁재 관계로, 같은 오행의 기운을 나눠 갖고 있어 서로의 입장을 가장 잘 이해하는 사이예요. 경쟁보다는 협력할 때 훨씬 큰 시너지가 나는 조합이라, 같은 목표를 두고 함께 일하거나 프로젝트를 진행하면 성과가 배가 됩니다. 단, 이해관계가 정확히 겹치는 일(같은 자리를 두고 경쟁하는 상황 등)은 되도록 피하는 게 관계를 오래 유지하는 비결이에요.',
    tips: ['같은 목표를 두고 협업하면 시너지가 커요.', '이해관계가 정면으로 겹치는 일은 피하는 게 좋아요.'],
  ),
  'GACHI_GA': GuinjiRelationMeta(
    key: 'GACHI_GA',
    label: '같이 가야 좋은 길',
    hanja: '共',
    subtitle: '공동 상승',
    color: GuinjiColors.relationGachiGa,
    orbit: 3,
    description: '같이 걸을 때 더 멀리 가는 사이.',
    category: 'path',
    short: '함께할 때 서로 잘 되는 사이',
    long: '방향과 속도가 맞는 관계입니다. 오래 함께할수록 서로에게 좋은 결과가 쌓여요.',
    specialInsight:
        '지지(地支)가 합(合)을 이루는 궁합으로, 따로 있을 때보다 함께 있을 때 운의 흐름이 훨씬 좋아지는 관계예요. 여행·창업·이사처럼 새로운 시작을 앞두고 있다면 이 사람과 함께 계획을 세워보세요. 서두르지 않고 오래 함께 갈수록 효과가 누적되는 유형이라, 단기간의 결과보다 꾸준한 동행 자체에 의미를 두는 게 좋아요.',
    tips: ['새로운 도전은 이 사람과 함께 시작해보세요.', '조급해하지 말고 꾸준히 함께하는 시간을 쌓아가세요.'],
  ),
  'NA_SALJINDA': GuinjiRelationMeta(
    key: 'NA_SALJINDA',
    label: '내가 살리는 사람',
    hanja: '育',
    subtitle: '내가 상대를 살림',
    color: GuinjiColors.relationNaSaljinda,
    orbit: 4,
    description: '내가 에너지를 주는 사람 — 가끔은 쉬어가도 좋아요.',
    category: 'path',
    short: '내가 도와줄 때 빛나는 사람',
    long: '나의 기운이 상대에게 크게 도움 되는 관계예요.',
    specialInsight:
        '내 오행이 상대를 생(生)하는 관계라, 내가 마음을 쓰고 베풀수록 이 사람이 눈에 띄게 잘 풀리는 신기한 조합이에요. 다만 일방적으로 에너지를 쏟기만 하면 나도 모르게 지칠 수 있으니, 도와주는 즐거움과 나의 휴식 사이에서 균형을 잡는 게 중요합니다. 이 사람이 잘되는 모습 자체가 나에게도 좋은 기운으로 돌아오는 구조이니 너무 계산하지 말고 자연스럽게 곁을 내어주세요.',
    tips: ['가끔은 내 에너지도 챙기며 무리하지 마세요.', '이 사람의 성장을 지켜보는 것 자체가 나에게도 좋은 기운이 돼요.'],
  ),
  'CHANG_GYIM': GuinjiRelationMeta(
    key: 'CHANG_GYIM',
    label: '내가 챙기는 사람',
    hanja: '養',
    subtitle: '내가 상대를 살림',
    color: GuinjiColors.relationChangGyim,
    orbit: 5,
    description: '주다 보면 내가 소모되기 쉬운 조합.',
    category: 'path',
    short: '내 손길이 필요한 사람',
    long: '내가 세심하게 챙길수록 관계가 순해지는 사이입니다.',
    specialInsight:
        '식신·상관처럼 내가 정성을 쏟아부어 키워내는 유형의 인연이에요. 잔소리보다는 꾸준한 관심과 실질적인 도움(밥 한 끼, 작은 선물, 짧은 안부)이 훨씬 효과적으로 통합니다. 다만 챙기는 게 습관이 되어 나를 소모하지 않도록, 내 컨디션이 안 좋을 때는 잠시 거리를 두고 회복한 뒤 다시 다가가는 리듬을 만들어보세요.',
    tips: ['잔소리보다 실질적인 작은 도움이 더 잘 통해요.', '내가 지쳤을 땐 잠시 거리를 두고 회복한 뒤 다가가세요.'],
  ),
  'GAMJEONG': GuinjiRelationMeta(
    key: 'GAMJEONG',
    label: '감정 충전소',
    hanja: '感',
    subtitle: '에너지 회복',
    color: GuinjiColors.relationGamjeong,
    orbit: 6,
    description: '만나면 마음이 회복되는 사람.',
    category: 'warm',
    short: '지치면 만나고 싶어지는 사람',
    long: '함께 있으면 감정의 배터리가 채워지는 관계예요.',
    specialInsight:
        '인성(印星)의 기운이 강하게 작용하는 관계로, 만나기만 해도 마음이 편해지고 위로받는 느낌을 주는 사람이에요. 큰 성과나 목표를 위한 관계라기보다, 지치고 소진됐을 때 아무 말 없이 곁에 있어주는 것만으로도 회복이 되는 존재입니다. 억지로 무언가를 함께하려 하기보다, 편하게 쉬면서 시간을 보내는 방식이 이 관계에는 가장 잘 맞아요.',
    tips: ['지쳤을 땐 목적 없이 그냥 편하게 만나보세요.', '무언가를 이루려 하기보다 함께 쉬는 시간 자체를 즐기세요.'],
  ),
  'DEUNGDEUNG': GuinjiRelationMeta(
    key: 'DEUNGDEUNG',
    label: '든든한 등받이',
    hanja: '護',
    subtitle: '상대가 나를 살림',
    color: GuinjiColors.relationDeungdeung,
    orbit: 7,
    description: '곁에서 흔들리지 않게 잡아주는 사람.',
    category: 'warm',
    short: '뒤에서 나를 지탱해주는 사람',
    long: '요란하지 않지만 오래 곁에 있는 관계입니다.',
    specialInsight:
        '정인(正印)의 안정적인 기운이 흐르는 관계로, 화려하게 티가 나진 않지만 위기의 순간에 든든하게 버팀목이 되어주는 사람이에요. 평소엔 무심한 듯 보여도 정작 중요한 순간에는 누구보다 먼저 나서서 도와주는 유형이라, 겉모습만으로 이 사람의 마음을 판단하지 않는 게 좋아요. 오래된 관계일수록 진가가 드러나는 인연이니 조급해하지 말고 신뢰를 쌓아가세요.',
    tips: ['겉으로 무심해 보여도 진심을 의심하지 마세요.', '오래 함께할수록 이 관계의 진가를 느끼게 될 거예요.'],
  ),
  'KKEURIDA': GuinjiRelationMeta(
    key: 'KKEURIDA',
    label: '끌리는 사람',
    hanja: '緣',
    subtitle: '관성/식상 자화',
    color: GuinjiColors.relationKkeurida,
    orbit: 8,
    description: '끌리지만 안정감은 따로 가는 사이.',
    category: 'warm',
    short: '자연스레 마음이 향하는 사람',
    long: '오행의 결이 서로 맞물려 자연스러운 호감이 생기는 관계예요.',
    specialInsight:
        '관성과 식상이 만나 자연스러운 끌림을 만들어내는 관계예요. 이유를 딱히 설명하기 어려운데도 자꾸 신경이 쓰이고 마음이 향한다면 이 조합일 가능성이 높습니다. 다만 끌림과 안정감은 별개라는 점을 기억하세요 — 감정에 휩쓸리기보다 이 사람의 말과 행동이 일관되는지 시간을 두고 지켜보는 게 현명한 접근입니다.',
    tips: ['끌리는 감정과 별개로 시간을 두고 지켜보세요.', '말과 행동의 일관성을 확인한 뒤에 마음을 더 열어도 늦지 않아요.'],
  ),
  'GACHI_BICH': GuinjiRelationMeta(
    key: 'GACHI_BICH',
    label: '같이 빛나는 사람',
    hanja: '輝',
    subtitle: '쌍방 상승',
    color: GuinjiColors.relationGachiBich,
    orbit: 9,
    description: '각자의 결이 또렷한 채로 빛나는 사이.',
    category: 'care',
    short: '함께 있을 때 서로가 튀는 사람',
    long: '개성이 강한 관계라 함께 있을 때 시너지도, 마찰도 큽니다.',
    specialInsight:
        '각자의 사주 기운이 또렷해서 함께 있으면 서로의 개성이 더욱 부각되는 관계예요. 잘 맞을 때는 눈에 띄게 화려한 시너지를 내지만, 반대로 자존심이 부딪히면 마찰도 그만큼 크게 날 수 있는 양날의 조합입니다. 서로의 영역과 스타일을 인정하고 존중하는 태도만 유지하면, 이만큼 매력적으로 함께 빛날 수 있는 관계도 드물어요.',
    tips: ['서로의 스타일과 영역을 존중해주세요.', '자존심 싸움으로 번지지 않게 한 발 물러서는 여유가 필요해요.'],
  ),
  'JAGEUKJE': GuinjiRelationMeta(
    key: 'JAGEUKJE',
    label: '자극제',
    hanja: '刺',
    subtitle: '긴장 → 성장',
    color: GuinjiColors.relationJageukje,
    orbit: 10,
    description: '서로의 날카로움이 성장으로 가는 자극제.',
    category: 'care',
    short: '나를 흔들어 깨우는 사람',
    long: '편안하지는 않지만 성장의 계기가 되는 관계입니다.',
    specialInsight:
        '정관·편관의 긴장된 기운이 작용해, 편하지만은 않은 자극을 주는 관계예요. 이 사람 앞에서는 나도 모르게 긴장하거나 잘 보이고 싶은 마음이 들 수 있는데, 그 긴장감이 오히려 나를 더 단단하게 성장시키는 계기가 됩니다. 불편함을 무조건 피하기보다, 이 관계가 나에게 어떤 자극과 배움을 주는지 곱씹어보면 의외의 성장 포인트를 발견하게 될 거예요.',
    tips: ['불편한 감정을 무조건 피하지 말고 원인을 들여다보세요.', '이 사람과의 마찰이 곧 성장의 신호일 수 있어요.'],
  ),
  'GINGJANG': GuinjiRelationMeta(
    key: 'GINGJANG',
    label: '긴장 속 단짝',
    hanja: '緊',
    subtitle: '안정 + 긴장 공존',
    color: GuinjiColors.relationGingjang,
    orbit: 11,
    description: '부딪히면서도 놓지 않는 단짝.',
    category: 'care',
    short: '가까울수록 예민해지는 사람',
    long: '결이 가까워 함께 있지만 미묘한 긴장이 도는 관계입니다.',
    specialInsight:
        '오행의 결이 서로 가까워 안정감을 주면서도, 동시에 미묘한 긴장이 함께 흐르는 독특한 조합이에요. 너무 가까이 붙어 있으면 사소한 일에도 예민해지기 쉬우니, 적당한 거리를 두고 서로의 공간을 존중하는 게 오히려 관계를 오래 지속시키는 비결입니다. 다투더라도 쉽게 놓지 못하는 인연이라는 점을 기억하고, 감정이 격해질 땐 잠시 시간을 두는 습관을 들여보세요.',
    tips: ['너무 가까이 붙어 있기보다 적당한 거리를 유지하세요.', '감정이 격해지면 바로 반응하지 말고 잠시 시간을 두세요.'],
  ),
};

/// 4대 카테고리 메타(새 디자인 `kCategories`와 동일 값).
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
  GuinjiCategoryMeta(key: 'warm', title: '보완', subtitle: '내 결을 채워주는 존재'),
  GuinjiCategoryMeta(key: 'care', title: '조심', subtitle: '거리 조절이 필요한 관계'),
];

/// 카테고리별 관계 키 목록(새 디자인 `kLabelsByCategory`와 동일 순서).
const Map<String, List<String>> guinjiRelationKeysByCategory = {
  'boost': ['CHEON_GWII', 'NA_SALRIDA', 'JORYEOK'],
  'path': ['GACHI_GA', 'NA_SALJINDA', 'CHANG_GYIM'],
  'warm': ['GAMJEONG', 'DEUNGDEUNG', 'KKEURIDA'],
  'care': ['GACHI_BICH', 'JAGEUKJE', 'GINGJANG'],
};
// 주의: 관계 순서 리스트(`guinjiRelationOrder`)는 `guinji_person.dart`에
// 정의되어 있다(중복 선언 방지). 그 파일도 12라벨로 갱신 필요 — 미완료.

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
