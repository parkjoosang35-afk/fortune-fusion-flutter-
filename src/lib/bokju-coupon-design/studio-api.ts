// src/lib/bokju-coupon-design/studio-api.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 디자인 스튜디오 — 4단계 작업순서 2: 엔드포인트 5종의 "핵심 로직"
//
// [설계 원칙 — 02e §5 + §0-G 필수 1·3] route.ts(Next.js 핸들러)는 요청
// 파싱·인증가드·HTTP 응답 포맷팅만 담당하는 얇은 껍데기로 두고, 실제
// 로직(검증·조회·freeze·되돌리기·카탈로그 조립)은 전부 이 파일의 순수
// 함수에 둔다. 이렇게 분리하는 이유:
//   1) revision.ts/dispatch.ts 와 동일한 기존 관행(테스트 하네스가
//      Next.js 서버 없이 함수를 직접 호출해 검증할 수 있어야 한다).
//   2) §0-G 필수1 "서버도 validateLayout 재검증" 을 route.ts 마다
//      중복 구현하면 드리프트 위험이 생긴다 — 이 파일에 한 번만 구현한다.
//
// [절대 불가침 — 02e §2/§7]
//   · layout.ts/theme.ts/templates.ts 는 읽기 전용(import 만, 수정 금지).
//   · validateLayout 은 layout.ts 의 것을 그대로 재사용한다(복사 금지,
//     §0-G 필수1 — "서버에서 그대로 재사용. 복사하지 마십시오").
//   · 팔레트·템플릿·부품 값은 theme.ts/templates.ts 에서 export 된 것을
//     그대로 JSON 화해서 돌려준다(값을 손으로 재입력하지 않는다 — §0-G
//     필수3).
//   · bokju-coupon-image-service.ts / bokju-coupon-visibility.ts 는 이
//     파일에서 import 하지 않는다(완전히 독립된 신규 경로, 기존 관행과 동일).
//
// [§0-G 필수 2 — 샘플 토큰 경계] previewDesign() 은 실제 쿠폰을 전혀
// 만들지 않고, 고정된 샘플 redeemToken('0'.repeat(32))·샘플 couponNo 로
// RenderContext 를 조립해 renderer.ts 의 renderCouponImage() 를 호출할
// 뿐이다. 이 함수는 BokjuCoupon 테이블에 쓰기 작업을 전혀 하지 않으므로
// (findUnique/create 호출 없음), 샘플 토큰이 실제 발행 레코드에 섞여
// 들어갈 경로 자체가 코드 구조상 존재하지 않는다 — 발행 경로(freezeAndPublishDesign
// → freezeRevision/setCurrentRevision, dispatch.ts 의 dispatchCouponRender)
// 와는 함수 수준에서 완전히 분리되어 있다.
// ─────────────────────────────────────────────────────────────────────
import { prisma } from '@/lib/db';
import {
  validateLayout, designLayoutSchema, defaultLayout,
  type DesignLayout, type LayoutIssue,
} from './layout';
import { PALETTES, paletteCatalog } from './theme';
import { TEMPLATES, PARTS, PART_GROUPS } from './templates';
import {
  freezeRevision, setCurrentRevision, listRevisions as listRevisionsRaw,
} from './revision';
import { renderCouponImage, type RenderContext } from './renderer';

// ────────────────────────────────────────────── 공통 오류
export class StudioApiError extends Error {
  code: string;
  status: number;
  issues?: LayoutIssue[];
  constructor(code: string, message: string, status = 400, issues?: LayoutIssue[]) {
    super(message);
    this.code = code;
    this.status = status;
    this.issues = issues;
  }
}

async function getCampaignOrThrow(campaignId: number) {
  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
  if (!campaign) throw new StudioApiError('CAMPAIGN_NOT_FOUND', `캠페인 ${campaignId}을(를) 찾을 수 없습니다.`, 404);
  return campaign;
}

// ────────────────────────────────────────────── 1) 디자인 조회
export interface GetCampaignDesignResult {
  layout: DesignLayout;
  currentRevisionId: number | null;
  currentRevisionNo: number | null;
}

/**
 * 캠페인의 "지금 발행에 쓸" 레이아웃을 돌려준다.
 * currentDesignRevisionId 가 있으면 그 리비전의 layout, 없으면(신규
 * 캠페인·아직 신규 디자인으로 전환 안 한 캠페인) defaultLayout() 을
 * 돌려준다 — 에디터가 "빈 손이 아니라 출발점이 있는" 상태로 시작한다.
 */
