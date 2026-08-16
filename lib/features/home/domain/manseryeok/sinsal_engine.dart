/// [정통사주 80종 전용 신규 엔진] 신살(神殺) 엔진 — PHASE 2 §11.
///
/// 37번 지시 §11 "sinsal_rules.json 전수조사 후 (기존계산가능→엔진연결) /
/// (계산로직없음→규칙정의후구현) / (의미만존재→해석콘텐츠분리)로 분류,
/// 최소 15종 이상 실계산 가능하게" 에 대응한다.
///
/// [전수조사 결과 — assets/jeontong/rules/sinsal_rules.json]
/// 이 파일은 30개 신살 키에 대해 `kr`/`easy`/`meaning`/`effect`(순수
/// 해석 콘텐츠)만 갖고 있고 계산 로직이 전혀 없다("의미만존재" 카테고리).
/// 따라서 이 엔진은 전통 명리학 문헌(웹 교차검증, §11 조사)의 보편
/// 고정표를 근거로 "규칙정의후구현" 방식으로 최소 15종 이상을 구현한다.
///
/// [절대 원칙] 아래 모든 판정 로직은 (일간|일지|년지) 등 명식 자체의
/// 글자와 전통 고정 대응표만을 사용하는 결정론적 계산이다. 생년월일
/// 문자열 해시나 임의 랜덤은 전혀 사용하지 않는다.
///
/// [12신살(十二神殺) 산출 원리] 년지/일지가 속한 삼합(申子辰·巳酉丑·
/// 寅午戌·亥卯未) 중 어느 그룹인지 찾고, 그 그룹의 생지(生地, 삼합의
/// 첫 글자)를 "지살" 위치로 고정한 뒤, 12지지를 순환하며
/// [겁살(-3)·재살(-2)·천살(-1)·지살(0)·년살(+1)·월살(+2)·망신살(+3)·
/// 장성살(+4)·반안살(+5)·역마살(+6)·육해살(+7)·화개살(+8)] 오프셋으로
/// 나머지 11개 신살의 지지를 결정한다(§11 웹 조사로 4개 삼합 그룹 전체
/// 교차 검증 완료). 기준(basis)은 이 프로젝트에서 "일지"를 기본으로
/// 채택한다(현대 명리학 주류 관행 — 과거에는 년지 기준이 전통이었으나
/// 현재는 일지 기준이 통용된다).
library;

import '../saju_engine.dart' show findSinsal, getGongmang;
import 'relationships_engine.dart' show RelationshipsEngine;
import 'saju_profile.dart';

const List<String> _zhiOrder = [
  '子',
  '丑',
  '寅',
  '卯',
  '辰',
  '巳',
  '午',
  '未',
  '申',
  '酉',
  '戌',
  '亥',
];

/// 지지 → 그 지지가 속한 삼합 그룹의 생지(生地, 삼합 그룹의 첫 글자).
/// 申子辰(생신)/巳酉丑(생사)/寅午戌(생인)/亥卯未(생해).
const Map<String, String> _branchToGroupSaengJi = {
  '申': '申',
  '子': '申',
  '辰': '申',
  '巳': '巳',
  '酉': '巳',
  '丑': '巳',
  '寅': '寅',
  '午': '寅',
  '戌': '寅',
  '亥': '亥',
  '卯': '亥',
  '未': '亥',
};

/// 지살(오프셋 0) 기준 12신살 순서 오프셋(§11 조사로 4개 삼합 그룹 전수
/// 대조 검증됨 — 申子辰: 겁巳재午천未지申년酉월戌망亥장子반丑역寅육卯화辰).
const List<(int, String)> _twelveSinsalOffsets = [
  (-3, '겁살'),
  (-2, '재살'),
  (-1, '천살'),
  (0, '지살'),
  (1, '년살'),
  (2, '월살'),
  (3, '망신살'),
  (4, '장성살'),
  (5, '반안살'),
  (6, '역마살'),
  (7, '육해살'),
  (8, '화개살'),
];

/// 양인살(羊刃殺) — 일간(양간만) 기준 지지 고정표. 甲→卯, 丙→午, 戊→午,
/// 庚→酉, 壬→子(§11 조사, 다수 문헌 공통 인용 — 음간 양인은 학파 차이가
/// 커서 Phase 2에서는 제외).
const Map<String, String> _yangInByDayGan = {
  '甲': '卯',
  '丙': '午',
  '戊': '午',
  '庚': '酉',
  '壬': '子',
};

/// 괴강살(魁罡殺) — 일주(day pillar) 고정표. 庚辰/庚戌/壬辰/戊戌(§11 조사,
/// 다수 문헌 공통 인용 4주 — 戊辰/壬戌 포함 여부는 학파 차이가 있어 제외).
const List<String> _goeGangDayPillars = ['庚辰', '庚戌', '壬辰', '戊戌'];

