// 메뉴(서비스) 공유 OG/카카오 중앙 설정 — Single Source of Truth.
//
// [배경 — 2026-10-21 "메뉴별 공유 주소" 작업] `share-og-config.ts`는
// 개인화된 "결과" 공유(예: "지민님의 정통사주 결과")를 위한 설정이다.
// 이번 요구사항은 그와 달리 "이 서비스를 한번 써보세요"라는 메뉴/서비스
// 자체의 홍보용 공유다(개인 결과 아님) — 의미가 달라 OG_CONFIG를
// 억지로 재사용하지 않고 이 파일을 새로 둔다.
//
// [내용 동기화 원칙] 여기 적힌 title/description 문구는 PC 랜딩
// (`sintong_pc_landing/src/landing-v7-content.js`의 `window.SECTIONS`)의
// tag/title/hook과 같은 톤을 유지한다. PC 랜딩 쪽 문구가 바뀌면 이 파일의
// description도 함께 맞춰야 한다(두 파일이 서로 다른 레포/배포 단위라
// import로 공유할 수 없어 수동 동기화 — 문구 변경 시 둘 다 고칠 것).
//
// [사용처]
//   1. `src/app/m/[menu]/page.tsx` — generateMetadata()가 이 설정으로
//      카카오/SNS 크롤러용 OG title/description/image/url을 만든다.
//   2. (예정) PC 랜딩의 "카카오톡 공유" 버튼 — Kakao.Share.sendDefault()
//      FeedTemplate도 반드시 이 설정과 "같은 메뉴 정보"를 쓴다(요구사항
//      "서비스 내 카카오톡 공유 버튼도 같은 메뉴 정보를 사용해주세요").
//      JS 번들이 분리되어 있어 이 TS 객체를 그대로 import할 수는 없고,
//      `/api/public/menu-share/[menu]` 엔드포인트(JSON)로 노출해 PC 랜딩
//      JS가 fetch해서 쓴다 — 이렇게 하면 문구 수정 시 이 파일 한 곳만
//      고치면 서버 OG와 카카오 버튼이 항상 같은 값을 쓰게 된다.
export type MenuKey =
  | "guinji"
  | "saju"
  | "tarot"
  | "wish"
  | "face"
  | "palm";

export type MenuShareConfigEntry = {
  /** PC 랜딩 `?s=` 쿼리 값이자 이 라우트의 URL 세그먼트(`/m/{key}`). */
  key: MenuKey;
  /** 메뉴 한글 이름(예: "정통사주"). */
  label: string;
  /** OG/카카오 공유 타이틀. */
  title: string;
  /** OG/카카오 공유 설명 한 줄. landing-v7-content.js의 hook과 동일 톤. */
  description: string;
  /** `public/share-og/` 디렉토리 내 OG 일러스트 파일명(기존 결과공유 이미지 재사용). */
  imageFile: string;
  /** PC 랜딩이 이 메뉴를 로드할 때 쓰는 Flutter 앱 라우트(참고용, 랜딩 쪽 THEME_ROUTE와 동일). */
  appRoute: string;
};

export const MENU_SHARE_CONFIG: Record<MenuKey, MenuShareConfigEntry> = {
  guinji: {
    key: "guinji",
    label: "귀인지도",
    title: "신통방통 · 귀인지도 — 내 편이 되는 사람을 미리 아는 법",
    description: "내 사주 속에서 귀인이 언제, 어느 방향에서 나타나는지 짚어주는 나만의 인연 지도.",
    imageFile: "relationship.png",
    appRoute: "/guinji-map",
  },
  saju: {
    key: "saju",
    label: "정통사주",
    title: "신통방통 · 정통사주 — 유행이 아닌 원전으로 풉니다",
    description: "생년월일시에서 펼쳐지는 원국·대운·세운을 원전 명리학의 원칙 위에서 하나하나 읽어드려요.",
    imageFile: "saju.png",
    appRoute: "/jeontong/input",
  },
  tarot: {
    key: "tarot",
    label: "타로",
    title: "신통방통 · 타로 — 지금 이 순간의 질문에, 카드로 답합니다",
    description: "연애, 이직, 인간관계 — 머릿속에 맴도는 질문을 그대로 카드에 던져보세요.",
    imageFile: "tarot.png",
    appRoute: "/tarot/intro",
  },
  wish: {
    key: "wish",
    label: "소원방",
    title: "신통방통 · 소원방 — 소원은 정해져야 이루어집니다",
    description: "무엇을, 언제, 어떻게 빌어야 하는지 함께 정리하고 빚어가는 공간.",
    imageFile: "wish.png",
    appRoute: "/wish-room",
  },
  face: {
    key: "face",
    label: "관상",
    title: "신통방통 · 관상 — 얼굴은 지금까지의 나를 기록합니다",
    description: "내가 어떤 사람인지, 어떤 흐름을 타고 있는지 읽는 오래된 학문, 관상.",
    imageFile: "face.png",
    appRoute: "/ai-fortune/face/capture",
  },
  palm: {
    key: "palm",
    label: "손금",
    title: "신통방통 · 손금 — 손안에 그려진 인생의 지도",
    description: "인생선·지혜선·감정선이 만나는 지점에서 성향과 운의 방향을 읽어드려요.",
    imageFile: "palm.png",
    appRoute: "/ai-fortune/palm/capture",
  },
};

export const MENU_SHARE_KEYS = Object.keys(MENU_SHARE_CONFIG) as MenuKey[];

export function isValidMenuKey(v: unknown): v is MenuKey {
  return typeof v === "string" && (MENU_SHARE_KEYS as readonly string[]).includes(v);
}
