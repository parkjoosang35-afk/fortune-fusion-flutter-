// ══════════════════════════════════════════════════════════════════
// BokjuCouponImageService — [복주머니 마케팅 쿠폰 최종본 §5] 모바일 쿠폰
// 이미지 자동 제작(QR 합성) + ZIP/엑셀 일괄 다운로드.
//
// [설계 원칙]
//   - 이미지는 고객이 "받는" 쿠폰일 뿐, 실제 사용 권한은 서버의 쿠폰 데이터로만
//     검증한다(§5 "이미지만 복사하거나 QR코드만 열었다고 복주머니가 자동
//     지급되지 않습니다"). 이 모듈은 순수 "보여주기용 이미지 생성"만 담당하고,
//     redeem 로직(bokju-coupon-service.ts)에는 전혀 관여하지 않는다.
//   - 대량 생성은 Node.js 프로세스 내 setImmediate 루프의 백그라운드 작업으로
//     처리한다(이 프로젝트엔 별도 워커 프로세스/큐 인프라가 없으므로, 기존
//     "백그라운드 처리" 요구는 Next.js 서버 프로세스 안에서 비동기 루프 +
//     DB 진행률 polling으로 구현한다 — sharp 합성 자체가 CPU-bound라 이벤트
//     루프를 블로킹하지 않도록 배치 사이에 setImmediate로 양보한다).
//   - 실패 항목은 failedCouponIds(JSON)에 쌓이고, retryFailedImages()로 그
//     항목만 재시도한다(전체 재생성 금지 원칙).
// ══════════════════════════════════════════════════════════════════
import { mkdir, writeFile, readFile } from "fs/promises";
import path from "path";
import QRCode from "qrcode";
import sharp from "sharp";
import archiver from "archiver";
import ExcelJS from "exceljs";
import { createWriteStream } from "fs";
import { prisma } from "@/lib/db";

const PUBLIC_DIR = path.join(process.cwd(), "public");
const UPLOADS_ROOT = path.join(PUBLIC_DIR, "uploads", "bokju-coupons");

const IMG_WIDTH = 720;
const IMG_HEIGHT = 1280;
const BATCH_SIZE = 20; // 배치마다 이벤트 루프에 양보

function campaignDir(campaignId: number): string {
  return path.join(UPLOADS_ROOT, `campaign_${campaignId}`);
}

function couponImageRelPath(campaignId: number, couponId: number): string {
  return `/uploads/bokju-coupons/campaign_${campaignId}/images/${couponId}.png`;
}

