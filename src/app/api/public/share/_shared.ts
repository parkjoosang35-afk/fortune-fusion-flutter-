// 결과 공유(Share) 공개 API 공용 헬퍼 — sintong-share-proposal.pdf 대응.
//
// [설계 원칙] guinji/_shared.ts, wishes/_shared.ts와 동일한 프로젝트 컨벤션을
// 따른다: requireUser()는 JWT Bearer 인증(서버최종판단), CORS_HEADERS는
// 공개 API 공통, publicId 포맷은 접두사+숫자(`sr_${id}`류)가 아니라 이
// 도메인 특성상 곧 shareId 자체가 공개 식별자이므로 별도 인코딩이 필요
// 없다(shareId는 이미 crypto 랜덤 문자열).
import { NextResponse } from "next/server";
import { randomBytes } from "crypto";
import { mkdir, readFile, writeFile, unlink } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import { authenticateRequest } from "@/lib/user-auth";
import {
  SHARE_CONTENT_TYPES,
  isValidShareContentType,
  type ShareContentType,
} from "@/lib/share-og-config";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export const CORS_HEADERS_WITH_AUTH = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

/**
 * [2027-02 6개 카테고리 통일] 결과 타입 화이트리스트 — 중앙 설정
 * `@/lib/share-og-config`의 OG_CONFIG 키를 그대로 재노출한다(fortune은
 * 레거시 하위호환 전용으로 포함되어 있음 — 상세 주석은 share-og-config.ts
 * 참고). 이 배열 자체를 더 이상 여기서 직접 선언하지 않는다(중복 제거).
 */
export const SHARE_RESULT_TYPES = SHARE_CONTENT_TYPES;
export type ShareResultType = ShareContentType;

export const isValidResultType = isValidShareContentType;

export async function requireUser(
  request: Request
): Promise<{ userId: number; nickname: string } | null> {
  const payload = await authenticateRequest(request);
  if (!payload) return null;
  return { userId: payload.userId, nickname: payload.nickname };
}

export function unauthorizedResponse() {
  return NextResponse.json(
    { success: false, error: "로그인이 필요합니다." },
    { status: 401, headers: CORS_HEADERS }
  );
}

/**
 * [보안 원칙 — NFR-03] shareId는 이 링크에 대한 유일한 접근 통제 수단이므로
 * 비순차·추측 불가능해야 한다. 혼동되기 쉬운 문자(0/O, 1/l/I)를 제외한
 * 32자 알파벳으로 10자리를 생성한다(62^10 조합에 준하는 충돌 저항성).
 * crypto.randomBytes 기반이라 guinji generateGuinjiToken()과 동일한
 * 신뢰 수준을 가진다.
 */
const SHARE_ID_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ";
export function generateShareId(length = 10): string {
  const bytes = randomBytes(length);
  let out = "";
  for (let i = 0; i < length; i++) {
    out += SHARE_ID_ALPHABET[bytes[i] % SHARE_ID_ALPHABET.length];
  }
  return out;
}

/**
 * [개인정보 원칙] payload에 대한 문자열 길이 상한. 과도하게 큰 payload를
 * 막아 DB 부하 및 실수로 원본 민감정보(사진 base64 등)가 통째로 들어가는
 * 사고를 1차 방어한다(가벼운 화이트리스트 표시값만 들어와야 정상).
 */
// 전체 결과 텍스트를 보존한다. OG 설명 120자 제한은 그대로 별도 적용한다.
// 이미지 base64 업로드 용도가 아닌 텍스트 JSON의 유한 상한.
export const SHARE_PAYLOAD_MAX_LENGTH = 200000;
export const SHARE_TITLE_MAX_LENGTH = 60;
export const SHARE_DESCRIPTION_MAX_LENGTH = 120;

// 비공개 디렉터리: 반드시 공유 레코드 활성 상태를 검사하는 GET을 통해서만 제공.
export const ORIGINAL_PNG_MAX_BYTES = 8 * 1024 * 1024;
const snapshotDirectory = () => process.env.SHARE_SNAPSHOT_DIR ?? path.join(process.cwd(), 'var', 'share-snapshots');
const snapshotPath = (shareId: string) => {
  if (!/^[23456789abcdefghjkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ]{10}$/.test(shareId)) throw new Error('INVALID_SHARE_ID');
  return path.join(snapshotDirectory(), `${shareId}.png`);
};
export function originalImagePath(shareId: string) {
  return `/api/public/share/${shareId}?original=1`;
}
export function hasOriginalImage(imageUrl: string | null, shareId: string) {
  if (!imageUrl) return false;
  try {
    const url = new URL(imageUrl, 'http://localhost');
    return url.pathname === `/api/public/share/${shareId}` && url.search === '?original=1';
  } catch { return false; }
}
export async function validateOriginalPng(value: unknown): Promise<Buffer> {
  if (typeof value !== 'string' || value.length === 0 || value.length > Math.ceil(ORIGINAL_PNG_MAX_BYTES / 3) * 4 || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) throw new Error('INVALID_ORIGINAL_PNG');
  const bytes = Buffer.from(value, 'base64');
  if (bytes.length > ORIGINAL_PNG_MAX_BYTES || bytes.toString('base64') !== value || !bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) throw new Error('INVALID_ORIGINAL_PNG');
  const image = sharp(bytes, { limitInputPixels: 24000000 });
  const metadata = await image.metadata();
  if (metadata.format !== 'png' || !metadata.width || !metadata.height || metadata.width * metadata.height > 24000000 || (metadata.pages ?? 1) !== 1) throw new Error('INVALID_ORIGINAL_PNG');
  await image.stats(); // 끝까지 실제 디코딩하여 손상 이미지 거절. 저장 바이트는 변경하지 않는다.
  return bytes;
}
export async function writeOriginalPng(shareId: string, bytes: Buffer) {
  await mkdir(snapshotDirectory(), { recursive: true, mode: 0o700 });
  await writeFile(snapshotPath(shareId), bytes, { flag: 'wx', mode: 0o600 });
}
export const readOriginalPng = (shareId: string) => readFile(snapshotPath(shareId));
export async function removeOriginalPng(shareId: string) {
  try { await unlink(snapshotPath(shareId)); } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
  }
}
