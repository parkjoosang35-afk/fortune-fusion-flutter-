// ═══════════════════════════════════════════════════════════════
// FILE: fe_data.dart
// [운세 엔진 디자인 핸드오프] 정적 카피 & 데모 데이터.
// 출처: uploaded_files/fortune_engine_extracted/flutter/lib/data/engine_data.dart
// (README.md: "5엔진·29카탈로그·6차원·데모데이터+대조판정함수"
// — 레퍼런스 그대로 포팅, 카피 문구 한 글자도 바꾸지 않음).
//
// [중요 — 69종 항목/정통사주 계산정책과 무관] 이 파일은 "운세 엔진"
// 안내 화면 전용 정적 카피/데모 데이터이며, 실제 사주 계산 로직이나
// 69종 해석 API를 호출하지 않는다. LLM을 사용하지 않고, 판정 로직
// (agreementOf)도 결정론적 규칙(최대편차 계산)로만 동작한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'fe_tokens.dart';

enum FeEngineId { s, g, t, f, p }

extension FeEngineIdCode on FeEngineId {
  /// 조합 코드 생성용 1글자 (S,G,T,F,P).
  String get code => switch (this) {
    FeEngineId.s => 'S',
    FeEngineId.g => 'G',
    FeEngineId.t => 'T',
    FeEngineId.f => 'F',
    FeEngineId.p => 'P',
  };
}

class FeEngine {
  final FeEngineId id;
  final String ko,
      short,
      hanja,
      tag,
      mottoPlain,
      mottoBold,
      line,
      input,
      method,
      evidence;
  final Color color;
  const FeEngine(
    this.id,
    this.ko,
    this.short,
    this.hanja,
    this.color,
    this.tag,
    this.mottoPlain,
    this.mottoBold,
    this.line,
    this.input,
    this.method,
    this.evidence,
  );
}

const feEngines = <FeEngine>[
  FeEngine(
    FeEngineId.s,
    '정통사주',
    '사주',
    '四柱',
    FeColors.saju,
    'ENGINE · 01 · SAJU',
    '여덟 글자는 추측이 아니라 계산입니다',
    '추측이 아니라 계산',
    '입춘이 정하고, 절기가 정하고, 60갑자가 정합니다.',
    '생년월일시',
    '입춘·12절기 절입 시각과 60갑자 순환으로 여덟 글자를 세우고, 오행 분포·십신·신강신약을 정해진 득점 규칙으로 산출합니다.',
    '십신 중 편관·정관 0개 — 일간 기준 십신 산출 규칙 → 약함',
  ),
  FeEngine(
    FeEngineId.g,
    '귀인지도',
    '귀인',
    '貴人',
    FeColors.guiin,
    'ENGINE · 02 · GUIIN',
    '귀인은 복이 아니라 좌표입니다',
    '좌표',
    '귀인이 여덟 글자에 뜨지 않았다면 — 없다는 뜻이 아니라 대운에서 옵니다.',
    '생년월일시',
    '일간·월지에 천을·문창·천덕·월덕 귀인 구결(한자 원문)을 대입해, 여덟 글자 안에서 귀인이 뜨는 자리와 그 궁위·방위를 판정합니다.',
    '귀인 2개가 년·월·시(사회·직장·미래 자리)에 출현 — 궁위 → 강함',
  ),
  FeEngine(
    FeEngineId.t,
    '타로',
    '타로',
    '塔羅',
    FeColors.tarot,
    'ENGINE · 03 · TAROT',
    '카드의 정의는 원전에서, 추출은 검증 가능하게',
    '원전',
    '카드의 정의는 100년 원전에서.',
    '질문 + 시드',
    '라이더-웨이트 원전(1911)의 카드 정의에 따라 78장을 중복 없이 배치하고, 자리 의미 × 카드 의미로 해석합니다. 추출은 시드로 고정됩니다.',
    '펜타클 계열 2장 출현 → 재물감각 강함',
  ),
  FeEngine(
    FeEngineId.f,
    '관상',
    '관상',
    '觀相',
    FeColors.face,
    'ENGINE · 04 · FACE',
    '첫눈이 아니라, 비율로',
    '비율',
    '얼굴은 비율로 — 같은 입력, 같은 판정.',
    '얼굴 사진',
    '얼굴 랜드마크에서 삼정 비율과 인당·재백궁·관록궁을 측정해 전통 관상 기준에 대응시킵니다. 같은 입력이면 같은 판정입니다.',
    '재백궁(코) 폭 = 얼굴의 20% — 전통 재백궁 발달 기준 → 보통',
  ),
  FeEngine(
    FeEngineId.p,
    '손금',
    '손금',
    '手相',
    FeColors.palm,
    'ENGINE · 05 · PALM',
    '네 개의 선, 네 개의 측정',
    '네 개의 측정',
    '수명을 말하지 않는 생명선 해석.',
    '손바닥 사진',
    '생명·지혜·감정·운명 네 주선의 길이·휘어짐·끊김·분지를 측정해 수상 주선 해석표에 대응시킵니다. 생명선은 수명과 무관합니다.',
    '운명선 길이 = 손폭의 0.62배 — 수상 주선 해석표 기준 → 강함',
  ),
];

