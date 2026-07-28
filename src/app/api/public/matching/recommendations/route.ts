// 공개(비인증) 매칭 추천 대상 목록 — MatchingRepository.getRecommendations() 대응.
//
// [범위] matching_profiles.isPublic=true & status=active 인 다른 유저 중,
// - 내가 이미 좋아요를 보낸 대상(matching_likes.fromUserId=me, active)
// - 이미 매칭 성사된 대상(matching_pairs status=active, 나와 연관)
// 을 제외하고 반환한다.
//
// [설계결정 - age 필드] UserProfile.birthDate가 현재 전부 null로 시딩되어 있어
// 나이를 계산할 수 없다. 회원가입 정공법 구축(로드맵④) 전까지는 결정론적 임시값
// `22 + (userId % 15)`(22~36세 범위)를 사용해 화면이 매번 다른 나이를 보여주는
// 어색함을 방지한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const EMOJIS = ["🌙", "⭐", "🌿", "☕", "✈️", "🌸", "🍀", "🎈", "🌊", "🔥"];

function pickEmoji(userId: number): string {
  return EMOJIS[userId % EMOJIS.length];
}

function fallbackAge(userId: number): number {
  return 22 + (userId % 15);
}

function calcAge(birthDate: string | null, userId: number): number {
  if (!birthDate) return fallbackAge(userId);
  const parsed = new Date(birthDate);
  if (Number.isNaN(parsed.getTime())) return fallbackAge(userId);
  const now = new Date();
  let age = now.getFullYear() - parsed.getFullYear();
  const monthDiff = now.getMonth() - parsed.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < parsed.getDate())) {
    age -= 1;
  }
  return age > 0 && age < 120 ? age : fallbackAge(userId);
}

function parsePreferences(raw: string | null): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((x) => typeof x === "string") : [];
  } catch {
    return [];
  }
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const [likedRows, pairRows] = await Promise.all([
      prisma.matchingLike.findMany({
        where: { fromUserId: userId, status: "active" },
        select: { toUserId: true },
      }),
      prisma.matchingPair.findMany({
        where: {
          status: "active",
          OR: [{ userAId: userId }, { userBId: userId }],
        },
        select: { userAId: true, userBId: true },
      }),
    ]);

    const excludeIds = new Set<number>([userId]);
    likedRows.forEach((l) => excludeIds.add(l.toUserId));
    pairRows.forEach((p) => {
      excludeIds.add(p.userAId === userId ? p.userBId : p.userAId);
    });

    const profiles = await prisma.matchingProfile.findMany({
      where: {
        isPublic: true,
        status: "active",
        deletedAt: null,
        userId: { notIn: Array.from(excludeIds) },
      },
      include: { user: { include: { profile: true } } },
      take: 30,
    });

    const data = profiles.map((p) => ({
      userId: String(p.userId),
      nickname: p.user.nickname,
      age: calcAge(p.user.profile?.birthDate ?? null, p.userId),
      introText: p.introText ?? p.user.profile?.introText ?? "",
      preferences: parsePreferences(p.preferences),
      emoji: pickEmoji(p.userId),
      likedByMe: false,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/matching/recommendations] 실패:", e);
    return NextResponse.json(
      { success: false, error: "추천 대상을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
