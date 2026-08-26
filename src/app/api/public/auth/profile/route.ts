// 프로필 수정 API — AuthRepository.updateProfile() 대응.
// ProfileCheckScreen(최초 1회) 및 마이페이지 수정에서 사용. user_profiles는 userId 1:1이므로
// upsert로 처리한다. gender는 users 테이블 컬럼이라 별도로 업데이트한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { authenticateRequest, toUserDto } from "@/lib/user-auth";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function PATCH(request: NextRequest) {
  const payload = await authenticateRequest(request);
  if (!payload) {
    return NextResponse.json(
      { success: false, error: "인증이 필요합니다.", code: "UNAUTHORIZED" },
      { status: 401, headers: CORS_HEADERS }
    );
  }

  let body: {
    nickname?: string;
    birth_date?: string | null;
    birth_time?: string | null;
    is_lunar?: boolean;
    gender?: string | null;
    // [신통방통 2단계 - 회원/운세 프로필 통합]
    // is_leap_month: 음력 선택 시에만 의미 있음(양력이면 false로 취급, 계산엔진 미변경).
    // birth_time_unknown: 계산에는 영향 없음(관례값 12:00 그대로 사용), 결과 화면 안내 문구 노출용으로만 저장.
    is_leap_month?: boolean;
    birth_time_unknown?: boolean;
    birth_place?: string | null;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const existing = await prisma.user.findUnique({ where: { id: payload.userId } });
    if (!existing || existing.status !== "active") {
      return NextResponse.json(
        { success: false, error: "유효하지 않은 계정입니다." },
        { status: 401, headers: CORS_HEADERS }
      );
    }

    if (body.nickname && body.nickname.trim() && body.nickname.trim() !== existing.nickname) {
      const dup = await prisma.user.findUnique({ where: { nickname: body.nickname.trim() } });
      if (dup && dup.id !== payload.userId) {
        return NextResponse.json(
          { success: false, error: "이미 사용 중인 닉네임입니다.", code: "DUPLICATE" },
          { status: 409, headers: CORS_HEADERS }
        );
      }
    }

    const updated = await prisma.user.update({
      where: { id: payload.userId },
      data: {
        ...(body.nickname && body.nickname.trim() ? { nickname: body.nickname.trim() } : {}),
        ...(body.gender !== undefined ? { gender: body.gender } : {}),
        profile: {
          upsert: {
            create: {
              birthDate: body.birth_date ?? null,
              birthTime: body.birth_time ?? null,
              isLunar: body.is_lunar ?? false,
              isLeapMonth: body.is_leap_month ?? false,
              birthTimeUnknown: body.birth_time_unknown ?? false,
              birthPlace: body.birth_place ?? null,
            },
            update: {
              ...(body.birth_date !== undefined ? { birthDate: body.birth_date } : {}),
              ...(body.birth_time !== undefined ? { birthTime: body.birth_time } : {}),
              ...(body.is_lunar !== undefined ? { isLunar: body.is_lunar } : {}),
              ...(body.is_leap_month !== undefined ? { isLeapMonth: body.is_leap_month } : {}),
              ...(body.birth_time_unknown !== undefined
                ? { birthTimeUnknown: body.birth_time_unknown }
                : {}),
              ...(body.birth_place !== undefined ? { birthPlace: body.birth_place } : {}),
            },
          },
        },
      },
      include: { grade: true, profile: true },
    });

    return NextResponse.json(
      { success: true, data: { user: toUserDto(updated) } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[PATCH /api/public/auth/profile] 실패:", e);
    return NextResponse.json(
      { success: false, error: "프로필 수정 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "PATCH, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
