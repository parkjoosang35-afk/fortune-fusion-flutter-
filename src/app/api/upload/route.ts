// 이미지 파일 업로드 API Route Handler
// 관리자 화면(부적 상품 등)에서 이미지를 "URL 직접 입력"뿐 아니라
// "로컬 파일 업로드"로도 등록할 수 있도록 지원한다.
// - 인증: verifyAdminSession()으로 관리자 세션 확인 (미인증 시 401)
// - 저장 위치: public/uploads/{category}/{timestamp}_{random}.{ext}
//   (정적 파일이므로 Next.js가 /uploads/{category}/... 경로로 그대로 서빙한다)
// - 반환: { url: "/uploads/{category}/파일명" } — 기존 imageUrl 문자열 필드에
//   그대로 저장할 수 있는 형태라서 DB 스키마/Server Action 변경이 필요 없다.
import { NextRequest, NextResponse } from "next/server";
import { writeFile, mkdir } from "fs/promises";
import path from "path";
import { randomUUID } from "crypto";
import { verifyAdminSession } from "@/lib/dal";

// 업로드를 허용할 카테고리 화이트리스트(디렉토리 탐색 공격 방지 목적).
// 필요한 화면이 늘어나면 여기에 추가한다.
const ALLOWED_CATEGORIES = new Set([
  "amulets",
  "tarot-cards",
  "banners",
  "luckybag",
  "giftcards",
  "popups",
  "events",
  // [사용자 요청: "오늘의 행운숫자" 관리자 콘텐츠 - 이미지/영상/스크립트 첨부 지원]
  "lucky-number",
  // [열림패스 첨부파일/광고소스 연동] 열림패스 상품별 첨부파일(이미지/영상/문서) 업로드
  "open-pass",
  // [메인화면 관리자 편집기] 섹션별 대표배너/서브배너/아이콘/배경/fallback 이미지 업로드
  "page-configs",
]);

const ALLOWED_IMAGE_MIME_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/jpg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
};

// [사용자 요청: "오늘의 행운숫자" 영상 첨부 지원] 기존 배너 업로드는 이미지 전용이었으나,
// lucky-number 카테고리는 영상(mp4/webm/mov) 업로드도 허용해야 한다.
const ALLOWED_VIDEO_MIME_TYPES: Record<string, string> = {
  "video/mp4": "mp4",
  "video/webm": "webm",
  "video/quicktime": "mov",
};

// [열림패스 첨부파일] 안내 PDF 문서 업로드 지원(document 유형).
const ALLOWED_DOCUMENT_MIME_TYPES: Record<string, string> = {
  "application/pdf": "pdf",
};

const ALLOWED_MIME_TYPES: Record<string, string> = {
  ...ALLOWED_IMAGE_MIME_TYPES,
  ...ALLOWED_VIDEO_MIME_TYPES,
  ...ALLOWED_DOCUMENT_MIME_TYPES,
};

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB (이미지)
// 영상은 이미지보다 용량이 크므로 별도 상한을 둔다(최대 40MB).
const MAX_VIDEO_FILE_SIZE = 40 * 1024 * 1024;
// PDF 등 문서 파일 상한(최대 15MB).
const MAX_DOCUMENT_FILE_SIZE = 15 * 1024 * 1024;

export async function POST(request: NextRequest) {
  // 인증 실패 시 verifyAdminSession()이 redirect()를 호출하는데, API Route(fetch)
  // 컨텍스트에서는 리다이렉트가 의미 없으므로 세션 부재를 먼저 별도 체크한다.
  try {
    await verifyAdminSession();
  } catch {
    return NextResponse.json({ error: "인증이 필요합니다." }, { status: 401 });
  }

  const formData = await request.formData();
  const file = formData.get("file");
  const categoryRaw = formData.get("category");
  const category = typeof categoryRaw === "string" ? categoryRaw : "";

  if (!ALLOWED_CATEGORIES.has(category)) {
    return NextResponse.json({ error: "허용되지 않은 업로드 카테고리입니다." }, { status: 400 });
  }

  if (!(file instanceof File)) {
    return NextResponse.json({ error: "파일이 전달되지 않았습니다." }, { status: 400 });
  }

  const ext = ALLOWED_MIME_TYPES[file.type];
  if (!ext) {
    return NextResponse.json(
      {
        error:
          "지원하지 않는 파일 형식입니다. (이미지: jpg/png/webp/gif, 영상: mp4/webm/mov, 문서: pdf)",
      },
      { status: 400 }
    );
  }

  const isVideo = file.type in ALLOWED_VIDEO_MIME_TYPES;
  const isDocument = file.type in ALLOWED_DOCUMENT_MIME_TYPES;
  const maxSize = isVideo ? MAX_VIDEO_FILE_SIZE : isDocument ? MAX_DOCUMENT_FILE_SIZE : MAX_FILE_SIZE;
  if (file.size > maxSize) {
    return NextResponse.json(
      { error: `파일 크기는 ${Math.floor(maxSize / (1024 * 1024))}MB를 초과할 수 없습니다.` },
      { status: 400 }
    );
  }

  const uploadDir = path.join(process.cwd(), "public", "uploads", category);
  await mkdir(uploadDir, { recursive: true });

  const fileName = `${Date.now()}_${randomUUID().slice(0, 8)}.${ext}`;
  const filePath = path.join(uploadDir, fileName);

  const arrayBuffer = await file.arrayBuffer();
  await writeFile(filePath, Buffer.from(arrayBuffer));

  // 배너/팝업 등 일부 화면은 imageUrl을 절대 URL(https://...) 형식으로
  // zod 검증(.url() / ^https?:\/\/)하므로, 상대경로 대신 절대 URL을 반환한다.
  // [버그 수정] request.nextUrl.origin은 샌드박스 환경에서 항상
  // http://localhost:3000으로 잡혀 외부(Flutter 앱 등)에서 접근 불가능한 URL이
  // 저장되는 문제가 있었다. 공개 접속 가능한 PUBLIC_BASE_URL 환경변수를 우선 사용하고,
  // 없을 경우에만 기존 방식(origin)으로 폴백한다.
  const baseUrl = process.env.PUBLIC_BASE_URL || request.nextUrl.origin;
  const url = `${baseUrl}/uploads/${category}/${fileName}`;
  // [열림패스 첨부파일] 원본 파일명/MIME/용량도 함께 반환한다(첨부파일 관리 폼이
  // 이 메타데이터를 hidden input으로 그대로 저장할 수 있도록). 기존 소비자(ImageUploadField 등)는
  // data.url만 사용하므로 필드 추가는 하위 호환성에 영향 없다.
  return NextResponse.json({
    url,
    originalFileName: file.name,
    mimeType: file.type,
    fileSize: file.size,
    isVideo,
    isDocument,
  });
}