FeEngine feEngineOf(String code) =>
    feEngines.firstWhere((e) => e.id.code == code);

/// 29종 카탈로그. key = 엔진 코드(SGTFP 순서로 정렬) 또는 PKG1..3
const feCatalog = <String, String>{
  'S': '사주 정통 리딩 — 여덟 글자는 추측이 아니라 계산입니다',
  'G': '귀인지도 리딩 — 귀인은 복이 아니라 좌표입니다',
  'T': '타로 스프레드 리딩 — 카드의 정의는 원전에서, 추출은 검증 가능하게',
  'F': '관상 비율 리딩 — 첫눈이 아니라, 비율로',
  'P': '손금 주선 리딩 — 네 개의 선, 네 개의 측정',
  'SG': '사주×귀인지도 — 십신의 구조에서 귀인의 자리를 다시 봅니다',
  'ST': '사주×타로 — 여덟 글자의 구조와 카드의 메시지가 서로를 검증합니다',
  'SF': '사주×관상 — 안과 밖이 일치하는지, 나란히 놓고 봅니다',
  'SP': '사주×손금 — 글자의 구조와 손의 선을 교차시킵니다',
  'GT': '귀인지도×타로 — 귀인의 방위와 카드의 조언을 대조합니다',
  'GF': '귀인지도×관상 — 사주의 궁위와 얼굴의 궁(十二宮)을 겹쳐 봅니다',
  'GP': '귀인지도×손금 — 운명선의 방향과 귀인의 궁위를 맞춰 봅니다',
  'TF': '타로×관상 — 카드가 말하는 것과 인상이 말하는 것',
  'TP': '타로×손금 — 카드의 메시지, 선의 습성',
  'FP': '관상×손금 — 얼굴의 비율과 손의 각, 몸으로 보는 이중 확인',
  'SGT': '사주·귀인지도·타로 — 구조 → 조력 → 조언의 3단 검증',
  'SGF': '사주·귀인지도·관상 — 글자와 궁과 얼굴의 삼각 대조',
  'SGP': '사주·귀인지도·손금 — 글자, 궁위, 선, 세 근거의 교차',
  'STF': '사주·타로·관상 — 계산과 카드와 비율',
  'STP': '사주·타로·손금 — 하늘의 글자, 카드, 손의 선',
  'SFP': '사주·관상·손금 — 몸의 두 지도(얼굴·손)와 여덟 글자',
  'GTF': '귀인지도·타로·관상 — 귀인, 조언, 인상의 대조',
  'GTP': '귀인지도·타로·손금 — 귀인의 위치와 선의 방향',
  'GFP': '귀인지도·관상·손금 — 궁과 얼굴과 손',
  'TFP': '타로·관상·손금 — 카드와 몸의 이중 창',
  'SGTFP': '오경(五鏡) 종합 — 다섯 엔진이 하나의 결론을 서로 견제하고 세웁니다',
  'PKG1': '연애·결혼 심층 — 일지의 배우자 궁, 일주의 귀인, 감정선, 관계의 카드',
  'PKG2': '커리어·재물 심층 — 재성·재백궁·운명선·귀인 궁위의 대조',
  'PKG3': '학업·시험 심층 — 문창귀인·인성 십신·상정·소드의 다각 검증',
};
const fePackageSeals = {'PKG1': '緣', 'PKG2': '財', 'PKG3': '成'};

/// 선택된 엔진 → 코드 (항상 S,G,T,F,P 순서).
String feComboCode(Set<FeEngineId> sel) =>
    FeEngineId.values.where(sel.contains).map((e) => e.code).join();

String feComboKind(String code) {
  if (code.startsWith('PKG')) return '패키지';
  return const {1: '단일', 2: '듀오', 3: '트리오', 5: '종합'}[code.length] ?? '';
}

