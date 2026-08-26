// 감사 도장(GratitudeSeal) 공개 API 공용 헬퍼 — DTO 변환.
//
// [배경] bokjumeoni-plan(01-planning.html §07 "벗의 감사 도장" · 03-dev-spec.html
// §"감사 도장 · Gratitude") — 누군가 내 소원에 복주머니를 보내면(sendPouch =
// `POST /wishes/:id/bokju`), 나는 24시간 이내에 딱 한 번 "감사 도장"을 찍어
// 답례할 수 있다. 찍는 사람(원래 받은 사람) +2복, 받는 사람(원래 보낸 사람) +5복.
//
// [핵심 설계 확정 — schema.prisma 주석 그대로]
//   GratitudeSeal.sourcePouchId = 원래 sendPouch에 해당하는 PointHistory.id
//   (WishBokju.id가 아니다 — PointHistory는 sendPouch 트랜잭션에서 항상 함께
//   생성되고, "누가 보냈는지"(userId)를 이미 정확히 갖고 있어 별도 조회 없이
//   sender/recipient를 역산할 수 있다).
//
// [익명성 원칙] 소원방 전체가 "익명이지만 서로 존재를 확인하는" 세계관이므로
// (01-planning.html §07 "도장은 익명이지만 상대에게 알림으로 도착"), 이 DTO들은
// 상대방의 실제 식별정보(닉네임 등)를 노출하지 않는다 — wishId/금액/시각만 노출.
import type { GratitudeSeal } from "@/generated/prisma/client";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** 감사 도장 답례 허용 시간(시간 단위). sourcePouchId(PointHistory)의 createdAt
 * 기준으로 이 시간이 지나면 seal 시도는 400으로 거부된다(03-dev-spec.html §895). */
export const GRATITUDE_SEAL_WINDOW_HOURS = 24;

export function gratitudeSealExpiresAt(pouchCreatedAt: Date): Date {
  return new Date(pouchCreatedAt.getTime() + GRATITUDE_SEAL_WINDOW_HOURS * 60 * 60 * 1000);
}

export function isGratitudeSealExpired(pouchCreatedAt: Date, now: Date = new Date()): boolean {
  return now.getTime() > gratitudeSealExpiresAt(pouchCreatedAt).getTime();
}

/** GET /gratitude/sealable — 내가 아직 도장을 찍지 않은, 24시간 이내의
 * 받은 sendPouch 후보 하나의 DTO. */
export function toSealableCandidateDto(candidate: {
  sourcePouchId: number;
  wishId: string;
  amount: number;
  pouchCreatedAt: Date;
}) {
  return {
    sourcePouchId: candidate.sourcePouchId,
    wishId: candidate.wishId,
    amount: candidate.amount,
    createdAt: candidate.pouchCreatedAt.toISOString(),
    expiresAt: gratitudeSealExpiresAt(candidate.pouchCreatedAt).toISOString(),
  };
}

/** GET /gratitude/received / POST /gratitude/seal 응답 — 이미 생성된
 * GratitudeSeal 레코드 DTO. grantedAmount는 그 시점에 실제로 지급된 금액
 * (PointHistory 조회로 얻은 값)을 그대로 노출한다(정책이 나중에 바뀌어도
 * 과거 이력은 지급 당시 값을 정확히 보여주기 위함). */
export function toGratitudeSealDto(
  seal: GratitudeSeal,
  publicWishId: string,
  grantedAmount: number
) {
  return {
    id: seal.id,
    wishId: publicWishId,
    sourcePouchId: seal.sourcePouchId,
    amount: grantedAmount,
    createdAt: seal.createdAt.toISOString(),
  };
}
