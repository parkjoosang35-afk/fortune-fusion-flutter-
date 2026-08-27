// 귀인지도 공유 링크 OG(Open Graph) 이미지 서빙 API.
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6-8] `GET /og/guinji/{token}.png`.
//
// [M8 확정] "동적 OG 생성 여부"는 §15 M8에서 "정적 PNG 확정"으로 결정되어 있다
// (§2 R9 "OG 정적 이미지 og-guinji-1200x630.png" · §16 D5 "동적 OG 템플릿"은
// M8이 향후 동적 생성으로 바뀔 경우에 대비한 디자인 요청일 뿐, 현재 범위 아님).
// 따라서 이 라우트는 사용자별/토큰별로 다른 이미지를 "생성"하지 않고, 유효한
// 초대 토큰인지만 검증한 뒤 고정 정적 PNG(public/guinji/og-guinji-1200x630.png)를
// 그대로 반환한다.
//
// [URL 형태] 파일 확장자(.png)가 경로 세그먼트에 포함되므로({token}.png 전체가
// 하나의 동적 세그먼트로 매칭됨), 라우트 핸들러 내부에서 ".png" 접미사를 제거해
// 순수 토큰 문자열을 얻는다.
//
// [만료/미존재 토큰 처리] SNS 크롤러(카카오톡/트위터 등)가 OG 이미지를 미리
// 가져갈 때 404를 반환하면 링크 미리보기 자체가 깨지는 사례가 있어, 존재하지
// 않거나 만료된 토큰이어도 동일한 폴백 이미지를 200으로 반환한다(공유 링크의
// 시각적 일관성 우선 — §6-4 GET /guinji/g/{token}처럼 사용자에게 직접 보여주는
// API가 아니라 크롤러/미리보기 전용이므로 굳이 404로 막을 실익이 없다).
import { NextRequest, NextResponse } from "next/server";
import { readFile } from "fs/promises";
import path from "path";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const OG_IMAGE_PATH = path.join(process.cwd(), "public", "guinji", "og-guinji-1200x630.png");
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ token: string }> }
) {
  const { token: tokenParam } = await params;
  const token = tokenParam.endsWith(".png") ? tokenParam.slice(0, -4) : tokenParam;

  try {
    // 존재/만료 여부는 로깅 목적으로만 조회한다(응답 자체는 항상 동일 정적 이미지 —
    // 위 주석 참고). 향후 M8이 "동적 생성"으로 바뀌면 이 조회 결과를 사용해 텍스트
    // 오버레이(예: 참여 인원수)를 렌더링하는 지점이 된다.
    if (token) {
      await prisma.guinjiMap.findUnique({ where: { token }, select: { id: true } });
    }

    const imageBuffer = await readFile(OG_IMAGE_PATH);
    return new NextResponse(imageBuffer as unknown as BodyInit, {
      status: 200,
      headers: {
        ...CORS_HEADERS,
        "Content-Type": "image/png",
        "Cache-Control": "public, max-age=3600, immutable",
      },
    });
  } catch (e) {
    console.error("[GET /api/public/og/guinji/[token]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "OG 이미지를 불러오지 못했습니다." },
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
