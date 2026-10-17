// [쿠폰 디자인 스튜디오 4단계 — 엔드포인트 5종 중 4] POST
// /api/admin/bokju-coupons/campaigns/:id/design/assets
//
// 에디터에서 이미지 요소(kind='image')/배경에 쓸 파일을 업로드한다.
// [02e §7 금지목록#5 / §3-2] "이미지업로드: base64→서버자산엔드포인트,
// DB base64저장금지" — 파일을 public/uploads/ 아래 디스크에 저장하고
// 상대/절대 URL만 반환한다. SQLite(BokjuCouponDesignRevision.layout JSON)
// 에는 이 URL 문자열만 들어간다 — 이미지 바이트 자체는 절대 들어가지 않는다.
//
// 기존 /api/upload/route.ts(범용 업로드)와 별개로 둔 이유: 그 라우트는
// ALLOWED_CATEGORIES 화이트리스트를 수정해야 하는데, 이는 쿠폰 스튜디오와
// 무관한 다른 화면들이 공유하는 파일이라 변경 범위를 이 기능에 묶고 싶지
// 않았다(02e §5 "기존 40여 라우트 중복 생성 금지"는 bokju-coupons 네임
// 스페이스 내부 중복을 가리키며, 범용 업로드 라우트와는 도메인이 다르다).
//
// [02e §0-I 보강 — 매직바이트 검증] 파일 검증(화이트리스트·크기·실제 바이트
// 시그니처 확인)은 studio-api.ts의 validateUploadFile()(순수 함수, 테스트
// 하네스가 직접 검증)에 전부 위임한다. 이 라우트는 요청 파싱·인증가드·
// 디스크 저장·HTTP 응답 포맷팅만 담당하는 얇은 I/O 래퍼다(studio-api.ts
// 상단 주석의 설계 원칙과 동일).
import { NextRequest } from "next/server";
import { writeFile, mkdir } from "fs/promises";
import path from "path";
import { randomUUID } from "crypto";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import { validateUploadFile } from "@/lib/bokju-coupon-design/studio-api";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("자산 업로드 권한이 없습니다.", 403);

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const formData = await request.formData();
    const file = formData.get("file");
    if (!(file instanceof File)) return jsonError("파일이 전달되지 않았습니다.");

    const arrayBuffer = await file.arrayBuffer();
    const bytes = new Uint8Array(arrayBuffer);

    // [02e §0-I] declared MIME(화이트리스트)·크기·실제 바이트 시그니처
    // 셋 다 studio-api.ts에서 재검증한다 — file.type(요청 헤더)은
    // 클라이언트가 임의로 써보낼 수 있는 "주장"일 뿐이라, 실제 바이트까지
    // 열어 확인해야 SVG/스크립트를 image/png로 위장한 업로드를 막을 수
    // 있다(실제 공격 페이로드로 재현해 확인함).
    const validation = validateUploadFile(file.type, file.size, bytes);
    if (!validation.ok || !validation.ext) {
      return jsonError(validation.errorMessage ?? "파일 검증에 실패했습니다.");
    }

    const uploadDir = path.join(
      process.cwd(), "public", "uploads", "bokju-coupons", "design-studio", String(campaignId),
    );
    await mkdir(uploadDir, { recursive: true });

    const fileName = `${Date.now()}_${randomUUID().slice(0, 8)}.${validation.ext}`;
    const filePath = path.join(uploadDir, fileName);
    await writeFile(filePath, Buffer.from(arrayBuffer));

    const assetUrl = `/uploads/bokju-coupons/design-studio/${campaignId}/${fileName}`;
    return jsonOk({ assetUrl, originalFileName: file.name, mimeType: file.type, fileSize: file.size }, 201);
  } catch (e) {
    console.error("[POST /api/admin/bokju-coupons/campaigns/:id/design/assets] 실패:", e);
    return jsonError("자산 업로드 중 오류가 발생했습니다.", 500);
  }
}
