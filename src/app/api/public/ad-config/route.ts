// [신통방통 관리자 통합 간소화 실행 지시서 - task 4 "광고관리 통합메뉴"]
// 공개(비인증) AdMob/AdSense 광고 설정 조회 API.
//
// [배경] banners/route.ts와 동일한 문제: 관리자 화면에서 아무리 설정을 바꿔도
// 그 값을 프론트(Flutter 앱/웹)가 조회할 방법이 없으면 "화면만 있고 실제
// 서비스에는 반영되지 않는" 구조가 된다. 이 라우트를 신설해 해결한다.
//
// [응답 설계]
// - admob: isEnabled만 의미 있음(노출 킬스위치). 다른 필드는 참고용으로만 내려줌.
// - adsense: isEnabled + publisherId + surfaceConfig + formatConfig 전부 의미 있음.
// - Flutter AdRemoteConfigService는 앱 시작 시 이 API를 호출해 WebAdConfig/
//   AdmobAdIds의 컴파일타임 기본값을 런타임에 오버라이드한다. 조회 실패 시
//   기존 컴파일타임 기본값으로 안전하게 폴백해야 하므로, 이 API가 다운되어도
//   서비스에 악영향이 없다(가용성보다 안전한 폴백이 우선).
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

function safeParseJson(json: string | null): Record<string, boolean> {
  if (!json) return {};
  try {
    return JSON.parse(json);
  } catch {
    return {};
  }
}

export async function GET() {
  const rows = await prisma.adPlatformConfig.findMany({
    where: { platform: { in: ["admob", "adsense"] } },
  });

  const admob = rows.find((r) => r.platform === "admob");
  const adsense = rows.find((r) => r.platform === "adsense");

  const payload = {
    admob: {
      isEnabled: admob?.isEnabled ?? true,
    },
    adsense: {
      isEnabled: adsense?.isEnabled ?? false,
      publisherId: adsense?.publisherId ?? null,
      showPlaceholderWhenDisabled: adsense?.showPlaceholderWhenDisabled ?? true,
      surfaceConfig: safeParseJson(adsense?.surfaceConfigJson ?? null),
      formatConfig: safeParseJson(adsense?.formatConfigJson ?? null),
    },
  };

  return NextResponse.json(
    { success: true, data: payload },
    {
      headers: {
        // 관리자가 설정을 바꾼 직후 즉시 반영되도록 캐시 무효화 (banners/route.ts와 동일 정책).
        "Cache-Control": "no-store, no-cache, must-revalidate",
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