function fmtDate(d: Date): string {
  return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")}`;
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

/**
 * 쿠폰 1장의 모바일 이미지를 합성한다.
 * - 상단: 신통방통 로고 텍스트 + 쿠폰명
 * - 중앙: 지급 복주머니 수량(큰 숫자) + QR코드
 * - 하단: 쿠폰 고유번호(마스킹 없이 전체 표시 — 고객이 직접 입력할 수도 있어야 함),
 *   사용 시작일/만료일, 안내 문구
 */
async function renderCouponImage(params: {
  campaignTitle: string;
  grantAmount: number;
  couponNo: string;
  redeemToken: string;
  validFrom: Date;
  validTo: Date;
  guideText: string | null;
  registerBaseUrl: string;
}): Promise<Buffer> {
  const qrUrl = `${params.registerBaseUrl}/coupon/${params.redeemToken}`;
  const qrDataUrl = await QRCode.toBuffer(qrUrl, {
    width: 420,
    margin: 1,
    color: { dark: "#2b1b0e", light: "#ffffff00" },
  });
  const qrBase64 = qrDataUrl.toString("base64");

  const guide = params.guideText?.trim() || "QR코드를 찍고 복주머니를 받으세요!";

  // 전통 복주머니 색감(적갈색/금색) 그라디언트 배경 + 텍스트 레이어를 SVG로 구성.
  const svg = `
<svg width="${IMG_WIDTH}" height="${IMG_HEIGHT}" viewBox="0 0 ${IMG_WIDTH} ${IMG_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#7a1f1f"/>
      <stop offset="55%" stop-color="#4a1212"/>
      <stop offset="100%" stop-color="#2a0a0a"/>
    </linearGradient>
    <linearGradient id="card" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#fff8e7"/>
      <stop offset="100%" stop-color="#fdeec9"/>
    </linearGradient>
  </defs>
  <rect width="${IMG_WIDTH}" height="${IMG_HEIGHT}" fill="url(#bg)"/>
  <circle cx="90" cy="110" r="150" fill="#ffd54f" opacity="0.08"/>
  <circle cx="${IMG_WIDTH - 60}" cy="${IMG_HEIGHT - 160}" r="200" fill="#ffd54f" opacity="0.07"/>

  <text x="${IMG_WIDTH / 2}" y="100" font-size="34" font-weight="700" fill="#ffd54f" text-anchor="middle" font-family="sans-serif">신통방통</text>
  <text x="${IMG_WIDTH / 2}" y="150" font-size="26" fill="#ffe9c0" text-anchor="middle" font-family="sans-serif">${escapeXml(params.campaignTitle)}</text>

  <rect x="60" y="200" width="${IMG_WIDTH - 120}" height="${IMG_HEIGHT - 400}" rx="28" fill="url(#card)"/>

  <text x="${IMG_WIDTH / 2}" y="290" font-size="30" fill="#7a1f1f" text-anchor="middle" font-family="sans-serif">지급 복주머니</text>
  <text x="${IMG_WIDTH / 2}" y="370" font-size="84" font-weight="800" fill="#c62828" text-anchor="middle" font-family="sans-serif">${params.grantAmount}</text>

  <image x="${IMG_WIDTH / 2 - 210}" y="410" width="420" height="420" href="data:image/png;base64,${qrBase64}"/>

  <text x="${IMG_WIDTH / 2}" y="880" font-size="24" fill="#6d4c20" text-anchor="middle" font-family="monospace">${escapeXml(params.couponNo)}</text>

  <text x="${IMG_WIDTH / 2}" y="930" font-size="22" fill="#8a6a3a" text-anchor="middle" font-family="sans-serif">${escapeXml(guide)}</text>

  <text x="${IMG_WIDTH / 2}" y="975" font-size="20" fill="#9b7b4a" text-anchor="middle" font-family="sans-serif">사용기한 ${fmtDate(params.validFrom)} ~ ${fmtDate(params.validTo)}</text>

  <text x="${IMG_WIDTH / 2}" y="${IMG_HEIGHT - 50}" font-size="18" fill="#ffe9c0" text-anchor="middle" font-family="sans-serif" opacity="0.85">신통방통 마케팅 쿠폰 · 1회 등록 가능</text>
</svg>`.trim();

  return sharp(Buffer.from(svg)).png().toBuffer();
}

export interface StartImageJobOptions {
  registerBaseUrl: string;
}

/** 캠페인의 쿠폰 전체(ISSUED 이상 상태) 이미지를 생성하는 작업을 등록하고 즉시 백그라운드로 시작한다. */
export async function startImageGenerationJob(
  campaignId: number,
  actorId: string,
  options: StartImageJobOptions
): Promise<{ jobId: number; totalCount: number }> {
  const coupons = await prisma.bokjuCoupon.findMany({
    where: { campaignId },
    select: { id: true },
  });
  if (coupons.length === 0) {
    throw new Error("발행된 쿠폰이 없습니다. 먼저 쿠폰을 발행하세요.");
  }

  const job = await prisma.bokjuCouponImageJob.create({
    data: {
      campaignId,
      status: "PENDING",
      totalCount: coupons.length,
      createdBy: actorId,
    },
  });

  // 백그라운드로 실행(await하지 않음) — API 응답은 즉시 jobId만 반환.
  void runImageJob(job.id, options).catch((e) => {
    console.error(`[BokjuCouponImageJob ${job.id}] 실행 중 예외:`, e);
  });

  return { jobId: job.id, totalCount: coupons.length };
}

/** 실패한 쿠폰 이미지만 재시도한다(§5 "실패 재시도" 요구사항 — 전체 재생성 금지). */
export async function retryFailedImages(
  jobId: number,
  options: StartImageJobOptions
): Promise<{ retried: number }> {
  const job = await prisma.bokjuCouponImageJob.findUnique({ where: { id: jobId } });
  if (!job) throw new Error("이미지 생성 작업을 찾을 수 없습니다.");
  const failedIds: number[] = job.failedCouponIds ? JSON.parse(job.failedCouponIds) : [];
  if (failedIds.length === 0) return { retried: 0 };

  await prisma.bokjuCouponImageJob.update({
    where: { id: jobId },
    data: { status: "RUNNING", failedCouponIds: null, failedCount: 0 },
  });

  void runImageJob(jobId, options, failedIds).catch((e) => {
    console.error(`[BokjuCouponImageJob ${jobId}] 재시도 중 예외:`, e);
  });

  return { retried: failedIds.length };
}

async function runImageJob(
  jobId: number,
  options: StartImageJobOptions,
  onlyCouponIds?: number[]
): Promise<void> {
  const job = await prisma.bokjuCouponImageJob.findUnique({ where: { id: jobId } });
  if (!job) return;

  await prisma.bokjuCouponImageJob.update({
    where: { id: jobId },
    data: { status: "RUNNING", startedAt: new Date() },
  });

  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: job.campaignId } });
  if (!campaign) {
    await prisma.bokjuCouponImageJob.update({ where: { id: jobId }, data: { status: "FAILED" } });
    return;
  }

  const coupons = await prisma.bokjuCoupon.findMany({
    where: onlyCouponIds ? { id: { in: onlyCouponIds } } : { campaignId: job.campaignId },
    select: { id: true, couponNo: true, redeemToken: true, expiresAt: true },
    orderBy: { id: "asc" },
  });

  const dir = campaignDir(job.campaignId);
  await mkdir(path.join(dir, "images"), { recursive: true });

  let processed = onlyCouponIds ? job.processedCount : 0;
  const failedIds: number[] = [];

  for (let i = 0; i < coupons.length; i += BATCH_SIZE) {
    const batch = coupons.slice(i, i + BATCH_SIZE);
    await Promise.all(
      batch.map(async (c) => {
        try {
          const buf = await renderCouponImage({
            campaignTitle: campaign.title,
            grantAmount: campaign.grantAmount,
            couponNo: c.couponNo,
            redeemToken: c.redeemToken,
            validFrom: campaign.validFrom,
            validTo: campaign.validTo,
            guideText: campaign.guideText,
            registerBaseUrl: options.registerBaseUrl,
          });
          await writeFile(path.join(dir, "images", `${c.id}.png`), buf);
          processed += 1;
        } catch (e) {
          console.error(`[BokjuCouponImageJob ${jobId}] 쿠폰 ${c.id} 이미지 생성 실패:`, e);
          failedIds.push(c.id);
        }
      })
    );
    await prisma.bokjuCouponImageJob.update({
      where: { id: jobId },
      data: { processedCount: processed, failedCount: failedIds.length },
    });
    await new Promise((resolve) => setImmediate(resolve));
  }

  // 엑셀 번호 목록 생성(항상 전체 쿠폰 기준으로 재생성 — 번호 목록은 가벼우므로 매번 최신화)
  const allCoupons = await prisma.bokjuCoupon.findMany({
    where: { campaignId: job.campaignId },
    select: { id: true, couponNo: true, redeemToken: true, status: true, expiresAt: true },
    orderBy: { id: "asc" },
  });
  const excelRelPath = await buildExcel(job.campaignId, campaign.title, allCoupons, options.registerBaseUrl);

  // ZIP은 이번 작업에서 새로 생성된(혹은 기존에 이미 있는) 이미지 전체를 묶는다.
  const zipRelPath = await buildZip(job.campaignId, allCoupons.map((c) => c.id));

  await prisma.bokjuCouponImageJob.update({
    where: { id: jobId },
    data: {
      status: failedIds.length > 0 ? "FAILED" : "COMPLETED",
      failedCouponIds: failedIds.length > 0 ? JSON.stringify(failedIds) : null,
      zipPath: zipRelPath,
      excelPath: excelRelPath,
      completedAt: new Date(),
    },
  });
}