// ---------------- 대조 ----------------
const feDimensions = [
  ['표현력', '소통과 표현 방식'],
  ['사고력', '생각하는 힘'],
  ['추진력', '실행과 도전'],
  ['재물감각', '기회와 자원 활용'],
  ['방향성', '적성·진로·삶의 흐름'],
  ['귀인 조력', '도움과 인연'],
];

enum FeAgreement { ok, mid, tense, solo }

/// 강함=2 · 보통=1 · 약함=0. 최대편차 0=일치, 1=보완, 2=긴장. 엔진 1개면 단일 관찰.
/// [결정론적 규칙] LLM을 전혀 사용하지 않는다 — 입력 레벨의 최댓값-최솟값만으로
/// 판정하는 순수 함수.
FeAgreement feAgreementOf(List<int> levels) {
  if (levels.length < 2) return FeAgreement.solo;
  final maxV = levels.reduce((a, b) => a > b ? a : b);
  final minV = levels.reduce((a, b) => a < b ? a : b);
  final d = maxV - minV;
  if (d == 0) return FeAgreement.ok;
  if (d == 1) return FeAgreement.mid;
  return FeAgreement.tense;
}

const feAgreementCopy = {
  FeAgreement.ok: [
    '일치',
    '두 관점이 같은 방향을 가리킵니다.',
    '각기 다른 근거로 같은 결론에 도달했을 때 — 조합 리딩이 가장 강해지는 순간입니다.',
  ],
  FeAgreement.mid: [
    '보완',
    '한쪽이 조용한 영역을, 다른 한쪽이 채웁니다.',
    '사주가 말하지 않은 것을 손금이, 카드가 미처 못 담은 것을 얼굴이 담아줍니다.',
  ],
  FeAgreement.tense: [
    '긴장',
    '두 관점이 다르게 말할 때, 우리는 숨기지 않습니다.',
    '대조가 실패한 게 아니라, 그것이 대조의 가치입니다. 갈림의 근거까지 함께 봐주세요.',
  ],
  FeAgreement.solo: ['단일 관찰', '', ''],
};
const feLevelLabel = ['약함', '보통', '강함'];

// ---------------- 실측 데모 (오경 종합 · 1990-05-15 10:30 · "이직해도 될까요" · 셀틱 크로스 · seed demo1) ----------------
class FeEvidence {
  final String engine;
  final int level;
  final String text;
  final String rule;
  const FeEvidence(this.engine, this.level, this.text, [this.rule = '']);
}

const feDemoRows = <String, List<FeEvidence>>{
  '방향성': [
    FeEvidence('S', 0, '십신 중 편관·정관 0개', '일간 기준 십신 산출 규칙'),
    FeEvidence('G', 2, '귀인 2개가 년·월·시(사회·직장·미래 자리)에 출현', '궁위'),
    FeEvidence('P', 2, '운명선 길이 = 손폭의 0.62배', '수상 주선 해석표 기준'),
  ],
  '재물감각': [
    FeEvidence('S', 0, '십신 중 편재·정재 0개'),
    FeEvidence('T', 2, '펜타클 계열 2장 출현'),
    FeEvidence('F', 1, '재백궁(코) 폭 = 얼굴의 20%', '전통 재백궁 발달 기준'),
  ],
  '표현력': [
    FeEvidence('S', 0, '식신·상관 0개'),
    FeEvidence('G', 2, '월덕귀인이 일주에 출현'),
    FeEvidence('T', 2, '컵 계열 2장'),
    FeEvidence('F', 1, '중정(눈·코) 33.1%'),
  ],
  '추진력': [
    FeEvidence('S', 2, '비견·겁재 2개'),
    FeEvidence('F', 1, '하정(입·턱) 34.5%'),
    FeEvidence('P', 2, '생명선 휘어짐 0.071 (곡률 기준 0.06)', '활력의 선, 수명과 무관'),
  ],
  '사고력': [FeEvidence('S', 0, '편인·정인 0개'), FeEvidence('T', 1, '소드 계열 1장')],
  '귀인 조력': [FeEvidence('G', 2, '8글자 안에 뜬 귀인 항성 2개', '전래 구결 판별')],
};
const feDemoInterpretation =
    '"글자로는 관성이 약하지만, 귀인 둘이 사회적 자리에서 돕고 손의 운명선은 분명합니다. '
    '표현력에서 사주와 나머지 관점이 갈린 것도 사실입니다. — 우리는 이 갈림을 지우지 않고, '
    '근거와 함께 드립니다."';
