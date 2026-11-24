import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_core_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase2_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase3_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase4_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_profile.dart';
import 'dart:convert';

void main() {
  // 이권호: 1970년 음력 11월 26일, 자시(子時, 00:00~00:59 대표 00:30), 남성, 서울(KST)
  final withCore = ManseryeokCoreEngine.buildProfileWithCore(
    year: 1970,
    month: 11,
    day: 26,
    hour: 0,
    minute: 30,
    gender: 'male',
    calendarType: CalendarInputType.lunar,
    isLeapMonth: false,
  );
  final p2 = Phase2AnalysisEngine.analyze(baseProfile: withCore.profile, core: withCore.core);
  final p3 = Phase3AnalysisEngine.analyze(baseProfile: p2);
  final p4 = Phase4AnalysisEngine.analyze(
    baseProfile: p3,
    core: withCore.core,
    referenceDate: DateTime(2026, 11, 24),
    daewoonCount: 9,
  );

  final out = <String, dynamic>{};
  out['engineVersion'] = p4.engineVersion;
  out['solarDate'] = p4.solarDate;
  out['lunarDate'] = p4.lunarDate;
  out['lunarLeapMonth'] = p4.lunarLeapMonth;
  out['ziHourPolicy'] = p4.ziHourPolicy.toString();
  out['daewoonStartPrecision'] = p4.daewoonStartPrecision.toString();

  Map<String, dynamic> pillarMap(Pillar p) => {
    'stemHanja': p.stemHanja, 'branchHanja': p.branchHanja,
    'stemKr': p.stemKr, 'branchKr': p.branchKr,
    'stemElement': p.stemElement, 'stemYinYang': p.stemYinYang,
    'branchElement': p.branchElement, 'branchYinYang': p.branchYinYang,
    'kr': p.kr, 'hanja': p.hanja, 'jiaZiIndex': p.jiaZiIndex,
  };
  out['yearPillar'] = pillarMap(p4.yearPillar);
  out['monthPillar'] = pillarMap(p4.monthPillar);
  out['dayPillar'] = pillarMap(p4.dayPillar);
  out['hourPillar'] = pillarMap(p4.hourPillar);

  final fe = p4.fiveElements!;
  out['fiveElements'] = {
    'stemCount': fe.stemCount,
    'branchCount': fe.branchCount,
    'hiddenStemCount': fe.hiddenStemCount,
    'totalCount': fe.totalCount,
    'dominant': fe.dominant,
    'deficient': fe.deficient,
    'isImbalanced': fe.isImbalanced,
  };

  out['tenGods'] = p4.tenGods;

  final hs = p4.hiddenStems!;
  out['hiddenStems'] = hs.map((k, v) => MapEntry(k, {
    'branch': v.branch,
    'stems': v.stems.map((s) => {
      'stemHanja': s.stemHanja, 'stemKr': s.stemKr, 'role': s.role, 'tenGod': s.tenGod,
    }).toList(),
  }));

  out['twelveStages'] = p4.twelveStages?.toMap();

  out['relationships'] = p4.relationships?.map((r) => {
    'type': r.type, 'characters': r.characters, 'positions': r.positions, 'resultElement': r.resultElement,
  }).toList();

  out['sinsal'] = p4.sinsal?.map((s) => {
    'id': s.id, 'nameKr': s.nameKr, 'nameHanja': s.nameHanja, 'basis': s.basis, 'foundOn': s.foundOn,
  }).toList();

  final st = p4.strength!;
  out['strength'] = {
    'verdict': st.verdict, 'score': st.score,
    'monthOrderScore': st.monthOrderScore, 'rootScore': st.rootScore,
    'supportScore': st.supportScore, 'controlScore': st.controlScore, 'drainScore': st.drainScore,
    'detail': st.detail,
  };

  final yo = p4.yongsin!;
  out['yongsin'] = {
    'method': yo.method, 'yongsin': yo.yongsin, 'heesin': yo.heesin,
    'gisin': yo.gisin, 'gusin': yo.gusin, 'reasoning': yo.reasoning,
  };

  out['daewoon'] = p4.daewoon?.map((d) => {
    'index': d.index, 'startAge': d.startAge, 'startYear': d.startYear,
    'pillar': pillarMap(d.pillar), 'tenGodStem': d.tenGodStem, 'tenGodBranch': d.tenGodBranch,
  }).toList();

  out['sewoon'] = p4.sewoon?.map((s) => {
    'year': s.year, 'pillar': pillarMap(s.pillar), 'tenGodStem': s.tenGodStem, 'tenGodBranch': s.tenGodBranch,
  }).toList();

  out['wolwoon'] = p4.wolwoon?.map((w) => {
    'year': w.year, 'month': w.month, 'pillar': pillarMap(w.pillar),
    'tenGodStem': w.tenGodStem, 'tenGodBranch': w.tenGodBranch, 'jieQiName': w.jieQiName,
  }).toList();

  print(const JsonEncoder.withIndent('  ').convert(out));
}
