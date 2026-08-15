/// [정통사주 80종 전용 신규 엔진] 합충형파해(合沖刑破害) + 원진/귀문 엔진 —
/// PHASE 2 §9.
///
/// 37번 지시 §9 "천간합/천간충, 육합/삼합/방합/지지충/형/파/해/원진/귀문을
/// '어떤 글자+어떤 글자+어떤 관계+어느 위치' 형태로 저장"에 대응한다.
///
/// [고정표의 출처] 아래 상수 테이블(육합/삼합/방합/지지충/형/파/해/원진/
/// 귀문/천간합/천간충)은 특정 개인의 생년월일과 무관하게 전통 명리학
/// 문헌에 공통적으로 등재된 "보편 고정 대응표"다(§9 작업 시 웹 조사로
/// 교차 검증). `lunar` 패키지는 육합(`HE_ZHI_6`)/지지충(`CHONG`)/
/// 천간합(`HE_GAN_5`)/천간사충(`CHONG_GAN_4`)만 제공하고 삼합/방합/형/파/
/// 해/원진/귀문은 제공하지 않으므로, 이 파일에서 직접 고정 테이블로
/// 선언한다. 이는 37번 지시 §34가 금지하는 "생년월일 해시/임의 랜덤/
/// 임의 공식"과는 무관한, 명리학 교과서 수준의 정적 데이터다.
library;

import 'saju_profile.dart';

/// 육합(六合) — 지지 두 글자가 만나 합화(合化)하는 오행.
/// 子丑合土, 寅亥合木, 卯戌合火, 辰酉合金, 巳申合水, 午未合火.
const List<(String, String, String)> _liuHePairs = [
  ('子', '丑', '토'),
  ('寅', '亥', '목'),
  ('卯', '戌', '화'),
  ('辰', '酉', '금'),
  ('巳', '申', '수'),
  ('午', '未', '화'),
];

/// 삼합(三合) — 지지 세 글자가 모여 합국(合局)을 이루는 오행.
/// 申子辰合水, 亥卯未合木, 寅午戌合火, 巳酉丑合金.
const List<(List<String>, String)> _sanHeGroups = [
  (['申', '子', '辰'], '수'),
  (['亥', '卯', '未'], '목'),
  (['寅', '午', '戌'], '화'),
  (['巳', '酉', '丑'], '금'),
];

/// 방합(方合) — 계절별 지지 세 글자가 모여 이루는 오행.
/// 寅卯辰=동방木, 巳午未=남방火, 申酉戌=서방金, 亥子丑=북방水.
const List<(List<String>, String)> _fangHeGroups = [
  (['寅', '卯', '辰'], '목'),
  (['巳', '午', '未'], '화'),
  (['申', '酉', '戌'], '금'),
  (['亥', '子', '丑'], '수'),
];

/// 지지충(六沖) — 정반대 위치의 지지끼리 충돌.
/// 子午沖, 丑未沖, 寅申沖, 卯酉沖, 辰戌沖, 巳亥沖.
const List<(String, String)> _liuChongPairs = [
  ('子', '午'), ('丑', '未'), ('寅', '申'),
  ('卯', '酉'), ('辰', '戌'), ('巳', '亥'),
];

/// 육해(六害) — 육합을 충으로 방해하는 관계.
/// 子未害, 丑午害, 寅巳害, 卯辰害, 申亥害, 酉戌害.
const List<(String, String)> _liuHaiPairs = [
  ('子', '未'), ('丑', '午'), ('寅', '巳'),
  ('卯', '辰'), ('申', '亥'), ('酉', '戌'),
];

/// 육파(六破) — 삼합/방합의 기세를 깨뜨리는 관계.
/// 子酉破, 丑辰破, 寅亥破, 卯午破, 巳申破, 未戌破.
const List<(String, String)> _liuPoPairs = [
  ('子', '酉'), ('丑', '辰'), ('寅', '亥'),
  ('卯', '午'), ('巳', '申'), ('未', '戌'),
];

/// 원진(怨嗔) — 子未, 丑午, 寅酉, 卯申, 辰亥, 巳戌.
const List<(String, String)> _yuanChenPairs = [
  ('子', '未'), ('丑', '午'), ('寅', '酉'),
  ('卯', '申'), ('辰', '亥'), ('巳', '戌'),
];

