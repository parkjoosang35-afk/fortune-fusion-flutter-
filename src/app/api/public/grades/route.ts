// 공개(비인증) 회원 등급 마스터 조회 API — Flutter GradeRepository.getAllGrades()/
// getGradeByCode() 대응.
//
// [문서8 DB스키마초안 §8-1 반영] 그동안 Flutter GradeRepository가 4등급을
// 고정 배열(Mock)로 하드코딩하고 있었던 것을 admin_web `user_grades` 테이블
// 실데이터로 교체하기 위한 신규 라우트. 등급 마스터는 갱신 빈도가 낮으므로
// 단순 목록 조회만 제공하고(where 없이 전체 조회), 정렬은 DB의 sortOrder를
// 그대로 사용한다(복합 인덱스 불필요).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(_request: NextRequest) {
  try {
    const rows = await prisma.userGrade.findMany({
      where: { deletedAt: null, status: "active" },
      orderBy: { sortOrder: "asc" },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          grades: rows.map((g) => ({
            code: g.code,
            name: g.name,
            min_activity_score: g.minActivityScore,
            point_earn_multiplier: g.pointEarnMultiplier,
            sort_order: g.sortOrder,
          })),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/grades] 실패:", e);
    return NextResponse.json(
      { success: false, error: "등급 마스터를 불러오지 못했습니다." },
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
