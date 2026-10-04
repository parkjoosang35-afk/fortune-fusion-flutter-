// 결과 공유 카톡 OG 카드 — 동적 PNG 생성기.
// [설계] guinji `buildOgPng.tsx`(D2 화이트리스트 원칙)와 동일한 패턴을
// 6종 결과 공유(정통사주/타로/관상/손금/소원방/귀인지도, +레거시 fortune)에
// 맞게 일반화한다.
//
// [2027-02 6개 카테고리 통일] 카테고리별 라벨/태그라인/이미지 경로는 더 이상
// 이 파일에 직접 선언하지 않고, 중앙 설정 `@/lib/share-og-config`의
// OG_CONFIG 하나를 참조한다(OG_CONFIG 중앙화 — 카테고리 변경 시 그 파일
// 하나만 고치면 됨).
//
// [화이트리스트 원칙 — 반드시 지킬 것]
//   1. 이미지 안에는 title(닉네임 포함 가능) + resultType 라벨 + tagline만
//      넣는다. 생년월일·전화번호·이메일·원본 사진 등은 절대 넣지 않는다
//      (호출부인 /api/public/share POST가 이미 이런 값을 막아야 하지만,
//      이 함수 자체도 [OgShareCardData] 타입에 선언된 필드 외에는 어떤
//      값도 받지 않는 구조로 강제한다).
//   2. 이 함수가 던지는 예외는 호출부([shareId]/route.ts)가 catch해
//      정적 PNG로 폴백한다 — 이 파일 안에서 실패를 숨기지 않는다.
import { ImageResponse } from "next/og";
import { readFile } from "fs/promises";
import path from "path";
import { OG_CONFIG, ogImageAbsolutePath, type ShareContentType } from "@/lib/share-og-config";

/** @deprecated 중앙 설정의 ShareContentType을 그대로 재노출(기존 호출부 호환용 별칭). */
export type ShareResultTypeLabel = ShareContentType;

/** [화이트리스트] 이 카드에 그릴 수 있는 값은 이 3개뿐이다. */
export type OgShareCardData = {
  /** 결과 타입(브랜드 라벨 텍스트 결정에만 사용, 원본 데이터 아님). */
  resultType: ShareContentType;
  /** 카드에 표시할 제목(예: "지민님의 정통사주"). 25자 초과 시 clamp. */
  title: string;
  /** 한 줄 카피. 미지정 시 resultType별 기본값(OG_CONFIG.defaultTagline). */
  tagline?: string;
};

const FONTS_DIR = path.join(process.cwd(), "public", "fonts");

let cachedFonts: { name: string; data: Buffer; weight: 400 | 700; style: "normal" }[] | null = null;
const cachedIllustrationDataUris = new Map<ShareContentType, string>();

async function loadFonts() {
  if (cachedFonts) return cachedFonts;
  const [gowunRegular, gowunBold] = await Promise.all([
    readFile(path.join(FONTS_DIR, "GowunBatang-Regular.ttf")),
    readFile(path.join(FONTS_DIR, "GowunBatang-Bold.ttf")),
  ]);
  cachedFonts = [
    { name: "GowunBatang", data: gowunRegular, weight: 400, style: "normal" },
    { name: "GowunBatang", data: gowunBold, weight: 700, style: "normal" },
  ];
  return cachedFonts;
}

async function loadIllustrationDataUri(resultType: ShareContentType) {
  const cached = cachedIllustrationDataUris.get(resultType);
  if (cached) return cached;
  const buffer = await readFile(ogImageAbsolutePath(resultType));
  const isJpeg = buffer[0] === 0xff && buffer[1] === 0xd8;
  const mime = isJpeg ? "image/jpeg" : "image/png";
  const dataUri = `data:${mime};base64,${buffer.toString("base64")}`;
  cachedIllustrationDataUris.set(resultType, dataUri);
  return dataUri;
}

function clampLine(text: string, maxLength = 25): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1)}…`;
}

/**
 * 결과 공유 OG 카드 PNG를 생성한다(1200x630).
 * [실패 시] 폰트/이미지 파일을 못 읽거나 렌더링 중 에러가 나면 그대로
 * throw한다 — 호출부가 정적 PNG로 폴백하는 것을 전제로 한다.
 */
export async function buildShareOgPng(data: OgShareCardData): Promise<ImageResponse> {
  const [fonts, illustrationDataUri] = await Promise.all([
    loadFonts(),
    loadIllustrationDataUri(data.resultType),
  ]);

  const config = OG_CONFIG[data.resultType];
  const brandLabel = config?.brandLabel ?? "신통방통";
  const title = clampLine(data.title);
  const tagline = clampLine(data.tagline ?? config?.defaultTagline ?? "");

  return new ImageResponse(
    (
      <div
        style={{
          width: "1200px",
          height: "630px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          backgroundColor: "#FAF3E0",
          padding: "72px 64px",
          fontFamily: "GowunBatang",
        }}
      >
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            maxWidth: "620px",
          }}
        >
          <div
            style={{
              fontSize: "28px",
              fontWeight: 700,
              letterSpacing: "4px",
              color: "#D97941",
              marginBottom: "28px",
            }}
          >
            {brandLabel}
          </div>
          <div
            style={{
              fontSize: "68px",
              fontWeight: 700,
              lineHeight: 1.25,
              color: "#2A1F14",
              marginBottom: "24px",
              wordBreak: "keep-all",
            }}
          >
            {title}
          </div>
          <div
            style={{
              fontSize: "30px",
              fontWeight: 400,
              lineHeight: 1.5,
              color: "#5A4A38",
            }}
          >
            {tagline}
          </div>
        </div>
        <img
          src={illustrationDataUri}
          width={380}
          height={380}
          style={{ display: "flex", objectFit: "contain" }}
        />
      </div>
    ),
    {
      width: 1200,
      height: 630,
      fonts,
    }
  );
}