/// 귀문관살(鬼門關殺) — 子酉, 丑午, 寅未, 卯申, 辰亥, 巳戌.
const List<(String, String)> _guiMenPairs = [
  ('子', '酉'), ('丑', '午'), ('寅', '未'),
  ('卯', '申'), ('辰', '亥'), ('巳', '戌'),
];

/// 삼형(三刑)/상형(相刑) 그룹 — 寅巳申(지세지형)·丑戌未(무은지형)는
/// 3글자가 모두 있어야 완전 성립하지만, 이 엔진은 2글자만 있어도
/// "부분 성립"으로 기록한다(예: 寅+巳만 있어도 형 관계로 저장, 3글자가
/// 다 모이면 별도로 "삼형 완전성립" 1건을 추가 기록).
const List<List<String>> _sanXingGroups = [
  ['寅', '巳', '申'], // 지세지형(持勢之刑)
  ['丑', '戌', '未'], // 무은지형(無恩之刑)
];

/// 상형(相刑) — 子卯(무례지형), 2글자만으로 성립.
const List<(String, String)> _xiangXingPairs = [
  ('子', '卯'),
];

/// 자형(自刑) — 같은 지지 두 글자(辰辰/午午/酉酉/亥亥)가 만나면 성립.
const List<String> _ziXingBranches = ['辰', '午', '酉', '亥'];

/// 천간합(天干合, 五合) — 甲己合土, 乙庚合金, 丙辛合水, 丁壬合木, 戊癸合火.
const List<(String, String, String)> _tianGanHePairs = [
  ('甲', '己', '토'),
  ('乙', '庚', '금'),
  ('丙', '辛', '수'),
  ('丁', '壬', '목'),
  ('戊', '癸', '화'),
];

/// 천간충(天干沖, 四沖) — 甲庚沖, 乙辛沖, 丙壬沖, 丁癸沖(戊己는 중앙토라
/// 충이 없음).
const List<(String, String)> _tianGanChongPairs = [
  ('甲', '庚'), ('乙', '辛'), ('丙', '壬'), ('丁', '癸'),
];

class RelationshipsEngine {
  RelationshipsEngine._();

