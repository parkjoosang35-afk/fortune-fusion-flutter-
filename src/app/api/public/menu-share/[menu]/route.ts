// 메뉴(서비스) 공유 정보 — 공개 JSON API.
// `GET /api/public/menu-share/{menu}` → { title, description, imageUrl, url }.
//
// [왜 필요한가] 요구사항 "서비스 내 카카오톡 공유 버튼도 같은 메뉴 정보를
// 사용해주세요"를 지키려면, `/m/[menu]/page.tsx`의 generateMetadata()가
// 만드는 OG와 PC 랜딩(`sintong_pc_landing`, 별도 정적 사이트·별도 배포
// 단위)의 카카오 공유 버튼이 동일한 title/description/image를 써야 한다.
// admin_web의 TS 설정 파일(`menu-share-config.ts`)을 pc_landing의 순수
// JS 번들이 직접 import할 수는 없으므로, 이 엔드포인트로 JSON을 공개
// 노출해 pc_landing의 랜딩 스크립트가 fetch해서 쓰게 한다 — 문구를
// 고칠 때 `menu-share-config.ts` 한 곳만 고치면 서버 OG와 카카오 공유
// 버튼이 항상 같은 값을 쓰게 되는 구조다.
//
// [CORS] pc_landing은 nginx상 같은 origin(sintong.kr)에서 서빙되므로
// 운영에서는 CORS가 필요 없지만, 샌드박스 프리뷰(서로 다른 포트/도메인)
// 테스트를 위해 `/api/public/og/share/[shareId]`와 동일하게 와일드카드
// Access-Control-Allow-Origin을 허용한다(공개 홍보용 데이터라 민감정보
// 없음 — 결과 공유 OG 이미지 API와 동일한 보안 수준 판단).
import { NextRequest, NextResponse } from "next/server";
import { isValidMenuKey, MENU_SHARE_CONFIG } from "@/lib/menu-share-config";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function OPTIONS() {
  return new NextResponse(null, { status: 204, headers: CORS_HEADERS });
}

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ menu: string }> }
) {
  const { menu } = await params;
  if (!isValidMenuKey(menu)) {
    return NextResponse.json(
      { error: "invalid_menu" },
      { status: 404, headers: CORS_HEADERS }
    );
  }

  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const config = MENU_SHARE_CONFIG[menu];

  return NextResponse.json(
    {
      menu: config.key,
      label: config.label,
      title: config.title,
      description: config.description,
      imageUrl: `${baseUrl}/share-og/${config.imageFile}`,
      // 사람이 실제로 열었을 때 OG가 노출되는 공유 주소(카카오톡 공유 버튼의
      // link.webUrl/mobileWebUrl, 그리고 "링크 복사"가 복사해야 할 값).
      shareUrl: `${baseUrl}/m/${config.key}`,
    },
    { headers: { ...CORS_HEADERS, "Cache-Control": "public, max-age=60" } }
  );
}
