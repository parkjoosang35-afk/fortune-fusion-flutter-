// 소원성(Wish Castle) 공용 서버 로직 — 촛불 레벨 계산.
// wish_config의 candle_level_{1..4}_threshold 값을 읽어 누적 복주머니(bokjuCount)
// 기준으로 현재 레벨(0~4)을 계산한다. API 라우트 여러 곳(bokju 전송, 댓글 보상 등)에서
// 공통으로 재사용하기 위해 별도 파일로 분리(과설계 방지 — 신규 서비스 클래스 없이
// 순수 함수 하나).
import { prisma } from "@/lib/db";

export const WISH_MAX_LEVEL = 4;

/** wish_config에서 레벨 1~4 임계값을 읽어온다. 없으면 안전한 기본값을 사용한다. */
export async function getCandleLevelThresholds(): Promise<number[]> {
  const rows = await prisma.wishConfig.findMany({
    where: {
      key: {
        in: [
          "candle_level_1_threshold",
          "candle_level_2_threshold",
          "candle_level_3_threshold",
          "candle_level_4_threshold",
        ],
      },
    },
  });
  const map = new Map(rows.map((r) => [r.key, Number(r.value)]));
  return [
    map.get("candle_level_1_threshold") ?? 10,
    map.get("candle_level_2_threshold") ?? 30,
    map.get("candle_level_3_threshold") ?? 70,
    map.get("candle_level_4_threshold") ?? 150,
  ];
}

/** 누적 복주머니 개수로부터 촛불 레벨(0~4)을 계산한다. */
export function computeCandleLevel(bokjuCount: number, thresholds: number[]): number {
  let level = 0;
  for (let i = 0; i < thresholds.length; i++) {
    if (bokjuCount >= thresholds[i]) level = i + 1;
  }
  return Math.min(level, WISH_MAX_LEVEL);
}

/** 특정 소원의 wish_config 문자열 값을 가져온다(단건). 없으면 fallback 반환. */
export async function getWishConfigValue(key: string, fallback: string): Promise<string> {
  const row = await prisma.wishConfig.findUnique({ where: { key } });
  return row?.value ?? fallback;
}

// [재화 구조 정리 - 재연결] 글 강조(highlight)/노출 강화(expose_boost) 지속시간.
// 소비 "금액"은 luck-pouch-rules(관리자 조정 가능)를 따르지만, 지속시간은 재화 값이
// 아니라 기능 동작 파라미터이므로 여기서는 고정 상수로 둔다(과설계 방지).
export const HIGHLIGHT_DURATION_HOURS = 24;
export const EXPOSE_BOOST_DURATION_HOURS = 24;

/** 글 강조가 현재 시점 기준으로 아직 유효한지 여부. */
export function isHighlightActive(highlightedUntil: Date | null, now: Date = new Date()): boolean {
  return !!highlightedUntil && highlightedUntil.getTime() > now.getTime();
}

/** 노출 강화가 현재 시점 기준으로 아직 유효한지 여부(적용 후 EXPOSE_BOOST_DURATION_HOURS 이내). */
export function isBoostActive(boostedAt: Date | null, now: Date = new Date()): boolean {
  if (!boostedAt) return false;
  return now.getTime() - boostedAt.getTime() < EXPOSE_BOOST_DURATION_HOURS * 60 * 60 * 1000;
}
