/// [정통사주 80종 전용 신규 엔진] 대운/세운/월운 엔진(Phase 4) 공용
/// Pillar 생성 헬퍼.
///
/// [재구현 금지 원칙 준수] 이 함수는 `ManseryeokCoreEngine.calculatePillars`
/// 내부의 private `buildPillar()`(PHASE 1, 이미 검증됨)와 동일한 고정
/// 매핑 테이블(ganElement/zhiElement/ganKr/zhiKr/LunarUtil.getJiaZiIndex)을
/// 그대로 사용한다 — 새로운 계산 로직이 아니라, 이미 검증된 PHASE 1
/// 로직을 Phase 4 엔진 3개(대운/세운/월운) 파일에서 공용으로 재사용하기
/// 위한 추출본이다. PHASE 1 파일(`manseryeok_core_engine.dart`)은 이미
/// 검증·커밋되어 있으므로 회귀 위험을 피하기 위해 건드리지 않고, 별도
/// 파일로 동일 로직을 노출한다(PHASE 3의 `_invSheng`/`_invKe` 중복 노출과
/// 동일한 선례를 따른다).
library;

import 'package:lunar/lunar.dart' show LunarUtil;

import '../saju_engine.dart' show ganElement, ganKr, zhiElement, zhiKr;
import 'saju_profile.dart';

/// 천간+지지 한자 각 1글자(예: '甲','子')로부터 [Pillar]를 생성한다.
Pillar buildLuckPillar(String stemHanja, String branchHanja) {
  final stemInfo = ganElement[stemHanja]!;
  final branchInfo = zhiElement[branchHanja]!;
  final jiaZi = '$stemHanja$branchHanja';
  return Pillar(
    stemHanja: stemHanja,
    branchHanja: branchHanja,
    stemKr: ganKr[stemHanja]!,
    branchKr: zhiKr[branchHanja]!,
    stemElement: stemInfo.$1,
    stemYinYang: stemInfo.$2,
    branchElement: branchInfo.$1,
    branchYinYang: branchInfo.$2,
    jiaZiIndex: LunarUtil.getJiaZiIndex(jiaZi),
  );
}