export async function getCampaignDesign(campaignId: number): Promise<GetCampaignDesignResult> {
  const campaign = await getCampaignOrThrow(campaignId);

  if (campaign.currentDesignRevisionId == null) {
    return { layout: defaultLayout(), currentRevisionId: null, currentRevisionNo: null };
  }

  const rev = await prisma.bokjuCouponDesignRevision.findUnique({
    where: { id: campaign.currentDesignRevisionId },
  });
  if (!rev) {
    // 데이터 정합성 방어(이론상 FK 없음 — 수동 삭제 시에만 발생). 레거시
    // 폴백과 동일한 방어적 동작(resolveLayoutForCoupon 의 관행과 일치).
    return { layout: defaultLayout(), currentRevisionId: null, currentRevisionNo: null };
  }
  return {
    layout: designLayoutSchema.parse(JSON.parse(rev.layout)),
    currentRevisionId: rev.id,
    currentRevisionNo: rev.revNo,
  };
}

// ────────────────────────────────────────────── 2) 디자인 저장(발행)
export interface SaveCampaignDesignResult {
  ok: true;
  revisionId: number;
  revisionNo: number;
  reused: boolean;
  contentHash: string;
  issues: LayoutIssue[]; // warn 만 남을 수 있음(error 는 이 지점까지 못 옴)
}

/**
 * [§0-G 필수 1 — 가장 중요] 서버가 validateLayout() 을 **다시** 돌린다.
 * 클라이언트 검사를 통과했다고 주장하는 요청이라도, 여기서 error 가 하나라도
 * 있으면 거부한다(400) — 클라이언트 검사는 우회 가능하기 때문이다.
 *
 * 통과하면 freezeRevision() 으로 리비전을 동결하고(같은 디자인이면 재사용),
 * 곧바로 setCurrentRevision() 으로 캠페인의 "현재 리비전" 포인터를 그 리비전으로
 * 옮긴다 — 02e §3-3 "디자인 저장 → freezeRevision → setCurrentRevision" 흐름
 * 그대로. 이 함수가 "쿠폰 행"을 만들지는 않는다(발행 흐름은 기존
 * issueCoupons() 가 담당 — 리비전 포인터만 넘긴다).
 */
export async function saveCampaignDesign(
  campaignId: number,
  rawLayout: unknown,
  opts: { note?: string; createdBy?: string } = {},
): Promise<SaveCampaignDesignResult> {
  await getCampaignOrThrow(campaignId);

  // [필수1] layout.ts 의 validateLayout 을 그대로 재사용 — 복사하지 않는다.
  const result = validateLayout(rawLayout);
  const hasError = result.issues.some((i) => i.level === 'error');
  if (!result.ok || hasError || !result.layout) {
    throw new StudioApiError(
      'LAYOUT_INVALID',
      '레이아웃 검증에 실패했습니다. 오류를 해결한 뒤 다시 저장해 주세요.',
      400,
      result.issues,
    );
  }

  const frozen = await freezeRevision(campaignId, result.layout, opts);
  await setCurrentRevision(campaignId, frozen.id);

  return {
    ok: true,
    revisionId: frozen.id,
    revisionNo: frozen.revNo,
    reused: frozen.reused,
    contentHash: '', // 호출부가 필요하면 canonicalHash 를 별도로 계산(여기선 불필요한 재계산 생략)
    issues: result.issues, // warn 만 남을 수 있음
  };
}

// ────────────────────────────────────────────── 3) 리비전 목록
export interface RevisionListItem {
  id: number;
  revNo: number;
  note: string | null;
  createdBy: string | null;
  createdAt: string;
  contentHash: string;
  isCurrent: boolean;
}

export async function listCampaignRevisions(campaignId: number): Promise<RevisionListItem[]> {
  const campaign = await getCampaignOrThrow(campaignId);
  const revs = await listRevisionsRaw(campaignId);
  return revs.map((r) => ({
    id: r.id,
    revNo: r.revNo,
    note: r.note,
    createdBy: r.createdBy,
    createdAt: r.createdAt.toISOString(),
    contentHash: r.contentHash,
    isCurrent: r.id === campaign.currentDesignRevisionId,
  }));
}

// ────────────────────────────────────────────── 4) 되돌리기
export interface RollbackResult {
  ok: true;
  campaignId: number;
  revisionId: number;
  revisionNo: number;
  /**
   * [§0-G 필수 4] 롤백 UI 에 그대로 보여줄 두 가지 사실. 이 함수는 텍스트만
   * 돌려주고, 실제 안내 문구 렌더링은 호출부(React 에디터)의 책임이다.
   */
  notice: {
    existingCouponsUnaffected: string;
    futureCouponsUseThisRevision: string;
  };
}

const ROLLBACK_NOTICE = {
  existingCouponsUnaffected:
    '이미 발행된 쿠폰은 발행 당시 디자인을 그대로 유지합니다(바뀌지 않습니다).',
  futureCouponsUseThisRevision:
    '앞으로 새로 발행되는 쿠폰부터 되돌린 리비전의 디자인을 받습니다.',
};

