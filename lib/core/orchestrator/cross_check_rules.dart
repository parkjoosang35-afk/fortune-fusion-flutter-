/// [엔진 통합 지시문 STEP 3 §5] 4개 최소 교차검증 규칙쌍의 구체 구현.
///
/// [설계 결정 — 지시문과의 차이] 지시문 원문은 통합 `SajuRepository`/
/// `SajuResultModel{pillars,fiveElements,topicResults,summary}`를
/// 가정했으나, 실제 코드베이스에는 그런 모델이 없다(조사로 확인됨).
/// 대신 이미 검증된(live 실측 완료) 로컬 PHASE1~4 만세력 엔진이 계산해
/// 둔 [SajuProfile]의 필드(오행 카운트/합충형파해/용신/세운)를 "그대로
/// 읽어서" 교차검증 점수로 변환한다 — 새 계산을 추가하지 않고, 이미
/// 존재하는 결정론적 계산 결과를 재사용할 뿐이다.
library;

import '../../features/home/domain/manseryeok/saju_profile.dart';
import 'cross_check_rule.dart';
import 'unified_fortune_profile.dart';

String _joinText(Map<String, String> map) => map.values.join(' ');

/// 규칙1. 사주↔관상 — 축: 추진력.
/// 사주 쪽: 오행 중 목(木)+화(火) 비중(추진력/적극성과 전통적으로 연관되는
/// 오행)이 토금수 대비 얼마나 우세한지를 8글자 전체 대비 비율로 환산.
/// 관상 쪽: features/topicResults 텍스트에서 추진력 관련 키워드 균형.
class SajuFaceDriveRule extends CrossCheckRule {
  const SajuFaceDriveRule();

  @override
  String get ruleId => 'saju_face_drive_v1';
  @override
  String get pair => '사주↔관상';
  @override
  String get axis => '추진력';
  @override
  String get doorA => '사주';
  @override
  String get doorB => '관상';

  @override
  ScoreExtraction? extractA(UnifiedFortuneProfile profile) {
    final fe = profile.sajuProfile?.fiveElements;
    if (fe == null) return null;
    final total = fe.totalCount.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return null;
    final woodFire = (fe.totalCount['목'] ?? 0) + (fe.totalCount['화'] ?? 0);
    // 8글자 중 목화가 전부면 +1.0, 전무하면 -1.0.
    final score = ((woodFire / total) * 2 - 1).clamp(-1.0, 1.0);
    return ScoreExtraction(
      score: score,
      evidenceText:
          '사주 8글자 중 목(木)+화(火) $woodFire개/$total개 '
          '(목${fe.totalCount['목']} 화${fe.totalCount['화']} '
          '토${fe.totalCount['토']} 금${fe.totalCount['금']} '
          '수${fe.totalCount['수']}) — 추진력 성향 오행 비중',
      sourceDoor: '사주',
    );
  }

  @override
  ScoreExtraction? extractB(UnifiedFortuneProfile profile) {
    final face = profile.faceResult;
    if (face == null) return null;
    final text = '${_joinText(face.features)} ${_joinText(face.topicResults)}';
    final score = keywordBalanceScore(
      text: text,
      positiveKeywords: const ['추진력', '적극', '열정', '도전', '활발', '진취'],
      negativeKeywords: const ['소극', '신중', '차분', '느긋', '내성적', '위축'],
    );
    return ScoreExtraction(
      score: score,
      evidenceText: '관상 요약/부위별 특징 텍스트 키워드 균형(추진력 관련)',
      sourceDoor: '관상',
    );
  }
}

/// 규칙2. 사주↔손금 — 축: 기질.
/// 사주 쪽: 토(土)+금(金) 비중(안정/현실 지향 기질과 연관)이 우세한지.
/// 손금 쪽: lines 텍스트에서 안정/신중 관련 키워드 균형.
class SajuPalmTemperamentRule extends CrossCheckRule {
  const SajuPalmTemperamentRule();