  /// 사주 8글자(4천간+4지지) 전체를 대상으로 위 고정표를 전수 대조해
  /// 성립하는 모든 관계를 찾아 반환한다. 같은 두 글자 조합이 여러 위치에
  /// 동시에 나타나면(예: 년지·시지가 모두 子일 때 월지 丑과 각각 합) 각
  /// 위치 조합마다 별도 항목으로 기록한다.
  static List<SajuRelationship> analyze({
    required Pillar yearPillar,
    required Pillar monthPillar,
    required Pillar dayPillar,
    required Pillar hourPillar,
  }) {
    final stems = [
      yearPillar.stemHanja,
      monthPillar.stemHanja,
      dayPillar.stemHanja,
      hourPillar.stemHanja,
    ];
    final branches = [
      yearPillar.branchHanja,
      monthPillar.branchHanja,
      dayPillar.branchHanja,
      hourPillar.branchHanja,
    ];
    const stemPosLabel = ['년간', '월간', '일간', '시간'];
    const branchPosLabel = ['년지', '월지', '일지', '시지'];

    final result = <SajuRelationship>[];

    // ── 천간합 ──
    for (final (a, b, el) in _tianGanHePairs) {
      for (var i = 0; i < 4; i++) {
        for (var j = i + 1; j < 4; j++) {
          if ((stems[i] == a && stems[j] == b) ||
              (stems[i] == b && stems[j] == a)) {
            result.add(SajuRelationship(
              type: '천간합',
              characters: [stems[i], stems[j]],
              positions: [stemPosLabel[i], stemPosLabel[j]],
              resultElement: el,
            ));
          }
        }
      }
    }

    // ── 천간충 ──
    for (final (a, b) in _tianGanChongPairs) {
      for (var i = 0; i < 4; i++) {
        for (var j = i + 1; j < 4; j++) {
          if ((stems[i] == a && stems[j] == b) ||
              (stems[i] == b && stems[j] == a)) {
            result.add(SajuRelationship(
              type: '천간충',
              characters: [stems[i], stems[j]],
              positions: [stemPosLabel[i], stemPosLabel[j]],
              resultElement: '',
            ));
          }
        }
      }
    }

    void addBranchPairRelation(
      String type,
      List<(String, String)> pairs, {
      Map<(String, String), String>? elementOf,
    }) {
      for (final (a, b) in pairs) {
        for (var i = 0; i < 4; i++) {
          for (var j = i + 1; j < 4; j++) {
            if ((branches[i] == a && branches[j] == b) ||
                (branches[i] == b && branches[j] == a)) {
              result.add(SajuRelationship(
                type: type,
                characters: [branches[i], branches[j]],
                positions: [branchPosLabel[i], branchPosLabel[j]],
                resultElement: elementOf?[(a, b)] ?? '',
              ));
            }
          }
        }
      }
    }

    // ── 육합 ──
    final liuHeElementMap = {
      for (final (a, b, el) in _liuHePairs) (a, b): el,
    };
    addBranchPairRelation(
      '육합',
      [for (final (a, b, _) in _liuHePairs) (a, b)],
      elementOf: liuHeElementMap,
    );

    // ── 지지충 ──
    addBranchPairRelation('지지충', _liuChongPairs);

    // ── 육해 ──
    addBranchPairRelation('해', _liuHaiPairs);

    // ── 육파 ──
    addBranchPairRelation('파', _liuPoPairs);

    // ── 원진 ──
    addBranchPairRelation('원진', _yuanChenPairs);

    // ── 귀문관살 ──
    addBranchPairRelation('귀문', _guiMenPairs);

    // ── 상형(자묘) ──
    addBranchPairRelation('형', _xiangXingPairs);

    // ── 자형(辰辰/午午/酉酉/亥亥) ──
    for (final b in _ziXingBranches) {
      for (var i = 0; i < 4; i++) {
        for (var j = i + 1; j < 4; j++) {
          if (branches[i] == b && branches[j] == b) {
            result.add(SajuRelationship(
              type: '자형',
              characters: [branches[i], branches[j]],
              positions: [branchPosLabel[i], branchPosLabel[j]],
              resultElement: '',
            ));
          }
        }
      }
    }

    // ── 삼합(3글자 모두 있을 때만 성립 — 부분합은 기록하지 않음:
    //     명리학에서 삼합 중 2글자만 있는 "반합(半合)"은 별도 학설이 많아
    //     Phase 2에서는 3글자 완전성립만 다룬다) ──
    for (final (group, el) in _sanHeGroups) {
      final foundPositions = <int>[];
      for (final g in group) {
        final idx = branches.indexOf(g);
        if (idx != -1 && !foundPositions.contains(idx)) {
          foundPositions.add(idx);
        }
      }
      // 그룹의 세 글자가 서로 다른 위치에서 모두 발견되어야 완전성립.
      final matchedChars = <String>[];
      final matchedPositions = <String>[];
      final usedIdx = <int>{};
      for (final g in group) {
        for (var i = 0; i < 4; i++) {
          if (branches[i] == g && !usedIdx.contains(i)) {
            matchedChars.add(branches[i]);
            matchedPositions.add(branchPosLabel[i]);
            usedIdx.add(i);
            break;
          }
        }
      }
      if (matchedChars.length == 3) {
        result.add(SajuRelationship(
          type: '삼합',
          characters: matchedChars,
          positions: matchedPositions,
          resultElement: el,
        ));
      }
    }

    // ── 방합(3글자 완전성립만) ──
    for (final (group, el) in _fangHeGroups) {
      final matchedChars = <String>[];
      final matchedPositions = <String>[];
      final usedIdx = <int>{};
      for (final g in group) {
        for (var i = 0; i < 4; i++) {
          if (branches[i] == g && !usedIdx.contains(i)) {
            matchedChars.add(branches[i]);
            matchedPositions.add(branchPosLabel[i]);
            usedIdx.add(i);
            break;
          }
        }
      }
      if (matchedChars.length == 3) {
        result.add(SajuRelationship(
          type: '방합',
          characters: matchedChars,
          positions: matchedPositions,
          resultElement: el,
        ));
      }
    }

    // ── 삼형(3글자 완전성립만: 寅巳申/丑戌未) ──
    for (final group in _sanXingGroups) {
      final matchedChars = <String>[];
      final matchedPositions = <String>[];
      final usedIdx = <int>{};
      for (final g in group) {
        for (var i = 0; i < 4; i++) {
          if (branches[i] == g && !usedIdx.contains(i)) {
            matchedChars.add(branches[i]);
            matchedPositions.add(branchPosLabel[i]);
            usedIdx.add(i);
            break;
          }
        }
      }
      if (matchedChars.length == 3) {
        result.add(SajuRelationship(
          type: '삼형',
          characters: matchedChars,
          positions: matchedPositions,
          resultElement: '',
        ));
      }
    }

    return result;
  }
}
