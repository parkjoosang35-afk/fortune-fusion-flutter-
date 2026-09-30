// [정통사주 AI 프롬프트 개선 — saju-output-spec.pdf §8 "자동 검증 스크립트"]
//
// PDF 원문은 Python(saju_qa_check.py, 의존성 없음)으로 제공되지만, 이 서버
// (admin_web)는 Next.js/TypeScript 런타임이라 저장 훅(route.ts)에서 바로
// 쓸 수 있도록 동일 로직을 TypeScript로 이식한다. 검사 항목/기준값은 PDF
// §8과 100% 동일하게 유지한다(파이썬 원본은 scripts/saju_qa_check.py에
// 그대로 보존 — 관리자가 오프라인에서 결과 JSON을 검증할 때 사용 가능).
//
// route.ts는 LLM이 반환한 SajuLlmResult를 저장하기 전에 checkSajuResult()를
// 호출하고, 문제가 있으면 1회 재생성 → 그래도 실패하면 안전 문구로 폴백한다
// (§11 적용순서체크리스트 6번, §8 "운영 파라미터 권장값: 재생성 최대 2회").

export interface SajuLlmSection {
  key: string;
  title: string;
  body: string[];
}

export interface SajuLlmResult {
  headline: string;
  sections: SajuLlmSection[];
  actions: string[];
  closing: string;
  evidence_used: string[];
}

const BANNED = [
  "죽음",
  "사망",
  "사고",
  "부상",
  "수술",
  "입원",
  "질병",
  "병원",
  "암",
  "이혼",
  "파혼",
  "이별",
  "파산",
  "파멸",
  "망한다",
  "큰 손실",
  "재앙",
  "배신",
  "단절",
  "액운",
  "흉",
  "살(煞)",
  "반드시",
  "절대",
  "틀림없이",
  "100%",
  "할 운명",
  "위험합니다",
];
const HEDGE = ["반드시", "절대", "틀림없이", "확실히"];
const CLICHE = ["이 사주는", "타고난", "구조입니다", "조만간 좋은 소식"];
const HEDGE_EXCEPTIONS = ["쉬워요", "편이에요", "수월"];
const NEGATIVE_WORDS = ["주의", "조심", "어긋", "새는", "떨어지", "무리"];
const POSITIVE_WORDS = ["좋아요", "유리", "강해", "수월", "챙기", "확인", "정해"];

function sentences(t: string): string[] {
  return t
    .split(/[.!?。]\s*/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function trigrams(t: string): Set<string> {
  const words = t.match(/[가-힣A-Za-z0-9]+/g) ?? [];
  if (words.length < 3) return new Set();
  const grams = new Set<string>();
  for (let i = 0; i < words.length - 2; i++) {
    grams.add(`${words[i]}|${words[i + 1]}|${words[i + 2]}`);
  }
  return grams;
}

export function checkSajuResult(
  result: SajuLlmResult,
  { maxOverlap = 0.15, maxLen = 60 }: { maxOverlap?: number; maxLen?: number } = {}
): string[] {
  const fail: string[] = [];

  const blocks: Record<string, string> = {};
  for (const s of result.sections ?? []) {
    blocks[s.key] = (s.body ?? []).join(" ");
  }
  blocks["headline"] = result.headline ?? "";
  blocks["closing"] = result.closing ?? "";
  blocks["actions"] = (result.actions ?? []).join(" ");

  const full = Object.values(blocks).join(" ");

  // 1) 금지어
  const hits = BANNED.filter((w) => full.includes(w));
  if (hits.length) fail.push(`[금지어] ${hits.join(", ")}`);

  // 2) 확정 단정 표현
  for (const s of sentences(full)) {
    for (const h of HEDGE) {
      if (s.includes(h) && !HEDGE_EXCEPTIONS.some((k) => s.includes(k))) {
        fail.push(`[단정] ${s.slice(0, 40)}`);
      }
    }
  }

  // 3) 블록 간 3-gram 겹침률
  const keys = Object.keys(blocks);
  for (let i = 0; i < keys.length; i++) {
    for (let j = i + 1; j < keys.length; j++) {
      const a = trigrams(blocks[keys[i]]);
      const b = trigrams(blocks[keys[j]]);
      if (a.size === 0 || b.size === 0) continue;
      let inter = 0;
      for (const g of a) if (b.has(g)) inter++;
      const overlap = inter / Math.min(a.size, b.size);
      if (overlap > maxOverlap) {
        fail.push(
          `[중복] ${keys[i]} ↔ ${keys[j]} 겹침 ${(overlap * 100).toFixed(0)}%`
        );
      }
    }
  }

  // 4) 문장 길이
  for (const s of sentences(full)) {
    if (s.length > maxLen) fail.push(`[장문 ${s.length}자] ${s.slice(0, 40)}`);
  }

  // 5) 블록 분량(2~3문장) / 실천 개수(3개)
  for (const s of result.sections ?? []) {
    const n = (s.body ?? []).length;
    if (n < 2 || n > 3) fail.push(`[분량] ${s.key} ${n}문장 (2~3 필요)`);
  }
  if ((result.actions ?? []).length !== 3) {
    fail.push(`[실천] ${(result.actions ?? []).length}개 (3개 필요)`);
  }

  // 6) 상투구 반복
  for (const c of CLICHE) {
    const count = full.split(c).length - 1;
    if (count > 1) fail.push(`[상투구] '${c}' ${count}회`);
  }

  // 7) 부정:긍정 비율(주의 1개당 해법 1.5개 이상)
  const sents = sentences(full);
  const neg = sents.filter((s) => NEGATIVE_WORDS.some((w) => s.includes(w))).length;
  const pos = sents.filter((s) => POSITIVE_WORDS.some((w) => s.includes(w))).length;
  if (neg > 0 && pos / neg < 1.5) {
    fail.push(`[비율] 주의 ${neg} : 해법·긍정 ${pos} — 해법을 늘리세요`);
  }

  // 8) 근거 인용 자기신고
  if (!result.evidence_used || result.evidence_used.length === 0) {
    fail.push("[근거] evidence_used 비어 있음 — 계산값을 실제로 인용하지 않았을 가능성");
  }

  return fail;
}
