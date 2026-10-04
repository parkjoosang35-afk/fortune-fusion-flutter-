// 결과 공유(Share) OG(Open Graph) 중앙 설정 — Single Source of Truth.
//
// [배경 — 2027-02 6개 카테고리 통일 작업] 기존에는 동일한 정보(카테고리별
// 라벨/태그라인/이미지 경로)가 다음 4개 파일에 중복 분산되어 있었다:
//   1. api/public/share/_shared.ts            → SHARE_RESULT_TYPES(화이트리스트)
//   2. api/public/og/share/buildShareOgPng.tsx → RESULT_TYPE_LABEL/DEFAULT_TAGLINE/ILLUSTRATION_PATHS
//   3. api/public/og/share/[shareId]/route.ts  → isKnownResultType(하드코딩 배열)
//   4. r/[id]/page.tsx                         → RESULT_TYPE_LABEL(표시용 짧은 라벨)
// 카테고리 하나를 추가/변경할 때마다 4곳을 전부 찾아 고쳐야 했다. 이
// 파일이 유일한 소스이며, 위 4곳은 전부 이 파일을 참조하도록 리팩토링한다.
//
// [6개 카테고리 체계] wish(소원방) / tarot(타로) / saju(정통사주) /
// relationship(귀인지도) / face(관상) / palm(손금).
//
// [하위 호환 — 절대 원칙] `fortune`은 과거(이 작업 이전) 생성된
// SharedResult.resultType='fortune' 레코드 및 그 `/r/{shareId}` 링크가
// 계속 정상 동작해야 하므로 화이트리스트에 "레거시 전용"으로 영구 보존한다.
// **신규 코드/신규 호출부는 절대 'fortune'을 쓰지 않고 'saju'를 사용할 것**
// (Flutter `ShareResultType.fortune`도 동일하게 @Deprecated로만 남아있다).
import path from "path";

export type ShareContentType =
  | "fortune" // @deprecated 레거시 전용 — 신규 공유는 saju 사용. 하위호환으로만 보존.
  | "saju"
  | "tarot"
  | "face"
  | "palm"
  | "wish"
  | "relationship";

export type OgConfigEntry = {
  /** `/r/[id]` 페이지 상단 뱃지 등에 쓰는 짧은 한글 표시명(예: "정통사주"). */
  label: string;
  /** OG PNG 카드 좌상단 브랜드 라벨(예: "신통방통 · 정통사주"). */
  brandLabel: string;
  /** OG PNG 카드 기본 태그라인(한 줄 카피). description이 없을 때 폴백으로도 사용. */
  defaultTagline: string;
  /** `public/share-og/` 디렉토리 내 OG 일러스트 PNG 파일명. */
  imageFile: string;
};

const SHARE_OG_DIR = path.join(process.cwd(), "public", "share-og");

/**
 * contentType → {label, brandLabel, defaultTagline, imageFile} 중앙 매핑.
 * 카테고리를 추가/변경할 때는 **이 객체 하나만** 수정하면 된다.
 */
export const OG_CONFIG: Record<ShareContentType, OgConfigEntry> = {
  // [레거시 전용] 과거 "오늘의 운세" 통합 화면이 fortune으로 공유했던
  // 기존 데이터의 하위호환만을 위해 유지한다. 신규 공유는 절대 이 값을
  // 쓰지 않는다(saju로 대체됨).
  fortune: {
    label: "오늘의 운세",
    brandLabel: "신통방통 · 오늘의 운세",
    defaultTagline: "생년월일만 넣으면 바로 나와요",
    imageFile: "fortune.png",
  },
  saju: {
    label: "정통사주",
    brandLabel: "신통방통 · 정통사주",
    defaultTagline: "생년월일만 넣으면 바로 나와요",
    imageFile: "saju.png",
  },
  tarot: {
    label: "타로",
    brandLabel: "신통방통 · 타로",
    defaultTagline: "카드가 알려주는 오늘의 이야기",
    imageFile: "tarot.png",
  },
  face: {
    label: "관상",
    brandLabel: "신통방통 · 관상",
    defaultTagline: "얼굴에 담긴 나의 이야기",
    imageFile: "face.png",
  },
  palm: {
    label: "손금",
    brandLabel: "신통방통 · 손금",
    defaultTagline: "손금이 알려주는 나의 이야기",
    imageFile: "palm.png",
  },
  wish: {
    label: "소원방",
    brandLabel: "신통방통 · 소원방",
    defaultTagline: "소원을 빌고 함께 이뤄가요",
    imageFile: "wish.png",
  },
  relationship: {
    label: "귀인지도",
    brandLabel: "신통방통 · 귀인지도",
    defaultTagline: "내 곁의 귀인을 찾아드려요",
    imageFile: "relationship.png",
  },
};

/** 화이트리스트(화이트리스트 검증용) — fortune(레거시) 포함 7개 값. */
export const SHARE_CONTENT_TYPES = Object.keys(OG_CONFIG) as ShareContentType[];

export function isValidShareContentType(v: unknown): v is ShareContentType {
  return typeof v === "string" && (SHARE_CONTENT_TYPES as readonly string[]).includes(v);
}

export function ogImageAbsolutePath(type: ShareContentType): string {
  return path.join(SHARE_OG_DIR, OG_CONFIG[type].imageFile);
}