async function buildExcel(
  campaignId: number,
  campaignTitle: string,
  coupons: { id: number; couponNo: string; redeemToken: string; status: string; expiresAt: Date }[],
  registerBaseUrl: string
): Promise<string> {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet("쿠폰번호목록");
  sheet.columns = [
    { header: "번호", key: "idx", width: 8 },
    { header: "쿠폰ID", key: "id", width: 10 },
    { header: "쿠폰번호", key: "couponNo", width: 26 },
    { header: "등록링크", key: "link", width: 50 },
    { header: "상태", key: "status", width: 12 },
    { header: "만료일", key: "expiresAt", width: 14 },
  ];
  coupons.forEach((c, idx) => {
    sheet.addRow({
      idx: idx + 1,
      id: c.id,
      couponNo: c.couponNo,
      link: `${registerBaseUrl}/coupon/${c.redeemToken}`,
      status: c.status,
      expiresAt: fmtDate(c.expiresAt),
    });
  });
  sheet.getRow(1).font = { bold: true };

  const dir = campaignDir(campaignId);
  await mkdir(dir, { recursive: true });
  const fileName = `coupons_${campaignId}.xlsx`;
  const absPath = path.join(dir, fileName);
  await workbook.xlsx.writeFile(absPath);
  void campaignTitle; // 제목은 시트 상단 메타로 추후 확장 가능 — 현재는 파일명만으로 구분
  return `/uploads/bokju-coupons/campaign_${campaignId}/${fileName}`;
}

