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
  validateLayout, designLayoutSchema, defaultLayout, CANVAS_PRESETS,
  type DesignLayout, type LayoutIssue,
} from './layout';
import { PALETTES, paletteCatalog, resolveTheme } from './theme';
import { TEMPLATES, PARTS, PART_GROUPS, buildTemplate } from './templates';
import {
  freezeRevision, setCurrentRevision, listRevisions as listRevisionsRaw,
} from './revision';
import { renderCouponImage, type RenderContext } from './renderer';
import { convertVisibilityToLayout } from './legacy-convert';
import { parseVisibilityJson, DEFAULT_VISIBILITY } from '@/lib/bokju-coupon-visibility';

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

// ────────────────────────────────────────────── 공통 — 레거시 캠페인의 "실제 설정" 매핑
/**
 * [02m §0-R-6 통합안] 레거시(customTemplateId 유무로 구분되는 11토글)
 * 캠페인이 "지금 실제로 보여주고 있는" 레이아웃을 convertVisibilityToLayout()
 * 으로 계산한다. convertLegacyDesign()의 visibility 결정 로직(02e §4-1 +
 * 02k §필수 decoration 교정)을 그대로 추출한 것 — 복제가 아니라 공용화
 * (전환 버튼 경로와 에디터 진입 경로가 같은 함수를 호출해야 두 진입점이
 * 드리프트하지 않는다).
 *
 * [내장 템플릿 — decoration 예외] customTemplateId 가 없으면(CLASSIC/
 * PREMIUM/KAKAO/MINIMAL) 11토글 개념 자체가 없으므로 DEFAULT_VISIBILITY로
 * 간주하되, decoration만은 false로 교정한다 — 내장 템플릿 렌더 함수
 * (buildClassicSvg 등)는 애초에 장식을 그리지 않기 때문이다(02k §필수,
 * convertLegacyDesign() 주석 참고).
 *
 * [커스텀 템플릿] customTemplateId 가 있으면 그 템플릿의 실제 visibility
 * JSON을 읽어 그대로 반영한다 — qr=false 등으로 꺼둔 토글이 에디터
 * 기본값에 덮여 사라지지 않도록 하는 것이 이 함수의 핵심 목적이다.
 */
async function resolveLegacyLayout(
  campaign: { customTemplateId: number | null },
): Promise<DesignLayout> {
  let rawVisibility: unknown = { ...DEFAULT_VISIBILITY, decoration: false };
  if (campaign.customTemplateId != null) {
    const tpl = await prisma.bokjuCouponDesignTemplate.findUnique({
      where: { id: campaign.customTemplateId },
    });
    if (tpl) {
      rawVisibility = parseVisibilityJson(tpl.visibility);
    }
    // tpl 이 없으면(데이터 정합성 방어) DEFAULT_VISIBILITY 로 폴백.
  }
  // [02p §0-U-3] canvas 를 convertVisibilityToLayout() 의 기본값에 맡기지
  // 않고 여기서 명시적으로 PORTRAIT_720 을 넘긴다. 이유: layout.ts 의
  // blankLayout·noQrLayout·templates.ts 의 buildTemplate 은 전부 기본값이
  // PORTRAIT_1080 이고, convertVisibilityToLayout 만 720 이다 — 누군가
  // "다른 함수들과 통일한다"며 그 기본값을 1080으로 바꾸면 전환·에디터
  // 경로만 조용히 1080이 되고(신규 캠페인은 여전히 720) 캠페인마다 발행
  // 크기가 갈리는 사고가 난다. 의도를 코드에 고정해 그 경로를 막는다.
  return convertVisibilityToLayout(rawVisibility, CANVAS_PRESETS.PORTRAIT_720);
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
 * 캠페인·아직 신규 디자인으로 전환 안 한 캠페인) **그 캠페인의 실제
 * 레거시 설정을 매핑한 레이아웃**(resolveLegacyLayout())을 돌려준다.
 *
 * [02m §0-R-6 수정 — 이전엔 defaultLayout() 이었다] 이전 버전은 여기서
 * defaultLayout()(빈 자리에 아무 토글도 반영 안 된 고정 기본값)을
 * 돌려줬는데, 이것이 바로 구조적 구멍이었다: 레거시 캠페인(특히
 * customTemplateId로 qr=false 등 실제 토글을 꺼둔 캠페인)의 에디터 초기
 * 화면이 "그 캠페인의 실제 설정"이 아니라 "아무 의미 없는 기본값"을
 * 보여줬고, 관리자가 그 상태로 "저장"만 눌러도(= saveCampaignDesign(),
 * 전환 버튼을 거치지 않음) currentDesignRevisionId가 채워지면서 실제
 * 토글 설정이 통째로 무시되고 기본값으로 덮였다(campaign 1 은 운 좋게
 * DEFAULT_VISIBILITY와 결과가 같아 피해가 없었을 뿐 — campaign 23/24처럼
 * 실제 토글을 꺼둔 캠페인이었다면 사일런트 데이터 손실이었다).
 *
 * resolveLegacyLayout()으로 교체하면, 에디터가 "그 캠페인이 실제로
 * 보여주고 있는 레거시 렌더와 동일한 구성"에서 출발하므로, 그대로
 * 저장해도 §4-3 "자동 전환 금지"가 지키려던 불변량(= 명시적 동의 없이
 * 디자인이 바뀌지 않는다)이 깨지지 않는다.
 */