/**
 * 캠페인의 "현재 리비전" 포인터를 과거 리비전으로 되돌린다.
 * setCurrentRevision() 하나로 충분하다(리비전 행 자체는 불변 — revision.ts
 * 의 설계 그대로, 포인터만 바꾼다). revisionId 가 이 캠페인 소속이 아니면
 * setCurrentRevision 내부에서 에러를 던진다(기존 안전장치 재사용).
 */
export async function rollbackCampaignDesign(
  campaignId: number,
  revisionId: number,
): Promise<RollbackResult> {
  await getCampaignOrThrow(campaignId);
  const rev = await prisma.bokjuCouponDesignRevision.findUnique({ where: { id: revisionId } });
  if (!rev || rev.campaignId !== campaignId) {
    throw new StudioApiError('REVISION_NOT_FOUND', `리비전 ${revisionId}을(를) 이 캠페인에서 찾을 수 없습니다.`, 404);
  }
  await setCurrentRevision(campaignId, revisionId);
  return {
    ok: true,
    campaignId,
    revisionId: rev.id,
    revisionNo: rev.revNo,
    notice: ROLLBACK_NOTICE,
  };
}

// ────────────────────────────────────────────── 5) 미리보기(샘플 토큰)
/**
 * [§0-G 필수 2] 미리보기 전용 샘플 컨텍스트. 실제 쿠폰 데이터가 아니다
 * — 고정값이며, 발행 경로(issueCoupons/dispatchCouponRender)가 생성하는
 * 실제 redeemToken(암호학적으로 무작위)과는 값 자체가 겹칠 수 없는
 * 자리수/패턴(전부 '0')을 쓴다. 이 값이 실제 쿠폰 테이블에 쓰이는 일은
 * 없다 — 이 함수는 DB 쓰기를 전혀 하지 않는다(아래 구현 참고).
 */
const SAMPLE_REDEEM_TOKEN = '0'.repeat(32);
const SAMPLE_COUPON_NO = 'SAMPLE-0000-0000';

export interface PreviewDesignInput {
  layout: unknown;
  campaignTitle: string;
  grantAmount: number;
  guideText?: string | null;
  validFrom: Date;
  validTo: Date;
  registerBaseUrl: string;
  partnerName?: string;
}

export interface PreviewDesignResult {
  buffer: Buffer;
  issues: LayoutIssue[];
  /** 화면에 "미리보기용 QR(샘플)"임을 명시하기 위한 플래그 — §0-G 필수2 */
  isSample: true;
}

/**
 * 서버 렌더 미리보기. 레이아웃 검증은 하되(경고 안내용), error 가 있어도
 * 미리보기 자체는 막지 않는다(드래그 중 중간 상태를 보여줘야 하므로) —
 * 단, **저장(발행)은 반드시 saveCampaignDesign() 의 검증을 통과해야 한다**
 * (미리보기가 느슨하다고 발행까지 느슨해지지 않는다 — 별도 함수, 별도 경로).
 *
 * 이 함수는 BokjuCoupon 테이블을 전혀 읽거나 쓰지 않는다 — 샘플 토큰이
 * 실제 쿠폰과 뒤섞일 코드 경로 자체가 없다(§0-G 필수2 "코드 구조로 경계
 * 보장").
 */
export async function previewDesign(input: PreviewDesignInput): Promise<PreviewDesignResult> {
  const parsed = designLayoutSchema.safeParse(input.layout);
  const layout = parsed.success ? parsed.data : defaultLayout();
  const validation = validateLayout(layout);

  const ctx: RenderContext = {
    campaign: {
      title: input.campaignTitle,
      grantAmount: input.grantAmount,
      guideText: input.guideText,
      validFrom: input.validFrom,
      validTo: input.validTo,
    },
    coupon: { couponNo: SAMPLE_COUPON_NO, redeemToken: SAMPLE_REDEEM_TOKEN },
    registerBaseUrl: input.registerBaseUrl,
    partnerName: input.partnerName,
  };

  const buffer = await renderCouponImage(layout, ctx);
  return { buffer, issues: validation.issues, isSample: true };
}

// ────────────────────────────────────────────── 6) 카탈로그(§0-G 필수3)
/**
 * [§0-G 필수 3] 팔레트·템플릿·부품 값은 전부 theme.ts/templates.ts 가
 * 정본이다. 이 함수는 그 값을 "그대로" 직렬화해서 돌려줄 뿐, 문자열/숫자를
 * 손으로 다시 적지 않는다 — 드리프트 방지. (사용자가 지적한 "부품 16종"
 * 오탈자 같은 사고를 구조적으로 막는다.)
 */
export interface DesignCatalog {
  palettes: ReturnType<typeof paletteCatalog>;
  templates: Array<{ id: string; name: string; note: string; bestFor: string }>;
  parts: Array<{ id: string; name: string; group: string; note: string }>;
  partGroups: readonly string[];
}