/// 백호대살(白虎大殺) — 일주(day pillar) 고정표. 甲辰/乙未/丙戌/丁丑/
/// 戊辰/壬戌/癸丑(§11 조사, 7주 전 문헌 공통 인용).
const List<String> _baekhoDaeSalPillars = [
  '甲辰',
  '乙未',
  '丙戌',
  '丁丑',
  '戊辰',
  '壬戌',
  '癸丑',
];

class SinsalEngine {
  SinsalEngine._();

  /// 12신살 전체를 계산한다. [basisBranch]는 통상 일지(day branch)를
  /// 사용한다(현대 명리학 주류 관행). 반환값 key는 12신살 이름, value는
  /// 그 신살에 해당하는 지지 한자 1글자.
  static Map<String, String> computeTwelveSinsalTable(String basisBranch) {
    final saengJi = _branchToGroupSaengJi[basisBranch]!;
    final saengJiIdx = _zhiOrder.indexOf(saengJi);
    return {
      for (final (offset, name) in _twelveSinsalOffsets)
        name: _zhiOrder[(saengJiIdx + offset + 24) % 12],
    };
  }

  /// [SajuProfile]의 사주 8글자를 입력받아 최소 15종 이상의 신살을
  /// 계산해 [SinsalEntry] 목록으로 반환한다.
  static List<SinsalEntry> analyze({
    required Pillar yearPillar,
    required Pillar monthPillar,
    required Pillar dayPillar,
    required Pillar hourPillar,
  }) {
    final positions = <String, Pillar>{
      'year': yearPillar,
      'month': monthPillar,
      'day': dayPillar,
      'hour': hourPillar,
    };
    const posLabel = {'year': '년지', 'month': '월지', 'day': '일지', 'hour': '시지'};
    final branches = positions.map((k, v) => MapEntry(k, v.branchHanja));
    final dayGan = dayPillar.stemHanja;
    final entries = <SinsalEntry>[];

    // ── ① 기존 saju_engine.dart 재사용: 천을귀인/문창귀인/역마(3종) ──
    final zhiList = [
      yearPillar.branchHanja,
      monthPillar.branchHanja,
      dayPillar.branchHanja,
      hourPillar.branchHanja,
    ];
    final legacyFound = findSinsal(dayGan, zhiList);
    final dayZhi = dayPillar.branchHanja;
    for (final f in legacyFound) {
      final name = f.split('(').first; // '天乙貴人(천을귀인)' → '天乙貴人'
      final foundOn = <String>[
        for (final e in branches.entries)
          if (_matchesLegacySinsal(name, dayGan, dayZhi, e.value))
            posLabel[e.key]!,
      ];
      entries.add(
        SinsalEntry(
          id: name,
          nameKr: f.contains('(')
              ? f.split('(').last.replaceAll(')', '')
              : name,
          nameHanja: name,
          basis: '일간',
          foundOn: foundOn,
        ),
      );
    }

    // ── ② 공망(空亡) — 기존 getGongmang() 재사용 ──
    final gongmang = getGongmang(dayGan, dayPillar.branchHanja);
    final gongmangBranches = gongmang.split(' ').first; // 예: '戌亥'
    final gongmangFoundOn = <String>[
      for (final e in branches.entries)
        if (gongmangBranches.contains(e.value)) posLabel[e.key]!,
    ];
    entries.add(
      SinsalEntry(
        id: '空亡',
        nameKr: '공망',
        nameHanja: '空亡',
        basis: '일주',
        foundOn: gongmangFoundOn,
      ),
    );

    // ── ③ 12신살(일지 기준) — 겁살/재살/천살/지살/년살(도화)/월살/
    //     망신살/장성살/반안살/역마살/육해살/화개살 (12종) ──
    final table = computeTwelveSinsalTable(dayPillar.branchHanja);
    for (final entry in table.entries) {
      final name = entry.key;
      final branch = entry.value;
      final foundOn = <String>[
        for (final e in branches.entries)
          if (e.value == branch) posLabel[e.key]!,
      ];
      entries.add(
        SinsalEntry(
          id: '12신살_$name',
          nameKr: name,
          nameHanja: branch,
          basis: '일지',
          foundOn: foundOn,
        ),
      );
    }

    // ── ④ 양인살(羊刃殺) — 일간 기준 ──
    final yangIn = _yangInByDayGan[dayGan];
    if (yangIn != null) {
      final foundOn = <String>[
        for (final e in branches.entries)
          if (e.value == yangIn) posLabel[e.key]!,
      ];
      entries.add(
        SinsalEntry(
          id: '羊刃',
          nameKr: '양인살',
          nameHanja: yangIn,
          basis: '일간',
          foundOn: foundOn,
        ),
      );
    }

    // ── ⑤ 괴강살(魁罡殺) — 4주(년/월/일/시) 전체에서 일주 조합 검사 ──
    final goeGangFoundOn = <String>[
      for (final e in positions.entries)
        if (_goeGangDayPillars.contains(e.value.hanja)) posLabel[e.key]!,
    ];
    if (goeGangFoundOn.isNotEmpty) {
      entries.add(
        SinsalEntry(
          id: '魁罡',
          nameKr: '괴강살',
          nameHanja: '魁罡',
          basis: '주(柱) 전체',
          foundOn: goeGangFoundOn,
        ),
      );
    }

    // ── ⑥ 백호대살(白虎大殺) — 4주 전체에서 검사 ──
    final baekhoFoundOn = <String>[
      for (final e in positions.entries)
        if (_baekhoDaeSalPillars.contains(e.value.hanja)) posLabel[e.key]!,
    ];
    if (baekhoFoundOn.isNotEmpty) {
      entries.add(
        SinsalEntry(
          id: '白虎',
          nameKr: '백호대살',
          nameHanja: '白虎',
          basis: '주(柱) 전체',
          foundOn: baekhoFoundOn,
        ),
      );
    }

    // ── ⑦ 원진(元辰) — relationships_engine에서 이미 계산된 결과를
    //     신살 목록에도 반영(사용자가 신살 탭에서도 조회 가능하도록) ──
    final relationships = RelationshipsEngine.analyze(
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
    );
    final yuanChenRelations = relationships
        .where((r) => r.type == '원진')
        .toList();
    if (yuanChenRelations.isNotEmpty) {
      final foundOn = <String>{
        for (final r in yuanChenRelations) ...r.positions,
      }.toList();
      entries.add(
        SinsalEntry(
          id: '元辰',
          nameKr: '원진살',
          nameHanja: '元辰',
          basis: '지지 조합',
          foundOn: foundOn,
        ),
      );
    }

    return entries;
  }

