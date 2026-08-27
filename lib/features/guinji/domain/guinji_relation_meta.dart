import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';

/// 관계 유형(貴/同/緣/養/師) 메타데이터.
///
/// [Phase G-3] `GuinjiComponents.jsx`의 `RELATION_TYPES` 객체를 그대로
/// 이식한다. 판정 로직(RelationJudger)은 아직 구현되지 않았으므로, 이
/// 메타데이터는 순수 표시(라벨/한자/색상/부제/설명)용으로만 쓰인다.
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

/// 관계 유형 순서와 동일한 맵(guin → oreunpal → inyeon → salrim → horang).
const Map<String, GuinjiRelationMeta> guinjiRelationTypes = {
  'guin': GuinjiRelationMeta(
    key: 'guin',
    label: '귀인',
    hanja: '貴',
    subtitle: '나를 살리는 기운',
    color: GuinjiColors.relationGuin,
    orbit: 0,
    description: '나에게 긍정 기운을 더해주는 조력자예요. 곁에 두면 결이 잘 맞아 힘이 됩니다.',
  ),
  'oreunpal': GuinjiRelationMeta(
    key: 'oreunpal',
    label: '오른팔',
    hanja: '同',
    subtitle: '같은 기운의 동료',
    color: GuinjiColors.relationOreunpal,
    orbit: 1,
    description: '마음이 잘 맞고 실질적 협력이 되는 사람. 같은 방향을 보는 동료예요.',
  ),
  'inyeon': GuinjiRelationMeta(
    key: 'inyeon',
    label: '인연',
    hanja: '緣',
    subtitle: '서로 끌리는 합(合)',
    color: GuinjiColors.relationInyeon,
    orbit: 2,
    description: '천간·지지의 합(合)으로 서로 자연스레 끌리는 사이. 오래 보게 될 사람이에요.',
  ),
  'salrim': GuinjiRelationMeta(
    key: 'salrim',
    label: '살림꾼',
    hanja: '養',
    subtitle: '내가 돌보는 인연',
    color: GuinjiColors.relationSalrim,
    orbit: 3,
    description: '내가 살리는 기운. 내가 챙기고 이끌어주게 되는 사람이에요.',
  ),
  'horang': GuinjiRelationMeta(
    key: 'horang',
    label: '호랑이 선생',
    hanja: '師',
    subtitle: '나를 다잡는 스승',
    color: GuinjiColors.relationHorang,
    orbit: 4,
    description: '자극·조언으로 성장을 이끄는 스승. 극(剋)은 나쁨이 아니라 통제·성과를 만드는 작용이에요.',
  ),
};

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