export function getDesignCatalog(): DesignCatalog {
  return {
    // theme.ts 의 paletteCatalog() 를 그대로 호출 — 색상 값을 재입력하지 않는다.
    palettes: paletteCatalog(),
    // templates.ts 의 TEMPLATES 배열에서 build 함수(직렬화 불가)만 제외하고
    // 나머지 필드를 그대로 전달한다 — id/name/note/bestFor 값은 TEMPLATES 원본.
    templates: TEMPLATES.map((t) => ({ id: t.id, name: t.name, note: t.note, bestFor: t.bestFor })),
    // PARTS 도 동일 — make 함수만 제외.
    parts: PARTS.map((p) => ({ id: p.id, name: p.name, group: p.group, note: p.note })),
    partGroups: PART_GROUPS,
  };
}

// 참고용 재노출 — 카탈로그 값이 PALETTES/TEMPLATES/PARTS 와 동일 소스임을
// 테스트가 직접 확인할 수 있게 한다(드리프트 회귀 테스트용).
export { PALETTES, TEMPLATES, PARTS, PART_GROUPS };

// ────────────────────────────────────────────── 7) 자산 업로드 검증(§0-I)
/**
 * [02e §0-I 보강 — 매직바이트 검증] 업로드 자산의 저장 확장자는 처음부터
 * ALLOWED_UPLOAD_MIME_TYPES[file.type](요청이 "주장하는" MIME)에서만
 * 파생되어 file.name(사용자 파일명)의 확장자를 쓰지 않는다 — 그래서
 * "사용자 파일명이 .svg면 .svg로 저장된다"는 경로는 원래부터 없었다.
 *
 * 다만 file.type(요청의 Content-Type)은 클라이언트가 임의로 써 보낼 수
 * 있는 "주장"일 뿐이다. SVG/스크립트 바이트에 Content-Type: image/png만
 * 씌워 보내면 MIME 화이트리스트 검사를 그대로 통과한다(실제 공격으로
 * 재현해 확인함 — 이 함수가 그 틈을 메운다). sniffImageMimeType()이 파일의
 * 실제 바이트 시그니처(매직바이트)를 읽어 "정말 PNG/JPEG/WEBP가 맞는지"를
 * 재확인하고, resolveUploadExtension()이 그 결과로만 저장 확장자를
 * 결정한다 — "사용자 입력에서 경로/형식을 만들지 않는다"는 path traversal
 * 방어와 같은 원리를 포맷 신뢰에도 적용한 것이다.
 */
export const ALLOWED_UPLOAD_MIME_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};
export const MAX_UPLOAD_FILE_SIZE = 5 * 1024 * 1024; // 5MB(02e §0-I "명세 기준 5MB 이하")

/** 파일 바이트 시그니처를 읽어 실제 이미지 MIME을 식별한다(없으면 null). */
export function sniffImageMimeType(bytes: Uint8Array): string | null {
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 &&
    bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a
  ) {
    return 'image/png';
  }
  // JPEG: FF D8 FF
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg';
  }
  // WEBP: 'RIFF' .... 'WEBP'
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
  ) {
    return 'image/webp';
  }
  return null;
}

export interface UploadValidationResult {
  ok: boolean;
  /** 저장에 사용할 확장자(매직바이트로 확인된 실제 포맷에서만 파생). */
  ext?: string;
  errorMessage?: string;
}

/**
 * 업로드 요청을 검증한다: ① declared MIME이 화이트리스트에 있는가,
 * ② 크기 제한 이내인가, ③ 실제 바이트가 정말 이미지 포맷이 맞는가.
 * route.ts(I/O 래퍼)는 이 함수의 결과만으로 저장 여부와 확장자를 결정한다.
 */
export function validateUploadFile(
  declaredMimeType: string,
  size: number,
  bytes: Uint8Array,
): UploadValidationResult {
  const declaredExt = ALLOWED_UPLOAD_MIME_TYPES[declaredMimeType];
  if (!declaredExt) {
    return { ok: false, errorMessage: '지원하지 않는 파일 형식입니다. (jpg/png/webp만 허용)' };
  }
  if (size > MAX_UPLOAD_FILE_SIZE) {
    return { ok: false, errorMessage: '파일 크기는 5MB를 초과할 수 없습니다.' };
  }
  const sniffedType = sniffImageMimeType(bytes);
  const ext = sniffedType ? ALLOWED_UPLOAD_MIME_TYPES[sniffedType] : undefined;
  if (!sniffedType || !ext) {
    return { ok: false, errorMessage: '파일 내용이 이미지 형식(PNG/JPEG/WEBP)과 일치하지 않습니다.' };
  }
  return { ok: true, ext };
}