export async function getCampaignDesign(campaignId: number): Promise<GetCampaignDesignResult> {
  const campaign = await getCampaignOrThrow(campaignId);

  if (campaign.currentDesignRevisionId == null) {
    const layout = await resolveLegacyLayout(campaign);
    return { layout, currentRevisionId: null, currentRevisionNo: null };
  }

  const rev = await prisma.bokjuCouponDesignRevision.findUnique({
    where: { id: campaign.currentDesignRevisionId },
  });
  if (!rev) {
    // 데이터 정합성 방어(이론상 FK 없음 — 수동 삭제 시에만 발생). 위
    // null 분기와 동일하게 "그 캠페인의 실제 레거시 설정"으로 폴백한다
    // (defaultLayout()이 아니다 — 02m §0-R-6과 동일한 이유).
    const layout = await resolveLegacyLayout(campaign);
    return { layout, currentRevisionId: null, currentRevisionNo: null };
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
 *
 * [02n §0-S-2 요청5] 아래 defaultLayout() 폴백은 "클라이언트가 보낸
 * input.layout이 DesignLayout 스키마 파싱에 실패했을 때"만 발동하는
 * 입력 검증 방어 코드다 — 에디터가 이미 유효한 레이아웃 상태를 들고
 * 있는 정상 흐름에서는 절대 타지 않는다. 레거시 캠페인의 "현재
 * 디자인이 무엇인가"를 결정하는 경로(getCampaignDesign())와는 호출
 * 관계가 전혀 없다 — 그쪽은 §0-R-6에서 resolveLegacyLayout()으로
 * 교체했고, 이 함수는 그 결과를 가져와 미리보기만 그릴 뿐 자체적으로
 * "레거시 기본값"을 결정하지 않는다.
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

// ────────────────────────────────────────────── 5-2) §4-3 레거시 전환
/**
 * [작업순서4 — 02e §4-3 기본안(d) + 02h §0-M-6] "신규 디자인으로 전환" 버튼의
 * 핵심 로직. 기존 11토글(CouponVisibilityConfig) 캠페인을 신규 DesignLayout
 * 체계로 1회 변환한다.
 *
 * [자동 전환 절대 금지 — 02e §4-2/§4-3] 이 함수는 관리자가 명시적으로
 * 호출(버튼 클릭 → API 요청)할 때만 실행된다. 이 모듈 안 어디에도 이
 * 함수를 자동으로 트리거하는 코드가 없다(배치 루프·발행 흐름 등 다른
 * 경로에서 import되지 않음 — route.ts 하나만 이 함수를 호출한다).
 *
 * [가드 — 버튼 1회] campaign.currentDesignRevisionId 가 이미 있으면
 * (= 이미 전환됨, 또는 신규 캠페인이라 처음부터 신규 에디터를 씀) 거부한다.
 * UI에서 버튼을 숨기는 것과 별개로, 데이터 계층에서도 재전환을 막는다
 * (이중 방어 — UI 우회로 같은 캠페인을 두 번 변환하는 사고 방지).
 *
 * [전환 전 레이아웃도 리비전으로 보존 — 02h §0-M-6] freezeRevision() 이
 * 만드는 rev1 자체가 "레거시 11토글 상태와 동등한" 변환 결과이며, 리비전
 * 행은 절대 UPDATE/DELETE 되지 않는다(revision.ts 불변 원칙). 이후 관리자가
 * 신규 에디터에서 내용을 더 고쳐 rev2 이상을 저장하더라도, rev1 은 영구히
 * 남아 기존 rollbackCampaignDesign()(→ GET revisions 목록 + POST rollback)
 * 으로 언제든 되돌릴 수 있다 — 별도의 "레거시 전용 리비전 타입"을 새로
 * 만들지 않는다(기존 되돌리기 메커니즘을 그대로 재사용 — 02e §5 "엔드포인트
 * 기존 재사용 우선"과 동일한 원칙).
 *
 * [발행 전 검사 우회 금지 — 금지 목록 ⑦] 변환 결과는 반드시
 * validateLayout() 을 통과해야 한다. 레거시 설정이 극단적이어서(예: QR과
 * 쿠폰번호를 모두 끔 → NO_DYNAMIC_BINDING) 통과하지 못하면, 검사를
 * 느슨하게 만들지 않고 전환 자체를 거부한다(400, issues 포함) — 관리자가
 * 레거시 화면에서 먼저 설정을 바로잡아야 한다.
 */
export interface ConvertLegacyDesignResult {
  ok: true;
  revisionId: number;
  revisionNo: number;
  issues: LayoutIssue[]; // warn 만 남을 수 있음(error 는 이 지점까지 못 옴)
  /**
   * [02k §결정 A — 장식 색 편차 고지] decoration이 true여서 장식 요소
   * (테두리+모서리 원 2개)가 실제로 추가된 경우에만 채워지는 안내문.
   * 레거시 렌더(bokju-coupon-image-service.ts 324-330줄)는 고정 헥스
   * #d4a94a를 쓰지만, 신규 레이아웃은 테마 토큰 @accent로 대체한다
   * (팔레트 전환 시 장식도 함께 따라오게 하려는 의도적 설계 — 02k 권고
   * (A) 수용). 두 색은 휘도 차이가 커서(약 49%) 나란히 비교하면
   * 구분되므로, "완전히 동일한 외형 재현이 아니다"를 명시적으로 고지한다.
   * decoration이 꺼져 있던 경우(장식 자체가 없음)는 null — 색 차이를
   * 고지할 대상이 없으므로.
   */
  decorationColorNotice: string | null;
}

export async function convertLegacyDesign(
  campaignId: number,
  opts: { createdBy?: string } = {},
): Promise<ConvertLegacyDesignResult> {
  const campaign = await getCampaignOrThrow(campaignId);

  // [버튼 1회 가드] 이미 신규 레이아웃을 쓰고 있으면(전환 완료 또는 신규
  // 캠페인) 재전환을 거부한다 — §4-3 "자동 전환 금지"의 데이터 계층 반영.
  if (campaign.currentDesignRevisionId != null) {
    throw new StudioApiError(
      'ALREADY_CONVERTED',
      '이미 신규 디자인으로 전환된 캠페인입니다. 다시 전환할 수 없습니다.',
      409,
    );
  }

  // [02m §0-R-6 — 공용화] "customTemplateId 유무로 실제 visibility를
  // 결정하고 convertVisibilityToLayout()으로 매핑한다"는 로직은 더 이상
  // 이 함수에 직접 두지 않는다. getCampaignDesign()의 레거시 폴백이
  // 똑같은 로직을 필요로 하게 되면서(02m §0-R-2 구조적 구멍 수정)
  // resolveLegacyLayout()으로 추출했고, 이 함수는 그것을 재사용한다 —
  // 두 진입점(전환 버튼 / 에디터 진입)이 같은 함수를 호출해야 드리프트가
  // 생기지 않는다(단일 진실 소스 원칙, 위 resolveLegacyLayout() 주석
  // 참고 — 내장 템플릿 decoration 예외·커스텀 템플릿 visibility 반영
  // 로직 설명은 전부 그쪽에 있다).
  const converted = await resolveLegacyLayout(campaign);

  // [금지 목록 ⑦ — 검사 우회 금지] 변환 결과도 저장 전 검사(saveCampaignDesign
  // 과 동일한 validateLayout)를 반드시 통과해야 한다. 복사하지 않고 그대로
  // 재사용한다(§0-G 필수1 과 동일 원칙).
  const result = validateLayout(converted);
  const hasError = result.issues.some((i) => i.level === 'error');
  if (!result.ok || hasError || !result.layout) {
    throw new StudioApiError(
      'CONVERSION_INVALID',
      '레거시 설정을 신규 레이아웃으로 변환했지만 발행 전 검사를 통과하지 못했습니다. '
        + '레거시 화면에서 QR 또는 쿠폰번호 중 최소 하나는 켜져 있는지 확인한 뒤 다시 시도하세요.',
      400,
      result.issues,
    );
  }

  // [02e §4-3 "freezeRevision → setCurrentRevision → rev1 동결"]
  const frozen = await freezeRevision(campaignId, result.layout, {
    note: '§4-3 레거시 전환 — 11토글 설정을 신규 레이아웃으로 자동 변환',
    createdBy: opts.createdBy,
  });
  await setCurrentRevision(campaignId, frozen.id);

  // [02k §결정 A] rawVisibility.decoration 을 다시 읽지 않고, "실제로
  // 변환 결과에 장식 요소가 생겼는가"로 직접 판단한다(legacy-convert.ts의
  // 추가 매핑 로직과 드리프트 없이 항상 일치하도록 — 단일 진실 소스).
  const hasDecoration = result.layout.elements.some((e) => e.id.startsWith('deco'));

  return {
    ok: true,
    revisionId: frozen.id,
    revisionNo: frozen.revNo,
    issues: result.issues,
    decorationColorNotice: hasDecoration
      ? '장식(테두리·모서리 원)의 색상은 레거시 고정 색상(#d4a94a)이 아니라 테마 색상(@accent)으로 표시됩니다. 팔레트에 따라 레거시와 미세하게 다른 색으로 보일 수 있습니다.'
      : null,
  };
}

// ────────────────────────────────────────────── 5-2b) 작업순서6 — 신규 캠페인 초기 리비전
/**
 * [작업순서6 — 02l §0-Q-2 결정 (a)] 신규 캠페인 생성 직후, 레이아웃
 * 기본값(buildTemplate('classic', …))에서 바로 리비전을 동결해
 * currentDesignRevisionId 를 처음부터 채운다.
 *
 * [왜 (a)인가 — convertVisibilityToLayout(DEFAULT_VISIBILITY) 가 아닌 이유]
 * convertLegacyDesign() 이 내장 템플릿 캠페인을 전환할 때 쓰는 기본값은
 * `{ ...DEFAULT_VISIBILITY, decoration: false }` (02k §필수 수정, 위 참고)
 * 이고, 그 결과 요소 집합은 classic 템플릿의 9개 그대로(장식 0개)다.
 * 신규 캠페인이 `convertVisibilityToLayout(DEFAULT_VISIBILITY)` (decoration
 * 그대로 true)를 쓰면 장식 3개가 추가되어, 같은 classic 기반인데도
 * "전환한 캠페인엔 장식이 없고 새로 만든 캠페인엔 있다"는 불일치가
 * 생긴다 — 단일 진실 소스 원칙 위반(이번이 두 번째 사례). 따라서 신규
 * 경로도 buildTemplate('classic', …)을 직접 호출해 전환 경로와 동일한
 * 출발점(장식 0개, 요소 9개)에서 시작한다.
 *
 * [함수 호출 1줄 — 02l 요청] 아래가 그 1줄이다:
 *   const layout = buildTemplate('classic', resolveTheme(undefined), CANVAS_PRESETS.PORTRAIT_720);
 *
 * [조건① — validateLayout 통과] buildTemplate('classic', …)은 QR·쿠폰번호가
 * 모두 켜진 완전한 레이아웃이므로 validateLayout()을 항상 통과한다(장식이
 * 없을 때도 NO_DYNAMIC_BINDING 등 에러 조건에 해당하지 않음). 그래도
 * 방어적으로 재검증하고, 혹시라도 실패하면(이론상 불가능하나) 캠페인
 * 생성 자체를 막지 않고 조용히 건너뛴다 — 레거시 폴백(currentDesignRevisionId
 * null → defaultLayout())이 항상 존재하므로 신규 캠페인 생성 자체가
 * 막히는 사고를 만들지 않는다.
 *
 * [조건② — 기존 캠페인 3개 절대 미접촉] 이 함수는 createCampaign() 이
 * 새로 만든 campaignId 에 대해서만 호출되며, 기존 캠페인의
 * currentDesignRevisionId 를 조회·수정하는 코드가 전혀 없다(freezeRevision/
 * setCurrentRevision 모두 신규 campaignId 인자로만 호출).
 */
export async function initializeNewCampaignDesign(
  campaignId: number,
  opts: { createdBy?: string } = {},
): Promise<{ revisionId: number; revisionNo: number } | null> {
  const layout = buildTemplate('classic', resolveTheme(undefined), CANVAS_PRESETS.PORTRAIT_720);

  const result = validateLayout(layout);
  const hasError = result.issues.some((i) => i.level === 'error');
  if (!result.ok || hasError || !result.layout) {
    // 방어적 분기 — 이론상 도달하지 않는다(classic 템플릿은 항상 유효).
    // 신규 캠페인 생성 자체를 막지 않고 레거시 폴백(null)으로 둔다.
    return null;
  }

  const frozen = await freezeRevision(campaignId, result.layout, {
    note: '작업순서6 — 신규 캠페인 초기 리비전(classic 기본값)',
    createdBy: opts.createdBy,
  });
  await setCurrentRevision(campaignId, frozen.id);
  return { revisionId: frozen.id, revisionNo: frozen.revNo };
}

// ────────────────────────────────────────────── 5-3) §0-M-6/02i §필수2 레거시 되돌리기
/**
 * [02i §필수2 — "(A) 전환 취소 경로를 만든다" 쪽으로 결정] convertLegacyDesign()
 * 이 만드는 rev1은 "변환 후" 레이아웃이지 "변환 전"(레거시 11토글) 상태가
 * 아니다 — 따라서 rev1으로 rollbackCampaignDesign()을 호출해도 전환 전
 * 화면(레거시 11토글 렌더)으로는 돌아가지 않는다(무변화). 레거시 11토글
 * 상태 자체는 애초에 DesignLayout 스키마가 아니므로(CouponVisibilityConfig는
 * 별도 JSON 스키마) freezeRevision()으로 리비전화할 수 없다 — 리비전
 * 하나를 "레거시 상태"로 박아 넣는 방식은 구조적으로 성립하지 않는다.
 *
 * 대신 campaign.currentDesignRevisionId 포인터 자체를 다시 null로 되돌린다
 * (revision.ts의 setCurrentRevision(campaignId, null) 재사용 — 이미
 * revisionId: number | null 타입으로 null을 지원하도록 구현되어 있었다).
 * getCampaignDesign()은 currentDesignRevisionId == null이면 이미
 * defaultLayout()으로 폴백하고, BokjuCampaignDetailClient.tsx의 조건부
 * 렌더링(`campaign.currentDesignRevisionId == null`)도 이 포인터 하나로
 * "레거시 11토글 화면을 보여줄지, 신규 에디터를 보여줄지"를 결정하므로,
 * 포인터만 null로 되돌리면 레거시 11토글 화면이 그대로 다시 노출된다 —
 * 별도의 "레거시 전용 리비전 타입"을 새로 만들지 않는다(02e §4-3 설계
 * 노트가 말하던 "기존 되돌리기 메커니즘 재사용"과 동일한 원칙을
 * "레거시 복귀"에도 그대로 적용한 것).
 *
 * [소급 변경 없음 — 안전성 근거] coupon.designRevisionId는 발행(쿠폰 행
 * 생성) 시점에 이미 각인되어 있다(revision.ts §금지목록 #4,
 * bokju-coupon-service.ts issueCoupons()). 포인터를 null로 되돌려도 이미
 * 발행된 쿠폰의 각인값은 전혀 건드리지 않으므로, 기발행 쿠폰 이미지는
 * 영향받지 않는다 — rollbackCampaignDesign()과 완전히 동일한 안전성 근거.
 *
 * [데이터 보존 확인] 레거시 설정 데이터(BokjuCouponDesignTemplate.visibility
 * JSON, customTemplateId 미지정이면 DEFAULT_VISIBILITY)는 전환 시 삭제되지
 * 않고 그대로 남아 있다 — convertLegacyDesign()이 읽기만 하고 아무것도
 * 지우지 않기 때문이다. 따라서 되돌리면 convertLegacyDesign() 호출 전과
 * 동일한 레거시 설정이 그대로 다시 보인다.
 *
 * [가드] 아직 전환하지 않은 캠페인(currentDesignRevisionId가 이미 null)은
 * 되돌릴 대상이 없으므로 거부한다 — "전환된 적 있는 캠페인만" 되돌릴 수
 * 있다(멱등하지 않게 막아 오조작을 방지).
 */
export interface RevertToLegacyResult {
  ok: true;
  campaignId: number;
  /**
   * [02i 테스트#15 정정 대상 — 롤백 UI 두 문구] rollbackCampaignDesign()의
   * ROLLBACK_NOTICE와 문구 성격은 같지만, 대상이 "리비전"이 아니라
   * "레거시 11토글 설정"이므로 문구를 되돌리기 전용으로 분리한다.
   */
  notice: {
    existingCouponsUnaffected: string;
    futureCouponsUseLegacy: string;
    colorFidelityNotice: string;
  };
}

const REVERT_TO_LEGACY_NOTICE = {
  existingCouponsUnaffected:
    '이미 발행된 쿠폰은 발행 당시 디자인을 그대로 유지합니다(바뀌지 않습니다).',
  futureCouponsUseLegacy:
    '앞으로 새로 발행되는 쿠폰부터 되돌린 리비전의 디자인을 받습니다. 기존 11토글 설정은 삭제되지 않고 보존되어 있었으므로, 전환 전과 동일한 모습으로 돌아갑니다.',
  // [02k §결정 A — 색상 차이 고지] "전환 전 상태로 돌아간다"가 100%
  // 정확한 설명은 아니라는 점을 명시한다 — 장식이 있던 캠페인을
  // 전환했다가 되돌릴 때, 그 사이 전환 상태의 장식 색은 레거시 고정
  // 헥스(#d4a94a)가 아니라 테마 토큰(@accent)이었다. 되돌린 뒤에는
  // 레거시 11토글 렌더 자체로 복귀하므로 이 차이는 사라지지만, 관리자가
  // "전환 중 미리보기"와 "레거시"를 색상으로 비교하다 문의하는 것을
  // 막기 위해 되돌리기 화면에도 동일하게 고지한다.
  colorFidelityNotice:
    '참고: 신규 디자인으로 전환되어 있던 동안에는 장식(테두리·모서리 원) 색상이 테마 색상(@accent)으로 표시되어, 레거시 고정 색상(#d4a94a)과 미세하게 달랐을 수 있습니다. 레거시로 되돌리면 이 차이 없이 원래 색상 그대로 보입니다.',
};

export async function revertToLegacyDesign(campaignId: number): Promise<RevertToLegacyResult> {
  const campaign = await getCampaignOrThrow(campaignId);

  if (campaign.currentDesignRevisionId == null) {
    throw new StudioApiError(
      'NOT_CONVERTED',
      '아직 신규 디자인으로 전환되지 않은 캠페인입니다. 되돌릴 대상이 없습니다.',
      409,
    );
  }

  await setCurrentRevision(campaignId, null);

  return {
    ok: true,
    campaignId,
    notice: REVERT_TO_LEGACY_NOTICE,
  };
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
