// [관상·손금 후속 개발] 표현 레이어(LLM) 출력 품질 검증.
// saju-qa-check.ts의 핵심 검사(금지어/확정 단정 표현)만 재사용해 적용 범위를
// 좁힌 경량 버전이다 — saju처럼 7블록 분량/3-gram 중복 검사까지는 과하다고
// 판단했다(관상/손금은 topicResults 5개 문단 구조로 saju보다 단순함).
//
// route.ts는 LLM이 반환한 features/lines + topicResults 전체 텍스트를 모아
// checkFacePalmText()로 검증하고, 문제가 있으면 1회 재생성 → 그래도 실패하면
// 기존 FALLBACK 문구로 폴백한다(saju와 동일한 재시도/폴백 원칙).

// [face-palm 전용 조정, saju-qa-check.ts와의 차이] "사고"를 saju와 동일하게
// 단독 금지어로 두면, 손금 두뇌선(頭腦線) 해석에서 필수적으로 쓰이는 "사고력"
// "사고방식" "창의적 사고" 등 정상 표현까지 오탐으로 차단되어 표현 레이어가
// 매번 재시도→폴백으로 빠지는 버그가 실제 사진 테스트에서 확인되었다. 사건·
// 사고(事故) 의미는 "교통사고"/"안전사고"처럼 구체적 복합어로만 잡는다.
// [face-palm 전용 조정 ②] 단일 글자 "암"(癌)도 "대암형"/"암시"처럼 무관한 정상
// 한국어 단어에 부분 문자열로 포함되어 실제 사진 테스트에서 반복 오탐이
// 확인되었다. 한 글자 금지어는 전부 "질병/암 진단" 맥락의 복합어로 좁힌다.
const BANNED = [
  "죽음", "사망", "교통사고", "안전사고", "부상", "수술", "입원", "질병", "병원",
  "암 진단", "암에 걸", "위암", "폐암", "간암", "유방암",
  "이혼", "파혼", "이별", "파산", "파멸", "망한다", "큰 손실", "재앙",
  "배신", "단절", "액운", "흉사", "살(煞)", "반드시", "절대", "틀림없이",
  "100%", "할 운명", "위험합니다",
];
const HEDGE = ["반드시", "절대", "틀림없이", "확실히"];
const HEDGE_EXCEPTIONS = ["쉬워요", "편이에요", "수월"];

function sentences(t: string): string[] {
  return t
    .split(/[.!?。]\s*/)
    .map((s) => s.trim())
    .filter(Boolean);
}

/**
 * features/lines + topicResults의 전체 텍스트를 금지어/확정 단정 표현
 * 기준으로 검사한다. 문제가 없으면 빈 배열을 반환한다.
 */
export function checkFacePalmText(allTexts: string[]): string[] {
  const fail: string[] = [];
  const full = allTexts.join(" ");

  const hits = BANNED.filter((w) => full.includes(w));
  if (hits.length) fail.push(`[금지어] ${hits.join(", ")}`);

  for (const s of sentences(full)) {
    for (const h of HEDGE) {
      if (s.includes(h) && !HEDGE_EXCEPTIONS.some((k) => s.includes(k))) {
        fail.push(`[단정] ${s.slice(0, 40)}`);
      }
    }
  }

  // 각 항목이 너무 짧으면(10자 미만) 관찰 근거 없이 성의 없게 생성된 것으로 간주.
  for (const t of allTexts) {
    if (t.trim().length > 0 && t.trim().length < 10) {
      fail.push(`[분량부족] "${t}"`);
    }
  }

  return fail;
}