  @override
  String get ruleId => 'saju_palm_temperament_v1';
  @override
  String get pair => '사주↔손금';
  @override
  String get axis => '기질';
  @override
  String get doorA => '사주';
  @override
  String get doorB => '손금';

  @override
  ScoreExtraction? extractA(UnifiedFortuneProfile profile) {
    final fe = profile.sajuProfile?.fiveElements;
    if (fe == null) return null;
    final total = fe.totalCount.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return null;
    final earthMetal = (fe.totalCount['토'] ?? 0) + (fe.totalCount['금'] ?? 0);
    final score = ((earthMetal / total) * 2 - 1).clamp(-1.0, 1.0);
    return ScoreExtraction(
      score: score,
      evidenceText:
          '사주 8글자 중 토(土)+금(金) $earthMetal개/$total개 — '
          '안정/현실 지향 기질 성향 오행 비중',
      sourceDoor: '사주',
    );
  }

  @override
  ScoreExtraction? extractB(UnifiedFortuneProfile profile) {
    final palm = profile.palmResult;
    if (palm == null) return null;
    final text = _joinText(palm.lines);
    final score = keywordBalanceScore(
      text: text,
      positiveKeywords: const ['안정', '신중', '현실적', '차분', '꼼꼼'],
      negativeKeywords: const ['즉흥', '감정적', '변화무쌍', '충동'],
    );
    return ScoreExtraction(
      score: score,
      evidenceText: '손금 라인별 특징 텍스트 키워드 균형(안정/현실 지향 관련)',
      sourceDoor: '손금',
    );
  }
}

/// 규칙3. 사주↔궁합 — 축: 관계.
/// 사주 쪽: 합충형파해 목록에서 "합"(화합) 관계 수 - "충/형/파/해/원진/귀문"
/// (갈등) 관계 수를 전체 관계 수로 정규화.
/// 궁합 쪽: 서버가 산출한 score(0~100)를 -1.0~+1.0으로 환산.
class SajuCompatibilityRelationRule extends CrossCheckRule {
  const SajuCompatibilityRelationRule();

  static const _harmonyTypes = {'천간합', '육합', '삼합', '방합'};
  static const _conflictTypes = {
    '천간충',
    '지지충',
    '형',
    '파',
    '해',
    '원진',
    '귀문',
  };

  @override
  String get ruleId => 'saju_compatibility_relation_v1';
  @override
  String get pair => '사주↔궁합';
  @override
  String get axis => '관계';
  @override
  String get doorA => '사주';
  @override
  String get doorB => '궁합';

  @override
  ScoreExtraction? extractA(UnifiedFortuneProfile profile) {
    final rel = profile.sajuProfile?.relationships;
    if (rel == null || rel.isEmpty) return null;
    final harmonyCount = rel.where((r) => _harmonyTypes.contains(r.type)).length;
    final conflictCount = rel
        .where((r) => _conflictTypes.contains(r.type))
        .length;
    final total = harmonyCount + conflictCount;
    if (total == 0) return null;
    final score = ((harmonyCount - conflictCount) / total).clamp(-1.0, 1.0);
    return ScoreExtraction(
      score: score,
      evidenceText:
          '사주 원국 합충형파해 — 합(화합) $harmonyCount건, '
          '충/형/파/해(갈등) $conflictCount건',
      sourceDoor: '사주',
    );
  }

  @override
  ScoreExtraction? extractB(UnifiedFortuneProfile profile) {
    final compat = profile.compatibilityResult;
    if (compat == null) return null;
    final score = ((compat.score - 50) / 50).clamp(-1.0, 1.0);
    return ScoreExtraction(
      score: score,
      evidenceText: '궁합 점수 ${compat.score}/100 (${compat.nameA}×${compat.nameB})',
      sourceDoor: '궁합',
    );
  }
}

