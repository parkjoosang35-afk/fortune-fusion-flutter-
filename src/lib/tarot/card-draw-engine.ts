// [신통방통 타로 65종 주제 연동 - Card Draw Engine]
//
// 78장 전체 덱(tarot_cards) 기준으로 카드를 추첨한다. 원 지시서 핵심 요구사항:
//   - 78장 전체 덱 기준 카드 추첨 (레거시 15장 DECK 사용 안 함)
//   - 리딩 내 카드 중복 금지
//   - 카드추첨은 서버 기준(클라이언트 임의생성 금지) — 이 파일이 유일한 추첨 로직
//   - AI Narrative Engine과 완전히 분리 — 이 엔진이 반환한 카드는 이후 절대 불변
//
// [결정론적 시드] 기존 레거시 로직과 동일하게 "질문 문자열 해시"를 시드로 사용해
// 같은 질문+카드수 조합이면 같은 결과가 나온다(순수 확률 게임 로직, LLM 연동
// 대상 아님 — route.ts 상단 주석과 동일한 설계 원칙).
import { prisma } from "@/lib/db";

export interface DrawnCard {
  id: string;
  name: string;
  nameKr: string;
  isReversed: boolean;
  /** 이번 리딩에서의 방향(정/역)에 대응하는 해석 텍스트. */
  meaning: string;
  /** 방향과 무관한 카드 고유 기본의미(AI 프롬프트 전달용). */
  basicMeaning: string;
  arcanaType: string;
  suit: string | null;
}

function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) {
    h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  }
  return Math.abs(h);
}

/**
 * 78장 tarot_cards 테이블 기준으로 `count`장을 중복 없이 추첨한다.
 * 결정론적(질문 해시 시드) — 같은 question+count면 항상 같은 카드 조합이 나온다.
 * 카드별 정/역방향도 시드 기반으로 결정되며, 반환된 이후 이 값은 호출부에서
 * 절대 변경되어서는 안 된다(어뷰징 방지 - 확정된 카드 불변 원칙).
 */
export async function drawFromFullDeck(
  question: string,
  count: number
): Promise<DrawnCard[]> {
  const deck = await prisma.tarotCard.findMany({
    where: { status: "active", deletedAt: null },
    orderBy: { sortOrder: "asc" },
    select: {
      id: true,
      name: true,
      nameKr: true,
      uprightMeaning: true,
      reversedMeaning: true,
      basicMeaning: true,
      arcanaType: true,
      suit: true,
    },
  });

  if (deck.length === 0) {
    throw new Error("TAROT_DECK_EMPTY");
  }
  if (count > deck.length) {
    throw new Error("TAROT_DRAW_COUNT_EXCEEDS_DECK");
  }

  const seed = hashSeed(question);
  const indices: number[] = [];
  let cursor = seed;
  let guard = 0;
  while (indices.length < count && guard < deck.length * 50) {
    cursor = (cursor * 1103515245 + 12345) & 0x7fffffff;
    const idx = cursor % deck.length;
    if (!indices.includes(idx)) indices.push(idx);
    guard++;
  }
  // 극히 드문 충돌 회피 실패 시 순차 채움(여전히 중복 없음 보장).
  if (indices.length < count) {
    for (let i = 0; i < deck.length && indices.length < count; i++) {
      if (!indices.includes(i)) indices.push(i);
    }
  }

  return indices.map((idx, i) => {
    const card = deck[idx];
    const reversed = (seed + idx + i) % 3 === 0;
    return {
      id: `card_${card.id}_${i}`,
      name: card.name,
      nameKr: card.nameKr,
      isReversed: reversed,
      meaning: reversed ? card.reversedMeaning : card.uprightMeaning,
      basicMeaning: card.basicMeaning,
      arcanaType: card.arcanaType,
      suit: card.suit,
    };
  });
}
