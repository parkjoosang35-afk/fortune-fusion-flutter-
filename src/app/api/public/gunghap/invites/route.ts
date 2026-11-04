// 궁합지도(Gunghap Map) 초대 생성 API.
// [신통방통 궁합지도 개발 지시서 §1 "초대 생성", 개발 승인(API 단계) §2]
//
// [요청] { ownerName?: string, saju: GuinjiSajuInput }
//   - saju는 초대자(owner) 본인의 사주 계산 결과(귀인지도와 동일하게
//     클라이언트 ManseryeokCoreEngine이 이미 계산한 값을 그대로 신뢰 —
//     "B안" 아키텍처, 서버가 재계산하지 않음). 형식은 GuinjiSajuInput
//     (한자 기반, 기존 계약 재사용)을 그대로 쓴다 — 신규 포맷을 만들지
//     않는다.
//
// [절대 원칙 — 초대자는 본인 사주만 등록] 이 엔드포인트는 상대방(게스트)의
// 어떤 정보도 입력받지 않는다. body에 상대방 생년월일 필드 자체가 없다
// (요청 스키마 참고) — "초대 발송자가 상대방의 생년월일을 미리 알고 있어야
// 하는 구조로 만들지 마세요" 원칙을 API 계약 수준에서부터 강제한다.
//
// [토큰 추측 불가능] `generateGunghapToken()`(crypto.randomBytes 기반
// CSPRNG, 귀인지도와 동일 방식)으로 발급한다.
//
// [1인 다중 초대 허용] 귀인지도(`GuinjiMap.@@unique([ownerId])`, 소유자당
// 1개)와 달리, `GunghapInvite`에는 ownerId unique 제약이 없다 — "한 명이
// 여러 궁합 초대를 만들 수 있도록 한다"(승인 문서) 요구사항을 스키마
// 설계 단계부터 반영했다(사전 검수 보고서 항목 1 참고). 매 요청마다 새
// 초대를 생성한다(귀인지도처럼 기존 레코드를 재사용하지 않음).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { isValidGuinjiSajuInput } from "@/lib/guinji-relation-judger";
import { GUNGHAP_CATEGORY_ORDER } from "@/lib/gunghap/gunghap-category-rules";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  generateGunghapToken,
  requireUser,
  unauthorizedResponse,
} from "../_shared";

export const dynamic = "force-dynamic";

// [2026-11 궁합 주제 반영 지시서 — Section 3] 미응답 초대 링크 만료기간.
// 승인 문서 확정값: 7일. 완료된(결과가 생성된) 초대는 만료 판정을 받지
// 않는다(g/[token]/route.ts에서 "invite.result != null"을 expiresAt
// 체크보다 항상 먼저 확인) — 이 상수는 "미응답" 상태의 링크에만 적용된다.
const INVITE_EXPIRY_DAYS = 7;

interface RequestBody {
  ownerName?: string;
  saju?: unknown;
  majorId?: string;
  subName?: string;
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
      { status: 400, headers: CORS_HEADERS },
    );
  }

  if (!isValidGuinjiSajuInput(body.saju)) {
    return NextResponse.json(
      { success: false, error: "saju(사주 계산 결과)가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const ownerName = body.ownerName?.trim();
  if (ownerName && ownerName.length > 20) {
    return NextResponse.json(
      { success: false, error: "이름은 20자 이내로 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  // [2026-11 궁합 주제 반영 지시서 — Section 1] 사용자가 고른 궁합 분야.
  // 선택사항(미지정 시 레거시와 동일하게 8분야 전체 노출) — 다만 값이
  // 왔다면 반드시 8개 고정 분야 중 하나여야 한다(임의 문자열 저장 방지).
  const majorId = body.majorId?.trim();
  if (majorId && !GUNGHAP_CATEGORY_ORDER.includes(majorId as (typeof GUNGHAP_CATEGORY_ORDER)[number])) {
    return NextResponse.json(
      { success: false, error: "majorId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }
  const subName = body.subName?.trim();
  if (subName && subName.length > 40) {
    return NextResponse.json(
      { success: false, error: "subName은 40자 이내여야 합니다." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  try {
    // 토큰 충돌(사실상 발생하지 않지만 unique 제약 방어적 재시도) — 귀인지도
    // maps/route.ts와 동일 패턴.
    let created: { id: number; token: string; expiresAt: Date | null } | null = null;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + INVITE_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
    for (let attempt = 0; attempt < 3 && !created; attempt++) {
      const token = generateGunghapToken();
      try {
        created = await prisma.gunghapInvite.create({
          data: {
            ownerId: auth.userId,
            token,
            ownerName: ownerName || null,
            ownerSajuParsed: JSON.stringify(body.saju),
            majorId: majorId || null,
            subName: subName || null,
            tokenIssuedAt: now,
            expiresAt,
          },
          select: { id: true, token: true, expiresAt: true },
        });
      } catch (e) {
        const code = (e as { code?: string }).code;
        if (code !== "P2002") throw e;
        // token 충돌(사실상 발생하지 않음) — 재시도.
      }
    }
    if (!created) {
      throw new Error("TOKEN_GENERATION_FAILED");
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          inviteId: created.id,
          token: created.token,
          // 클라이언트가 바로 공유 링크를 조립할 수 있도록 경로 접두사를
          // 함께 내려준다(baseUrl은 클라이언트/운영 설정에 따라 다르므로
          // 여기서는 상대 경로만 제공).
          sharePath: `/gh/${created.token}`,
          expiresAt: created.expiresAt ? created.expiresAt.toISOString() : null,
        },
      },
      { status: 201, headers: CORS_HEADERS },
    );
  } catch (e) {
    console.error("[POST /api/public/gunghap/invites] 실패:", e);
    return NextResponse.json(
      { success: false, error: "초대 생성 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS },
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
