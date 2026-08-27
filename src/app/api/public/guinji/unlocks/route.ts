// 귀인지도 스페셜 해설 해금 API — Flutter RelationDetailScreen(S6) 잠금 카드 대응.
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6-5] `POST /guinji/unlocks`.
//
// [흐름] S6 "이 관계, 어떻게 대해야 할까" 잠금 카드에서 지도 소유자(owner)가
// 특정 멤버의 스페셜 해설을 해금한다. 해금 경로는 2가지:
//   - method="ad"  : 리워드 광고 1회 시청 완료 → 해금 (포인트 차감 없음)
//   - method="point": 복주머니 50P 차감 → 해금 (PointPolicy 'guinji_unlock_special')
// [M12] 멱등: unlock_record.@@unique([userId, memberId])로 "멤버당 1회만 해금"을
//   구조적으로 보장 — 이미 해금된 멤버 재요청은 에러가 아니라 unlocked:true를
//   그대로 반환한다(중복 과금/중복 광고 방지).
// [일 5회 한도] PointPolicy('guinji_unlock_special').dailyLimit(=5)을 기준으로
//   오늘(KST) 신규 해금 건수를 카운트해 초과 시 429.
//
// [권한] 스페셜 해설은 "내 지도"의 관계를 보는 기능(S6는 owner 전용 화면)이므로
// member.map.ownerId === 요청자여야 한다(타인 지도 멤버 해금 시도는 FORBIDDEN).
//
// [요청] {memberId: "m_xxx", method: "ad"|"point"}
// [응답] {unlocked: true, remainingToday: number}
// [에러 매핑] MEMBER_NOT_FOUND(404) / FORBIDDEN(403) / LIMIT_REACHED(429)
//   / INSUFFICIENT_BALANCE(400, point 방식 잔액 부족)
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGuinjiMemberDbId,
  requireUser,
  todayKstDateKey,
  unauthorizedResponse,
} from "../_shared";

export const dynamic = "force-dynamic";

const DEFAULT_UNLOCK_AMOUNT = 50;
const DEFAULT_DAILY_LIMIT = 5;

interface RequestBody {
  memberId?: string;
  method?: string;
}

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: RequestBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const memberDbId = body.memberId ? parseGuinjiMemberDbId(body.memberId) : null;
  const method = body.method === "point" ? "point" : body.method === "ad" ? "ad" : null;

  if (memberDbId === null || method === null) {
    return NextResponse.json(
      { success: false, error: "memberId/method가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const outcome = await prisma.$transaction(async (tx) => {
      const member = await tx.guinjiMapMember.findUnique({
        where: { id: memberDbId },
        include: { map: true },
      });
      if (!member || member.deletedAt != null || member.status !== "active") {
        throw new Error("MEMBER_NOT_FOUND");
      }
      if (member.map.ownerId !== auth.userId) {
        throw new Error("FORBIDDEN");
      }

      const policy = await tx.pointPolicy.findUnique({
        where: { sourceType: "guinji_unlock_special" },
      });
      const dailyLimit = policy?.dailyLimit ?? DEFAULT_DAILY_LIMIT;
      const unlockAmount = policy?.isActive === false ? 0 : policy?.amount ?? DEFAULT_UNLOCK_AMOUNT;

      // [M12 멱등] 이미 이 멤버를 해금했다면 재과금/재광고 없이 그대로 unlocked 반환.
      const existing = await tx.guinjiUnlockRecord.findUnique({
        where: { userId_memberId: { userId: auth.userId, memberId: member.id } },
      });
      if (existing) {
        const dateKey = todayKstDateKey();
        const todayCount = await tx.guinjiUnlockRecord.count({
          where: { userId: auth.userId, dateKey },
        });
        return { alreadyUnlocked: true, remainingToday: Math.max(0, dailyLimit - todayCount) };
      }

      // [일 5회 한도] 오늘(KST) 신규 해금 건수가 이미 한도에 도달했으면 거부.
      const dateKey = todayKstDateKey();
      const todayCount = await tx.guinjiUnlockRecord.count({
        where: { userId: auth.userId, dateKey },
      });
      if (todayCount >= dailyLimit) {
        throw new Error("LIMIT_REACHED");
      }

      // method="point"인 경우에만 복주머니를 차감한다. method="ad"는 클라이언트가
      // 리워드 광고 시청 완료 콜백을 마친 뒤 이 API를 호출한다고 신뢰한다(광고 SDK
      // 서버측 콜백 검증 자체는 이번 Phase 범위 밖 — fortune_ad_watch_logs 패턴과
      // 동일 수준의 세션 검증은 후속 Phase 과제로 남긴다).
      if (method === "point" && unlockAmount > 0) {
        const spendResult = await spendLuckPouch(tx, {
          userId: auth.userId,
          amount: unlockAmount,
          sourceType: "guinji_unlock_special",
          sourceId: member.id,
          memo: `귀인지도 스페셜 해설 해금 (${member.name})`,
        });
        if (!spendResult.ok) {
          throw new Error("INSUFFICIENT_BALANCE");
        }
      }

      await tx.guinjiUnlockRecord.create({
        data: {
          userId: auth.userId,
          memberId: member.id,
          dateKey,
          method,
        },
      });

      return { alreadyUnlocked: false, remainingToday: Math.max(0, dailyLimit - (todayCount + 1)) };
    });

    return NextResponse.json(
      { success: true, data: { unlocked: true, remainingToday: outcome.remainingToday } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    const errorMap: Record<string, { status: number; error: string }> = {
      MEMBER_NOT_FOUND: { status: 404, error: "멤버를 찾을 수 없어요." },
      FORBIDDEN: { status: 403, error: "내 지도의 관계만 해금할 수 있어요." },
      LIMIT_REACHED: { status: 429, error: "오늘의 해금 횟수를 모두 사용했어요." },
      INSUFFICIENT_BALANCE: { status: 400, error: "복주머니가 부족해요." },
    };
    const mapped = errorMap[message];
    if (mapped) {
      return NextResponse.json(
        { success: false, error: mapped.error, code: message },
        { status: mapped.status, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/guinji/unlocks] 실패:", e);
    return NextResponse.json(
      { success: false, error: "해금 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