/// 규칙4. 타로↔사주 — 축: 시기.
/// 타로 쪽: summary 텍스트에서 "지금이 좋은 때/기회" vs "기다려야 함"류
/// 키워드 균형.
/// 사주 쪽: 이미 계산된 용신(Phase3)과 올해 세운(Phase4)의 오행이
/// 일치하는지로 "지금 시기가 사주상 유리한지"를 판정(새 계산 없음 —
/// 이미 엔진이 산출해 둔 용신/세운 필드를 비교만 함).
class TarotSajuTimingRule extends CrossCheckRule {
  const TarotSajuTimingRule();

  @override
  String get ruleId => 'tarot_saju_timing_v1';
  @override
  String get pair => '타로↔사주';
  @override
  String get axis => '시기';
  @override
  String get doorA => '타로';
  @override
  String get doorB => '사주';

  @override
  ScoreExtraction? extractA(UnifiedFortuneProfile profile) {
    final tarot = profile.tarotResult;
    if (tarot == null) return null;
    final score = keywordBalanceScore(
      text: tarot.summary,
      positiveKeywords: const ['좋은 때', '기회', '적기', '순조로운', '지금 시작', '추진'],
      negativeKeywords: const ['기다려', '신중해야', '지연', '늦춰지는', '보류'],
    );
    return ScoreExtraction(
      score: score,
      evidenceText: '타로 리딩 요약 텍스트 키워드 균형(시기 관련): '
          '"${tarot.summary.length > 40 ? tarot.summary.substring(0, 40) : tarot.summary}..."',
      sourceDoor: '타로',
    );
  }

  @override
  ScoreExtraction? extractB(UnifiedFortuneProfile profile) {
    final sajuProfile = profile.sajuProfile;
    final yongsin = sajuProfile?.yongsin;
    final sewoonList = sajuProfile?.sewoon;
    if (yongsin == null || sewoonList == null || sewoonList.isEmpty) {
      return null;
    }
    final nowYear = DateTime.now().year;
    SewoonEntry? current;
    for (final s in sewoonList) {
      if (s.year == nowYear) {
        current = s;
        break;
      }
    }
    if (current == null) return null;

    final stemEl = current.pillar.stemElement;
    final branchEl = current.pillar.branchElement;
    double score;
    String matched;
    if (stemEl == yongsin.yongsin || branchEl == yongsin.yongsin) {
      score = 0.8;
      matched = '용신(${yongsin.yongsin})';
    } else if (stemEl == yongsin.heesin || branchEl == yongsin.heesin) {
      score = 0.4;
      matched = '희신(${yongsin.heesin})';
    } else if (stemEl == yongsin.gisin || branchEl == yongsin.gisin) {
      score = -0.8;
      matched = '기신(${yongsin.gisin})';
    } else if (stemEl == yongsin.gusin || branchEl == yongsin.gusin) {
      score = -0.4;
      matched = '구신(${yongsin.gusin})';
    } else {
      score = 0.0;
      matched = '용희기구 어느 쪽과도 불일치';
    }
    return ScoreExtraction(
      score: score,
      evidenceText:
          '$nowYear년 세운(${current.pillar.kr}, 천간$stemEl/지지$branchEl)이 '
          '$matched와 겹침 — 용신 판단법: ${yongsin.method}',
      sourceDoor: '사주',
    );
  }
}

/// 이번 범위(STEP 3)에서 활성화된 4개 규칙 전체 목록. [FortuneOrchestrator]가
/// 이 리스트를 기본값으로 사용한다 — 규칙 추가/제거는 이 리스트만 수정하면
/// 되고, 엔진/오케스트레이터 로직은 건드릴 필요가 없다.
const List<CrossCheckRule> defaultCrossCheckRules = [
  SajuFaceDriveRule(),
  SajuPalmTemperamentRule(),
  SajuCompatibilityRelationRule(),
  TarotSajuTimingRule(),
];
