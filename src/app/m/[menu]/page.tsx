// 메뉴(서비스) 공유 링크 — 공개 웹 랜딩페이지.
// [2026-10-21 신설 — "메뉴별 공유 주소 + OG + 카카오톡 공유" 작업]
//
// [요구사항 매핑]
//   "PC·모바일 대표 도메인은 sintong.kr로 유지" → 이 라우트는 nginx
//     `location /`(admin_web 프록시, sintong.kr.conf 확인됨)로 자동
//     서빙되므로 별도 도메인/서브도메인 없이 sintong.kr 아래에 산다.
//   "메뉴별 공유 주소를 구분" → `/m/{menu}` 6종(guinji/saju/tarot/wish/
//     face/palm), `menu-share-config.ts`가 유일한 소스.
//   "공유 주소에 맞는 OG 제목·설명·이미지·주소를 서버 응답에 포함" →
//     아래 generateMetadata()(Server Component, 카카오 크롤러가 읽는
//     og:title/description/image/url을 실제로 HTML에 심는다).
//   "공유 링크를 누르면 PC는 기존 레이아웃 가운데에서, 모바일은 전체
//     화면으로 해당 메뉴가 바로 열리게" → 사람이 이 링크를 열면
//     `RedirectToLanding`이 즉시 `sintong.kr/?s={menu}`로 이동한다. 그
//     주소는 PC 랜딩의 `landing-v7.js`(`initFromShareParam`)가 이미
//     `?s=` 쿼리를 읽어 해당 메뉴 테마로 iframe을 띄우고, CSS
//     `@media(max-width:1023px)`가 모바일에서 좌우 패널을 숨기고
//     iframe을 전체화면으로 보여주는 처리를 전부 하므로(2026-10-21
//     모바일 반응형 작업, 이번 작업 범위 아님 — 재사용만 함) 이 파일은
//     리다이렉트만 책임진다.
//
// [`/r/[id]` 패턴과의 차이] `/r`은 "개인 결과"라 noindex + Flutter 앱
// 내부 화면으로 보낸다. 이 `/m`은 "서비스 홍보"라 검색 노출을 막을
// 이유가 없고(index 허용), 목적지도 앱이 아니라 PC 랜딩 자체다(랜딩이
// 이미 iframe으로 앱을 품고 있으므로 결국 같은 화면이 뜨지만, 좌우
// 안내 영역까지 보여주는 완전한 랜딩 경험을 제공하기 위해 랜딩을 거친다).
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { isValidMenuKey, MENU_SHARE_CONFIG } from "@/lib/menu-share-config";
import { RedirectToLanding } from "./redirect-to-landing";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ menu: string }>;
};

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { menu } = await params;
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const pageUrl = `${baseUrl}/m/${menu}`;

  if (!isValidMenuKey(menu)) {
    return {
      title: "신통방통",
      description: "사주 · 타로 · 귀인지도까지, 신통방통이 들려주는 오늘 당신의 운명 이야기.",
    };
  }

  const config = MENU_SHARE_CONFIG[menu];
  const imageUrl = `${baseUrl}/share-og/${config.imageFile}`;

  return {
    title: config.title,
    description: config.description,
    openGraph: {
      title: config.title,
      description: config.description,
      url: pageUrl,
      images: [{ url: imageUrl, width: 1200, height: 630 }],
      type: "website",
      siteName: "신통방통",
    },
    twitter: {
      card: "summary_large_image",
      title: config.title,
      description: config.description,
      images: [imageUrl],
    },
  };
}

export default async function MenuSharePage({ params }: PageProps) {
  const { menu } = await params;
  if (!isValidMenuKey(menu)) {
    notFound();
  }
  return <RedirectToLanding menu={menu} />;
}