  /// findSinsal()이 반환한 이름 문자열(한자 부분)이 실제로 어느 지지에서
  /// 발동했는지 역추적하기 위한 헬퍼(기존 saju_engine.dart의 findSinsal은
  /// 이름 목록만 반환하고 위치를 반환하지 않으므로, 이 엔진에서 원본
  /// 고정표를 참고해 위치를 다시 계산한다).
  static bool _matchesLegacySinsal(
    String name,
    String dayGan,
    String dayZhi,
    String zhi,
  ) {
    switch (name) {
      case '天乙貴人':
        return _cheoneulGwiin[dayGan]?.contains(zhi) ?? false;
      case '文昌貴人':
        return _munchangGwiin[dayGan] == zhi;
      case '驛馬':
        // findSinsal()은 일지가 속한 방합 그룹 기준의 역마 지지가
        // 원국(4지지) 중 어디에 있는지로 판정한다.
        return _yeokma[dayZhi] == zhi;
      default:
        return false;
    }
  }
}

// saju_engine.dart의 yeokma 고정표와 동일한 값(위치 역추적 전용 재선언 —
// 계산 로직 재구현이 아니라 동일 고정표를 참조용으로 노출).
const Map<String, String> _yeokma = {
  '寅': '申',
  '午': '申',
  '戌': '申',
  '申': '寅',
  '子': '寅',
  '辰': '寅',
  '巳': '亥',
  '酉': '亥',
  '丑': '亥',
  '亥': '巳',
  '卯': '巳',
  '未': '巳',
};

// saju_engine.dart 내부 private 상수와 동일한 값(위치 역추적 전용 재선언 —
// 계산 로직 재구현이 아니라 동일 고정표를 참조용으로 노출).
const Map<String, List<String>> _cheoneulGwiin = {
  '甲': ['丑', '未'],
  '戊': ['丑', '未'],
  '庚': ['丑', '未'],
  '乙': ['子', '申'],
  '己': ['子', '申'],
  '丙': ['亥', '酉'],
  '丁': ['亥', '酉'],
  '壬': ['卯', '巳'],
  '癸': ['卯', '巳'],
  '辛': ['寅', '午'],
};

const Map<String, String> _munchangGwiin = {
  '甲': '巳',
  '乙': '午',
  '丙': '申',
  '丁': '酉',
  '戊': '申',
  '己': '酉',
  '庚': '亥',
  '辛': '子',
  '壬': '寅',
  '癸': '卯',
};
