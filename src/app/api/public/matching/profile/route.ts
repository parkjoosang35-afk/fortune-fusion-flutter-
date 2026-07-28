// 공개(비인증) 매칭 프로필(M-1) 등록/조회 API — MatchingRepository.saveProfile()/getMyProfile() 대응.
//
// [설계결정 - preferences 구조] Flutter는 preferences를 취향태그 문자열 배열로 다룬다.
// DB matching_profiles.preferences는 JSON 문자열 컬럼(SQLite 네이티브 JSONB 없음)이라
// 애플리케이션 레벨에서 JSON.stringify/parse한다. 초기 시딩 데이터 중 일부는
// {ageRange,gender,region} 같은 이상형 조건 객체 형태로 들어있었으나, 이는 레거시
// 시드 샘플일 뿐 스키마 제약은 아니므로, 이번 회원 앱 연동부터는 태그 배열 형태로
// 통일해서 저장한다. 조회 시 배열이 아닌 값(레거시 객체 등)을 만나면 빈 배열로 안전하게
// 폴백해 화면이 깨지지 않도록 한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parsePreferences(raw: string | null): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      return parsed.filter((x) => typeof x === "string");
    }
    return [];
  } catch {
    return [];
  }
}

function toProfileDto(p: {
  userId: number;
  isPublic: boolean;
  introText: string | null;
  preferences: string | null;
}) {
  return {
    userId: String(p.userId),
    isPublic: p.isPublic,
    introText: p.introText ?? "",
    preferences: parsePreferences(p.preferences),
  };
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const profile = await prisma.matchingProfile.findUnique({
      where: { userId },
    });
    if (!profile || profile.deletedAt) {
      return NextResponse.json({ success: true, data: null }, { headers: CORS_HEADERS });
    }
    return NextResponse.json(
      { success: true, data: toProfileDto(profile) },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/matching/profile] 실패:", e);
    return NextResponse.json(
      { success: false, error: "프로필을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    isPublic?: boolean;
    introText?: string;
    preferences?: string[];
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const isPublic = body.isPublic ?? true;
  const introText = (body.introText ?? "").trim();
  const preferences = Array.isArray(body.preferences) ? body.preferences : [];

  try {
    const saved = await prisma.matchingProfile.upsert({
      where: { userId },
      update: {
        isPublic,
        introText,
        preferences: JSON.stringify(preferences),
        status: "active",
        deletedAt: null,
      },
      create: {
        userId,
        isPublic,
        introText,
        preferences: JSON.stringify(preferences),
      },
    });
    return NextResponse.json(
      { success: true, data: toProfileDto(saved) },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/matching/profile] 실패:", e);
    return NextResponse.json(
      { success: false, error: "프로필 저장에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
