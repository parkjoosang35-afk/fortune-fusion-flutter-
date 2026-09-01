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
  });

  final String key;
  final String label;
  final String hanja;
  final String subtitle;
  final Color color;

  /// 궤도 인덱스(0=최내곽 貴 → 4=최외곽 師).
  final int orbit;
  final String description;
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
  ),
  'NA_SALRIDA': GuinjiRelationMeta(
    key: 'NA_SALRIDA',
    label: '나를 살리는 사람',
    hanja: '生',
    subtitle: '상대가 나를 살림',
    color: GuinjiColors.relationNaSalrida,
    orbit: 1,
    description: '힘들 때 절로 찾는, 나를 살리는 사람.',
  ),
  'JORYEOK': GuinjiRelationMeta(
    key: 'JORYEOK',
    label: '조력자',
    hanja: '助',
    subtitle: '쌍방 균형',
    color: GuinjiColors.relationJoryeok,
    orbit: 2,
    description: '서로의 약점을 채워주는 조력자.',
  ),
  'GACHI_GA': GuinjiRelationMeta(
    key: 'GACHI_GA',
    label: '같이 가야 좋은 길',
    hanja: '共',
    subtitle: '공동 상승',
    color: GuinjiColors.relationGachiGa,
    orbit: 3,
    description: '같이 걸을 때 더 멀리 가는 사이.',
  ),
  'NA_SALJINDA': GuinjiRelationMeta(
    key: 'NA_SALJINDA',
    label: '내가 살리는 사람',
    hanja: '育',
    subtitle: '내가 상대를 살림',
    color: GuinjiColors.relationNaSaljinda,
    orbit: 4,
    description: '내가 에너지를 주는 사람 — 가끔은 쉬어가도 좋아요.',
  ),
  'CHANG_GYIM': GuinjiRelationMeta(
    key: 'CHANG_GYIM',
    label: '내가 챙기는 사람',
    hanja: '養',
    subtitle: '내가 상대를 살림',
    color: GuinjiColors.relationChangGyim,
    orbit: 5,
    description: '주다 보면 내가 소모되기 쉬운 조합.',
  ),
  'GAMJEONG': GuinjiRelationMeta(
    key: 'GAMJEONG',
    label: '감정 충전소',
    hanja: '感',
    subtitle: '에너지 회복',
    color: GuinjiColors.relationGamjeong,
    orbit: 6,
    description: '만나면 마음이 회복되는 사람.',
  ),
  'DEUNGDEUNG': GuinjiRelationMeta(
    key: 'DEUNGDEUNG',
    label: '든든한 등받이',
    hanja: '護',
    subtitle: '상대가 나를 살림',
    color: GuinjiColors.relationDeungdeung,
    orbit: 7,
    description: '곁에서 흔들리지 않게 잡아주는 사람.',
  ),
  'KKEURIDA': GuinjiRelationMeta(
    key: 'KKEURIDA',
    label: '끌리는 사람',
    hanja: '緣',
    subtitle: '관성/식상 자화',
    color: GuinjiColors.relationKkeurida,
    orbit: 8,
    description: '끌리지만 안정감은 따로 가는 사이.',
  ),
  'GACHI_BICH': GuinjiRelationMeta(
    key: 'GACHI_BICH',
    label: '같이 빛나는 사람',
    hanja: '輝',
    subtitle: '쌍방 상승',
    color: GuinjiColors.relationGachiBich,
    orbit: 9,
    description: '각자의 결이 또렷한 채로 빛나는 사이.',
  ),
  'JAGEUKJE': GuinjiRelationMeta(
    key: 'JAGEUKJE',
    label: '자극제',
    hanja: '刺',
    subtitle: '긴장 → 성장',
    color: GuinjiColors.relationJageukje,
    orbit: 10,
    description: '서로의 날카로움이 성장으로 가는 자극제.',
  ),
  'GINGJANG': GuinjiRelationMeta(
    key: 'GINGJANG',
    label: '긴장 속 단짝',
    hanja: '緊',
    subtitle: '안정 + 긴장 공존',
    color: GuinjiColors.relationGingjang,
    orbit: 11,
    description: '부딪히면서도 놓지 않는 단짝.',
  ),
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
