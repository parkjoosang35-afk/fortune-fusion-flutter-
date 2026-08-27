// 귀인지도 멤버 추가(+즉시 관계 판정) API — Flutter GuinjiRepository.join() 대응.
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6-3] `POST /guinji/maps/{mapId}/members`.
//
// [흐름] S9(지인 참여) 딥링크 진입 화면에서, 이미 초대 토큰으로 mapId를
// 알고 있는 지인(guest, 로그인 필요)이 자신의 생년월일 정보를 제출하면:
//   1) map_member 레코드 생성(joinedUserId=guest 본인)
//   2) RelationJudger로 owner↔guest 관계 즉시 계산 → relationship 캐시 저장
//   3) PointPolicy 'guinji_join'(+20P, 참여 1명당) 소유자에게 지급
//      (S8 확정 문구 "1명 참여 = 복주머니 20P")
// 전부 하나의 $transaction 안에서 처리한다(luckybag/open route.ts 패턴).
//
// [요청] { name, solarLunar('solar'|'lunar'), birthDate('YYYY-MM-DD'),
//   birthTime?('HH:mm'), saju: GuinjiSajuInput }
// saju는 guest 본인의 사주 계산 결과(B안 — 클라이언트 산출값 그대로 신뢰).
//
// [에러 매핑] MAP_NOT_FOUND(404) / OWNER_SELF_JOIN(400, 본인 지도에는 참여
// 불가) / DUPLICATE_JOIN(409, S9 "중복 참여 → E3") / INVALID_SAJU(400).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  parseGuinjiMapDbId,
  requireUser,
  toGuinjiMemberPublicId,
  unauthorizedResponse,
} from "../../../_shared";
import { GuinjiSajuInput, isValidGuinjiSajuInput, judgeGuinjiRelation } from "@/lib/guinji-relation-judger";

export const dynamic = "force-dynamic";

interface RequestBody {
  name?: string;
  solarLunar?: string;
  birthDate?: string;
  birthTime?: string | null;
  saju?: unknown;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ mapId: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { mapId: mapIdParam } = await params;
  const mapDbId = parseGuinjiMapDbId(mapIdParam);
  if (mapDbId === null) {
    return NextResponse.json(
      { success: false, error: "mapId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: RequestBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const name = body.name?.trim();
  const solarLunar = body.solarLunar === "lunar" ? "lunar" : "solar";
  const birthDate = body.birthDate?.trim();
  const birthTime = body.birthTime?.trim() || null;

  if (!name || !birthDate || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
    return NextResponse.json(
      { success: false, error: "name/birthDate가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!isValidGuinjiSajuInput(body.saju)) {
    return NextResponse.json(
      { success: false, error: "saju(사주 계산 결과)가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const guestSaju: GuinjiSajuInput = body.saju;

  try {
    const outcome = await prisma.$transaction(async (tx) => {
      const map = await tx.guinjiMap.findUnique({ where: { id: mapDbId } });
      if (!map || map.deletedAt != null || map.status !== "active") {
        throw new Error("MAP_NOT_FOUND");
      }
      if (map.ownerId === auth.userId) {
        throw new Error("OWNER_SELF_JOIN");
      }
      if (!map.ownerSajuParsed) {
        // 이론상 발생 불가(POST /guinji/maps 생성 시 항상 저장) — 방어적 처리.
        throw new Error("OWNER_SAJU_MISSING");
      }

      // 중복 참여 방지(S9 에러 연동 "중복 참여 → E3") — 동일 지도에 동일
      // 회원이 이미 활성 멤버로 존재하면 재참여를 막는다.
      const existingMember = await tx.guinjiMapMember.findFirst({
        where: { mapId: map.id, joinedUserId: auth.userId, status: "active" },
      });
      if (existingMember) {
        throw new Error("DUPLICATE_JOIN");
      }

      const ownerSaju = JSON.parse(map.ownerSajuParsed) as GuinjiSajuInput;
      const judged = judgeGuinjiRelation(ownerSaju, guestSaju);

      const member = await tx.guinjiMapMember.create({
        data: {
          mapId: map.id,
          joinedUserId: auth.userId,
          name,
          solarLunar,
          birthDate,
          birthTime,
          birthTimeMissing: birthTime == null,
          sajuParsed: JSON.stringify(guestSaju),
        },
      });

      const relationship = await tx.guinjiRelationship.create({
        data: {
          mapId: map.id,
          ownerId: map.ownerId,
          memberId: member.id,
          relationType: judged.relationType,
          chemistryScore: judged.chemistryScore,
          ohaengEvidence: JSON.stringify(judged.ohaengEvidence),
        },
      });

      // [PointPolicy guinji_join] 참여 1명당 지도 소유자에게 포인트 지급.
      // 멱등키: sourceType='guinji_join' + sourceId=member.id(신규 생성된
      // 멤버 id는 재사용될 수 없으므로 자연히 1회만 지급됨).
      const policy = await tx.pointPolicy.findUnique({ where: { sourceType: "guinji_join" } });
      const rewardPoint = policy?.isActive ? policy.amount : 0;
      let ownerBalanceAfter: number | null = null;
      if (rewardPoint > 0) {
        let ownerWallet = await tx.wallet.findFirst({
          where: { userId: map.ownerId, currencyType: "POINT", deletedAt: null },
        });
        if (!ownerWallet) {
          ownerWallet = await tx.wallet.create({
            data: { userId: map.ownerId, currencyType: "POINT", balance: 0 },
          });
        }
        ownerBalanceAfter = ownerWallet.balance + rewardPoint;
        await tx.wallet.update({
          where: { id: ownerWallet.id },
          data: { balance: ownerBalanceAfter, balanceSyncedAt: new Date() },
        });
        await tx.pointHistory.create({
          data: {
            walletId: ownerWallet.id,
            userId: map.ownerId,
            amount: rewardPoint,
            type: "earn",
            sourceType: "guinji_join",
            sourceId: member.id,
            balanceAfter: ownerBalanceAfter,
            memo: `귀인지도 참여 (${name})`,
          },
        });
      }

      return { member, relationship, rewardPoint, ownerBalanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          memberId: toGuinjiMemberPublicId(outcome.member.id),
          relationship: {
            relationType: outcome.relationship.relationType,
            chemistryScore: outcome.relationship.chemistryScore,
            ohaengEvidence: JSON.parse(outcome.relationship.ohaengEvidence),
          },
        },
      },
      { status: 201, headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    const errorMap: Record<string, { status: number; error: string }> = {
      MAP_NOT_FOUND: { status: 404, error: "지도를 찾을 수 없어요." },
      OWNER_SELF_JOIN: { status: 400, error: "내 지도에는 참여할 수 없어요." },
      OWNER_SAJU_MISSING: { status: 500, error: "지도 소유자 사주 정보가 없어요." },
      DUPLICATE_JOIN: { status: 409, error: "이미 참여한 지도예요." },
    };
    const mapped = errorMap[message];
    if (mapped) {
      return NextResponse.json(
        { success: false, error: mapped.error },
        { status: mapped.status, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/guinji/maps/[mapId]/members] 실패:", e);
    return NextResponse.json(
      { success: false, error: "참여 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