async function buildZip(campaignId: number, couponIds: number[]): Promise<string> {
  const dir = campaignDir(campaignId);
  await mkdir(dir, { recursive: true });
  const fileName = `coupon_images_${campaignId}.zip`;
  const absPath = path.join(dir, fileName);

  await new Promise<void>((resolve, reject) => {
    const output = createWriteStream(absPath);
    const archive = archiver("zip", { zlib: { level: 9 } });
    output.on("close", () => resolve());
    archive.on("error", (err) => reject(err));
    archive.pipe(output);

    for (const id of couponIds) {
      const imgPath = path.join(dir, "images", `${id}.png`);
      archive.file(imgPath, { name: `${id}.png` });
    }
    void archive.finalize();
  }).catch(async (e) => {
    // 일부 이미지가 없을 수 있으므로(실패 항목) 존재하는 파일만 다시 추려서 재시도.
    console.error(`[buildZip] 1차 시도 실패, 존재 파일만 재시도:`, e);
    const { readdir } = await import("fs/promises");
    const existing = new Set(await readdir(path.join(dir, "images")).catch(() => [] as string[]));
    await new Promise<void>((resolve, reject) => {
      const output = createWriteStream(absPath);
      const archive = archiver("zip", { zlib: { level: 9 } });
      output.on("close", () => resolve());
      archive.on("error", (err) => reject(err));
      archive.pipe(output);
      for (const id of couponIds) {
        const name = `${id}.png`;
        if (existing.has(name)) archive.file(path.join(dir, "images", name), { name });
      }
      void archive.finalize();
    });
  });

  return `/uploads/bokju-coupons/campaign_${campaignId}/${fileName}`;
}

/**
 * [업체 전용 다운로드] 특정 배정(allocation)에 속한 쿠폰 이미지만 묶어 ZIP으로
 * 반환한다. 캠페인 전체 ZIP(buildZip)을 그대로 주면 다른 업체에 배정된 쿠폰까지
 * 노출되므로, 업체 화면에서는 반드시 이 함수를 통해 본인 배정분만 받는다.
 * 이미지가 아직 생성되지 않은 쿠폰은 건너뛴다(관리자가 이미지 생성을 먼저 해야 함).
 */
export async function buildAllocationZip(
  campaignId: number,
  allocationId: number,
  couponIds: number[]
): Promise<Buffer> {
  const dir = campaignDir(campaignId);
  const archive = archiver("zip", { zlib: { level: 9 } });
  const chunks: Buffer[] = [];
  const done = new Promise<Buffer>((resolve, reject) => {
    archive.on("data", (chunk: Buffer) => chunks.push(chunk));
    archive.on("end", () => resolve(Buffer.concat(chunks)));
    archive.on("error", (err) => reject(err));
  });
  for (const id of couponIds) {
    const imgPath = path.join(dir, "images", `${id}.png`);
    try {
      await readFile(imgPath);
      archive.file(imgPath, { name: `${id}.png` });
    } catch {
      // 해당 쿠폰 이미지가 아직 생성되지 않음 — 건너뜀
    }
  }
  void archive.finalize();
  void allocationId; // 파일명에는 쓰지 않지만 호출부 로깅/추적용으로 인자 유지
  return done;
}

export async function getImageJob(jobId: number) {
  return prisma.bokjuCouponImageJob.findUnique({ where: { id: jobId } });
}

export async function listImageJobsForCampaign(campaignId: number) {
  return prisma.bokjuCouponImageJob.findMany({
    where: { campaignId },
    orderBy: { createdAt: "desc" },
  });
}

export function couponImagePath(campaignId: number, couponId: number): string {
  return couponImageRelPath(campaignId, couponId);
}

export async function readCouponImage(campaignId: number, couponId: number): Promise<Buffer | null> {
  try {
    return await readFile(path.join(campaignDir(campaignId), "images", `${couponId}.png`));
  } catch {
    return null;
  }
}
