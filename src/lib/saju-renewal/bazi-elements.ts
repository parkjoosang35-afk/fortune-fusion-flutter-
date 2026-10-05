// [정통사주 리뉴얼 v1.0] 간지(干支) ↔ 오행 매핑 + 육십간지 보조 테이블.
//
// saju_engine(`/saju/v3/facts`)은 이미 각 주(柱)의 `element`(예: "금-토" = 간오행-지오행)를
// 계산해서 내려주지만, `luck_pillars[].gan_zhi_kr`(예: "경진")처럼 "한글 2글자" 형태로만
// 오는 필드는 오행 정보가 별도로 없다. topic-evidence.ts가 "후반 대운에 용신 오행이
// 등장하는가" 같은 조건을 판정하려면 이 한글 간지 문자열에서 오행을 역으로 구해야 하므로,
// 이 매핑 테이블을 둔다(계산 엔진 재계산이 아니라, 이미 계산된 결과를 단순 문자 매핑으로
// 재해석하는 것뿐이므로 "LLM이 사주를 계산한다"는 금지 원칙과 무관하다).
export const GAN_ELEMENT: Record<string, string> = {
  갑: "목",
  을: "목",
  병: "화",
  정: "화",
  무: "토",
  기: "토",
  경: "금",
  신: "금",
  임: "수",
  계: "수",
};

export const ZHI_ELEMENT: Record<string, string> = {
  자: "수",
  축: "토",
  인: "목",
  묘: "목",
  진: "토",
  사: "화",
  오: "화",
  미: "토",
  신: "금",
  유: "금",
  술: "토",
  해: "수",
};

/** 충(沖) 관계 지지 쌍 — "대운 지지 충"(LIFE_001) 판정에 사용. */
export const CHONG_PAIRS: [string, string][] = [
  ["자", "오"],
  ["축", "미"],
  ["인", "신"],
  ["묘", "유"],
  ["진", "술"],
  ["사", "해"],
];

export function isChongPair(zhiA: string | undefined, zhiB: string | undefined): boolean {
  if (!zhiA || !zhiB) return false;
  return CHONG_PAIRS.some(
    ([a, b]) => (a === zhiA && b === zhiB) || (a === zhiB && b === zhiA)
  );
}

/** "경진" 같은 한글 간지 2글자 문자열에서 [간오행, 지오행]을 반환한다. 형식이 아니면 null. */
export function splitGanZhiKr(ganZhiKr: string | undefined | null): { gan: string; zhi: string; ganElement: string; zhiElement: string } | null {
  if (!ganZhiKr || ganZhiKr.length < 2) return null;
  const gan = ganZhiKr[0];
  const zhi = ganZhiKr[1];
  const ganElement = GAN_ELEMENT[gan];
  const zhiElement = ZHI_ELEMENT[zhi];
  if (!ganElement || !zhiElement) return null;
  return { gan, zhi, ganElement, zhiElement };
}

/** pillars.*.element 필드("금-토")에서 [간오행, 지오행]을 분리한다. */
export function splitPillarElement(element: string | undefined): { ganElement: string; zhiElement: string } | null {
  if (!element) return null;
  const parts = element.split("-");
  if (parts.length !== 2) return null;
  return { ganElement: parts[0], zhiElement: parts[1] };
}

/** 십신(十神) 그룹 — 재성/비겁/식상/관성/인성 5그룹. ten_gods 응답 값(한글 명칭)과 매칭한다. */
export const TEN_GOD_GROUPS: Record<string, string[]> = {
  비겁: ["비견", "겁재"],
  식상: ["식신", "상관"],
  재성: ["편재", "정재"],
  관성: ["편관", "정관"],
  인성: ["편인", "정인"],
};

/** ten_gods 객체의 7개 슬롯(연간/월간/시간/연지/월지/일지/시지, 일간=일주 본인이라 제외) 값 전체. */
export function listTenGodSlots(tenGods: Record<string, string | undefined> | undefined): string[] {
  if (!tenGods) return [];
  return Object.values(tenGods).filter((v): v is string => typeof v === "string" && v.length > 0);
}

/** 특정 십신 그룹(예: 재성=[편재,정재])에 속하는 슬롯 개수와 비율을 계산한다. */
export function countTenGodGroup(
  tenGods: Record<string, string | undefined> | undefined,
  groupNames: string[]
): { count: number; total: number; ratio: number } {
  const slots = listTenGodSlots(tenGods);
  const total = slots.length;
  const count = slots.filter((s) => groupNames.includes(s)).length;
  return { count, total, ratio: total > 0 ? count / total : 0 };
}

// ════════════════════════════════════════════════════════════════
// 오행 상생상극(五行 相生相剋) — 일간(day_master) 기준 십신 오행 역산
// ════════════════════════════════════════════════════════════════
// [용도] saju_engine의 `ten_gods`는 "연간/월간/시간/연지/월지/일지/시지" 7슬롯의 십신
// 명칭만 주지만, `luck_pillars`/`current_luck`(대운)·용신(yongshin) 등은 "오행"
// 단위로만 내려온다. "대운에 재성이 들어온다"(MONEY_004) 같은 조건을 판정하려면
// 일간 오행 기준으로 "재성에 해당하는 오행이 무엇인지"를 역산해야 한다. 이는 사주를
// 새로 계산하는 것이 아니라, 이미 계산된 day_master.element 하나만으로 결정되는
// 고정 공식(상생상극)을 적용하는 것 — LLM이 아니라 여기 코드가 결정론적으로 수행한다.
//
// 상생(生) 순환: 목→화→토→금→수→목
// 상극(剋) 순환: 목→토→토→수→수→화→화→금→금→목 (목克土·土克水·水克火·火克金·金克木)
export const WX_GENERATES: Record<string, string> = {
  목: "화",
  화: "토",
  토: "금",
  금: "수",
  수: "목",
};

export const WX_CONTROLS: Record<string, string> = {
  목: "토",
  토: "수",
  수: "화",
  화: "금",
  금: "목",
};

function invert(map: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(map)) out[v] = k;
  return out;
}

/** 나를 생(生)해주는 오행(= 인성의 오행). */
export const WX_GENERATED_BY: Record<string, string> = invert(WX_GENERATES);
/** 나를 극(剋)하는 오행(= 관성의 오행). */
export const WX_CONTROLLED_BY: Record<string, string> = invert(WX_CONTROLS);

/** 일간 오행 기준 5개 십신 그룹에 대응하는 "상대 오행"을 반환한다. */
export function resolveTenGodElements(dayMasterElement: string | undefined): {
  비겁: string | undefined; // 나와 같은 오행
  식상: string | undefined; // 내가 생하는 오행
  재성: string | undefined; // 내가 극하는 오행
  관성: string | undefined; // 나를 극하는 오행
  인성: string | undefined; // 나를 생하는 오행
} {
  if (!dayMasterElement) {
    return { 비겁: undefined, 식상: undefined, 재성: undefined, 관성: undefined, 인성: undefined };
  }
  return {
    비겁: dayMasterElement,
    식상: WX_GENERATES[dayMasterElement],
    재성: WX_CONTROLS[dayMasterElement],
    관성: WX_CONTROLLED_BY[dayMasterElement],
    인성: WX_GENERATED_BY[dayMasterElement],
  };
}
