// ══════════════════════════════════════════════════════════════════
// WishRoomEngine — 소원방(WishRoom) v2.6 서버 계산식의 단일 소스.
//
// [원본] design_handoff_sintong_wishroom_flutter/app/api.js (목 서버 = 서버 규칙의
// 정답지, [SERVER] 표시 부분). 이 파일은 그 목서버의 계산 로직을 TypeScript로
// 그대로 포팅한 것이다 — 수치·공식을 바꾸지 않는다(변경 시 docs/API_CONTRACT.md §6
// 과 data/wishroom_data.json을 함께 갱신해야 함).
//
// [카탈로그] LEVELS·DECAY·ITEMS·CHARACTERS·THEMES·SLOTS 등은
// src/data/wishroom_data.json(Flutter assets/wishroom/data/와 동일 파일)을
// 그대로 읽는다 — 앱과 서버가 같은 소스를 보므로 값이 어긋나지 않는다.
//
// prisma.$transaction 콜백 안에서 쓰는 것을 전제로 tx를 인자로 받는 함수들은
// luck-pouch-engine.ts 관례를 따른다.
// ══════════════════════════════════════════════════════════════════
import type { Prisma } from "@/generated/prisma/client";
import wishroomData from "@/data/wishroom_data.json";

type Tx = Prisma.TransactionClient;

// ---------------- 카탈로그 타입 ----------------
export interface WrLevel {
  lv: number;
  name: string;
  pts: number;
  change: string;
  fx: string;
}
export interface WrDecayTier {
  minDays: number;
  brightness: number;
  label: string;
  badge: boolean;
  push?: boolean;
}
export interface WrItemEffect {
  type: "devo" | "support" | "cool" | "daily" | "pouch" | "decay";
  v: number;
}
export interface WrItemDef {
  id: string;
  slot: string;
  name: string;
  price?: number | null;
  owned?: boolean;
  freeTier?: boolean;
  glow?: string;
  img?: string;
  kind?: string;
  s?: number;
  aura?: string;
  effect?: WrItemEffect;
  desc?: string;
  theme?: string;
  tier?: string;
  glyph?: string;
  hanja?: string;
  color?: string;
  reward?: number;
}
export interface WrCharacterDef {
  id: string;
  code: string;
  name: string;
  title: string;
  grade: string;
  gender: string;
  emblem?: string;
  price: number;
  behaviors: string[];
  job?: string;
  type?: string;
  personality?: string;
  likes?: string;
  aura?: string;
  line?: string;
}
export interface WrSlotDef {
  id: string;
  label: string;
  max: number;
  glyph: string;
}

interface WishRoomDataShape {
  LEVELS: WrLevel[];
  DECAY: WrDecayTier[];
  DEVOTION_RULE: { dailyLimit: number; cooldownSec: number; bonusAt: number; bonusPouch: number };
  CHARACTERS: WrCharacterDef[];
  SLOTS: WrSlotDef[];
  ITEMS: WrItemDef[];
  WISH_COLORS: Array<{ id: string; label: string; hanja: string; color: string; deep: string; desc: string }>;
  PAPERS: Array<{ id: string; label: string; bg: string[]; ink: string; sub: string }>;
  THEMES: Array<{ id: string; label: string; glyph: string; hanja: string; sub: string; color: string; deep: string; light: string; desc: string; room: string; outfitHint?: string }>;
  OUTFIT_ART: Record<string, Record<string, string>>;
  OUTFIT_PRICE: Record<string, number>;
  THEME_ITEMS?: unknown;
  TIER?: unknown;
  RITUAL: Record<string, { verb: string; icon: string; pose: string; done: string; src: string; lines: Array<[string, string | null]>; quotes: Array<[string, string]> }>;
  POSE_ART: Record<string, string>;
  EFFECT_CAP: { devo: number; support: number; cool: number; daily: number; pouch: number; decay: number };
  EFFECT_LABEL?: unknown;
  EFFECT_SHORT?: unknown;
  SUPPORT_REWARDS: Array<{ at: number; reward: string; icon: string; item: string; desc: string }>;
  EARN: Array<{ id: string; label: string; amount: number; limit: number; sub: string; auto?: boolean }>;
  WISH_TEMPLATES?: unknown;
  SEED_ROOMS?: unknown;
  SEED_COMMENTS?: unknown;
  NICKS: string[];
}

export const WR: WishRoomDataShape = wishroomData as unknown as WishRoomDataShape;

const DAY_MS = 86400000;

// ---------------- 시간 ----------------
/** KST 자정 기준 날짜 문자열 'YYYY-MM-DD' */
export function kstDate(t: number = Date.now()): string {
  return new Date(t + 9 * 3600e3).toISOString().slice(0, 10);
}

/** 'YYYY-MM-DD' 두 날짜 사이의 일수 차 (KST 날짜 기준) */
export function dayDiff(from: string, to: string): number {
  return Math.round((Date.parse(to + "T00:00:00Z") - Date.parse(from + "T00:00:00Z")) / DAY_MS);
}

export function addYears(d: string, y: number): string {
  const [Y, M, D2] = d.split("-").map(Number);
  const t = new Date(Date.UTC(Y + y, M - 1, D2));
  return t.toISOString().slice(0, 10);
}

/** 두 Date 사이의 "일수 경과"(절대 ms 차이 기준, absentDays 계산용) */
export function daysBetween(from: Date, to: Date): number {
  return Math.floor((to.getTime() - from.getTime()) / DAY_MS);
}

// ---------------- 레벨 · 포인트 ----------------
export function levelOf(pts: number): number {
  let l = 1;
  for (const L of WR.LEVELS) {
    if (pts >= L.pts) l = L.lv;
  }
  return l;
}

export function levelDef(lv: number): WrLevel {
  return WR.LEVELS[Math.max(0, Math.min(WR.LEVELS.length - 1, lv - 1))];
}

/** 성장 포인트 = 정성 + 응원×0.5 + 받은 복주머니×10 + bonusPts(아이템 기운 누적) [SERVER] */
export function calcPoints(params: { devotionCount: number; supportCount: number; pouchReceived: number; bonusPts: number }): number {
  return params.devotionCount + params.supportCount * 0.5 + params.pouchReceived * 10 + (params.bonusPts || 0);
}

// ---------------- 감쇠 ----------------
export function decayOf(days: number): WrDecayTier {
  let s = WR.DECAY[0];
  for (const d of WR.DECAY) {
    if (days >= d.minDays) s = d;
  }
  return s;
}

// ---------------- 장착 아이템 기운 합산 [SERVER] ----------------
export interface EffectsResult {
  devo: number;
  support: number;
  cool: number;
  daily: number;
  pouch: number;
  decay: number;
  src: Array<{ id: string; name: string; type: string; v: number; match: boolean }>;
}

export interface EquipShape {
  CANDLE?: string;
  FLOWER?: string;
  BACKGROUND?: string;
  SPECIAL?: string;
  DECORATION?: string[];
  SEAL?: string[];
  THEME?: string[];
}

const ITEM_BY_ID = new Map(WR.ITEMS.map((i) => [i.id, i]));
export function findItem(id: string): WrItemDef | undefined {
  return ITEM_BY_ID.get(id);
}

/** 장착 아이템 effect 합. aura === wishColor 이면 ×1.5(all 제외). 항목별 EFFECT_CAP 적용. [SERVER] */
export function effectsOf(equip: EquipShape, wishColor: string): EffectsResult {
  const ids = [
    equip.CANDLE,
    equip.FLOWER,
    equip.BACKGROUND,
    equip.SPECIAL,
    ...(equip.DECORATION || []),
    ...(equip.SEAL || []),
    ...(equip.THEME || []),
  ].filter((x): x is string => !!x);

  const sum = { devo: 0, support: 0, cool: 0, daily: 0, pouch: 0, decay: 0 };
  const src: EffectsResult["src"] = [];

  for (const id of ids) {
    const it = findItem(id);
    if (!it || !it.effect) continue;
    const match = it.aura === "all" || (!!wishColor && it.aura === wishColor);
    const v = it.effect.type === "daily" ? it.effect.v : Math.round(it.effect.v * (match && it.aura !== "all" ? 1.5 : 1));
    if (it.effect.type === "decay") sum.decay = Math.max(sum.decay, v);
    else (sum as Record<string, number>)[it.effect.type] += v;
    src.push({ id, name: it.name, type: it.effect.type, v, match: match && it.aura !== "all" });
  }

  (Object.keys(sum) as Array<keyof typeof sum>).forEach((k) => {
    sum[k] = Math.min(sum[k], WR.EFFECT_CAP[k]);
  });

  return { ...sum, src };
}

// ---------------- 텍스트 필터 · 봉인일 검증 [SERVER] ----------------
export class WishRoomError extends Error {
  status: number;
  code: string;
  extra: Record<string, unknown>;
  constructor(status: number, code: string, message: string, extra: Record<string, unknown> = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }
}

const PROFANITY = ["씨발", "시발", "병신", "개새", "fuck", "광고문의", "카톡친추"];
const PII_PATTERNS = [/01[016789][- .]?\d{3,4}[- .]?\d{4}/, /\d{2,3}-\d{3,4}-\d{4}/, /(로|길)\s?\d+/, /(동|호)\s?\d{2,4}호?/];

export function filterText(text: string | undefined | null, force: boolean): void {
  if (!text || !text.trim()) throw new WishRoomError(400, "EMPTY", "내용을 적어주세요");
  if (PROFANITY.some((w) => text.toLowerCase().includes(w))) {
    throw new WishRoomError(422, "FILTERED", "담을 수 없는 표현이 포함되어 있어요");
  }
  if (!force && PII_PATTERNS.some((rx) => rx.test(text))) {
    throw new WishRoomError(422, "PII_WARNING", "전화번호나 주소처럼 보이는 내용이 있어요");
  }
}

export function checkSealDate(s: string | null | undefined): string {
  const today = kstDate();
  if (!s || !/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    throw new WishRoomError(400, "SEAL_DATE_REQUIRED", "봉인 날짜를 골라주세요");
  }
  if (dayDiff(today, s) < 1) {
    throw new WishRoomError(400, "SEAL_DATE_PAST", "봉인 날짜는 오늘 이후로 골라주세요");
  }
  if (s > addYears(today, 3)) {
    throw new WishRoomError(400, "SEAL_DATE_TOO_FAR", "봉인 날짜는 3년 이내로 골라주세요");
  }
  return s;
}

// ---------------- 후기 어뷰징 검사 [SERVER] ----------------
export function reviewAbuseFlags(text: string, recentTexts: string[], recentCount60s: number): string[] {
  const t = (text || "").trim();
  const s = t.replace(/\s/g, "");
  const flags: string[] = [];
  if (s.length < 20) flags.push("TOO_SHORT");
  if (/(.)\1{5,}/.test(s)) flags.push("REPEAT_CHAR");
  if (/^[0-9]+$/.test(s)) flags.push("NUMBERS_ONLY");
  const jamoCount = (s.match(/[ㄱ-ㅎㅏ-ㅣ]/g) || []).length;
  if (/^[ㄱ-ㅎㅏ-ㅣ]+$/.test(s) || jamoCount > s.length * 0.4) flags.push("JAMO");
  if (/^[a-zA-Z]+$/.test(s) && new Set(s.toLowerCase()).size < 5) flags.push("GIBBERISH");
  if (s.includes("가나다라마바사") || s.includes("abcdefg") || s.includes("qwerty") || s.includes("asdf")) flags.push("SEQUENCE");
  for (let L = 3; L <= Math.floor(s.length / 3); L++) {
    const u = s.slice(0, L);
    if (u.repeat(Math.ceil(s.length / L)).slice(0, s.length) === s) {
      flags.push("REPEAT_PHRASE");
      break;
    }
  }
  if (new Set(s).size < Math.min(8, s.length / 3)) flags.push("LOW_VARIETY");
  if (recentTexts.some((r) => r.replace(/\s/g, "") === s)) flags.push("DUPLICATE");
  if (recentCount60s >= 2) flags.push("RAPID");
  return [...new Set(flags)];
}

// ---------------- 분당 요청 제한 [SERVER] — 호출부가 최근 타임스탬프 배열을 관리 ----------------
export function checkRateLimit(timestampsMs: number[], nowMs: number): void {
  const recent = timestampsMs.filter((x) => nowMs - x < 60e3);
  if (recent.length >= 10) {
    throw new WishRoomError(429, "RATE_LIMIT", "잠시 숨을 고르고 다시 시도해주세요");
  }
}

// ---------------- Equip JSON 직렬화 ----------------
export function parseEquip(json: string): EquipShape {
  try {
    const e = JSON.parse(json || "{}");
    return {
      CANDLE: e.CANDLE ?? "c_basic",
      FLOWER: e.FLOWER ?? "f_none",
      BACKGROUND: e.BACKGROUND ?? "b_night",
      SPECIAL: e.SPECIAL ?? "s_none",
      DECORATION: Array.isArray(e.DECORATION) ? e.DECORATION : [],
      SEAL: Array.isArray(e.SEAL) ? e.SEAL : [],
      THEME: Array.isArray(e.THEME) ? e.THEME : [],
    };
  } catch {
    return { CANDLE: "c_basic", FLOWER: "f_none", BACKGROUND: "b_night", SPECIAL: "s_none", DECORATION: [], SEAL: [], THEME: [] };
  }
}

export function serializeEquip(e: EquipShape): string {
  return JSON.stringify({
    CANDLE: e.CANDLE ?? "c_basic",
    FLOWER: e.FLOWER ?? "f_none",
    BACKGROUND: e.BACKGROUND ?? "b_night",
    SPECIAL: e.SPECIAL ?? "s_none",
    DECORATION: e.DECORATION ?? [],
    SEAL: e.SEAL ?? [],
    THEME: e.THEME ?? [],
  });
}

export interface LayoutPosShape {
  x: number;
  y: number;
  s: number;
}
export function parseLayout(json: string): Record<string, LayoutPosShape> {
  try {
    return JSON.parse(json || "{}");
  } catch {
    return {};
  }
}
export function serializeLayout(l: Record<string, LayoutPosShape>): string {
  return JSON.stringify(l);
}

// ---------------- outfitNow 계산 [SERVER] ----------------
/** Room.outfitNow = (outfit ?? theme) 의상 그림이 있고 보유했으면 그 테마, 아니면 free. */
export function outfitNowOf(params: { charCode: string; outfit: string | null; theme: string; ownedOutfits: string[]; isOwner: boolean }): string {
  const want = params.outfit || params.theme || "free";
  const art = WR.OUTFIT_ART[params.charCode] && WR.OUTFIT_ART[params.charCode][want];
  const own = want === "free" || params.ownedOutfits.includes(`${params.charCode}:${want}`) || !params.isOwner;
  return art && own ? want : "free";
}

// ---------------- WishRoom row -> DTO (roomView 포팅) ----------------
export interface WishRoomRow {
  id: number;
  userId: number;
  charCode: string;
  text: string;
  theme: string;
  outfit: string | null;
  wishColor: string;
  paper: string;
  visibility: string;
  region: string;
  status: string;
  points: number;
  level: number;
  devotionCount: number;
  supportCount: number;
  pouchReceived: number;
  commentCount: number;
  devotionsToday: number;
  devotionsResetDate: string | null;
  lastDevotionAt: Date | null;
  lastActiveAt: Date;
  equipJson: string;
  layoutJson: string;
  completedAt: Date | null;
  cancelUntil: Date | null;
  sealUntil: string | null;
  capsule: string | null;
  outcome: string | null;
  wishStatus: string | null;
  shareToken: string | null;
  snapshot: string | null;
  createdAt: Date;
  owner?: { nickname: string } | null;
  bonusPts?: number; // 아이템 기운 보너스 누적(서버 계산용, DB에는 points에 통합 반영됨 — 캐시 전용 필드 아님. 별도 계산식에서만 사용)
}

export interface RoomViewOptions {
  currentUserId: number | null;
  ownedOutfits: string[];
  supportedToday: boolean;
  supportRewardClaims: Array<{ at: number; itemCode: string | null }>;
  nowMs?: number;
}

export function roomView(r: WishRoomRow, opts: RoomViewOptions) {
  const now = opts.nowMs ?? Date.now();
  const lvl = levelDef(r.level);
  const next = WR.LEVELS[r.level] || null;
  const isMine = r.userId === opts.currentUserId;
  const days = isMine ? daysBetween(r.lastActiveAt, new Date(now)) : 0;
  const decay = decayOf(days);
  const equip = parseEquip(r.equipJson);
  const layout = parseLayout(r.layoutJson);
  const fx = effectsOf(equip, r.wishColor);
  const today = kstDate(now);
  const devoToday = r.devotionsResetDate === today ? r.devotionsToday : 0;
  const dailyLimit = WR.DEVOTION_RULE.dailyLimit + fx.daily;
  const cooldownSec = WR.DEVOTION_RULE.cooldownSec - fx.cool;

  const outfitNow = outfitNowOf({
    charCode: r.charCode,
    outfit: r.outfit,
    theme: r.theme,
    ownedOutfits: opts.ownedOutfits,
    isOwner: isMine,
  });

  const sealedOn = kstDate(r.createdAt.getTime());
  const sealDaysLeft = r.sealUntil ? dayDiff(today, r.sealUntil) : null;
  const sealTotalDays = r.sealUntil ? dayDiff(sealedOn, r.sealUntil) : null;

  return {
    id: `wr_${r.id}`,
    ownerId: String(r.userId),
    owner: r.owner?.nickname ?? "",
    region: r.region,
    text: r.text,
    char: r.charCode,
    status: r.status,
    visibility: r.visibility,
    theme: r.theme,
    outfit: r.outfit,
    outfitNow,
    wishColor: r.wishColor,
    paper: r.paper,
    devotionCount: r.devotionCount,
    supportCount: r.supportCount,
    pouchReceived: r.pouchReceived,
    level: r.level,
    commentCount: r.commentCount,
    points: r.points,
    levelName: lvl.name,
    curLevelPts: lvl.pts,
    nextLevelPts: next ? next.pts : null,
    brightness: Math.max(decay.brightness, fx.decay / 100),
    decayLabel: decay.label,
    decayBadge: decay.badge,
    isMine,
    supportedToday: opts.supportedToday,
    absentDays: days,
    devotionsToday: devoToday,
    devotionsRemaining: Math.max(0, dailyLimit - devoToday),
    dailyLimit,
    cooldownSec,
    daysLit: Math.max(1, Math.floor((now - r.createdAt.getTime()) / DAY_MS) + 1),
    cooldownUntil: r.lastDevotionAt ? r.lastDevotionAt.getTime() + cooldownSec * 1000 : 0,
    completedAt: r.completedAt ? r.completedAt.getTime() : null,
    cancelUntil: r.completedAt ? r.completedAt.getTime() + 7 * DAY_MS : null,
    createdAt: r.createdAt.getTime(),
    equip,
    layout,
    effects: fx,
    rewards: isMine
      ? WR.SUPPORT_REWARDS.map((s) => {
          const claim = opts.supportRewardClaims.find((c) => c.at === s.at);
          return {
            ...s,
            reached: r.supportCount >= s.at,
            claimed: !!claim,
            got: claim?.itemCode ?? null,
          };
        })
      : undefined,
    sealUntil: r.sealUntil,
    sealedOn,
    capsule: r.capsule,
    sealDaysLeft,
    sealTotalDays,
    capsuleDue: !!(r.sealUntil && r.capsule === "LOCKED" && sealDaysLeft !== null && sealDaysLeft <= 0),
    outcome: r.outcome,
    wishStatus: r.wishStatus,
    shareToken: r.shareToken,
    snapshot: r.snapshot ? JSON.parse(r.snapshot) : null,
  };
}

// ---------------- 공용 DB 조회 헬퍼 ----------------
export async function getRoomOrThrow(tx: Tx, id: number) {
  const r = await tx.wishRoom.findUnique({ where: { id }, include: { user: { select: { nickname: true } } } });
  if (!r || r.deletedAt != null) {
    throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
  }
  return r;
}

export async function getOwnedOutfits(tx: Tx, userId: number): Promise<string[]> {
  const rows = await tx.wishRoomOutfitOwned.findMany({ where: { userId }, select: { charCode: true, theme: true } });
  return rows.map((r) => `${r.charCode}:${r.theme}`);
}

export async function getSupportedToday(tx: Tx, roomId: number, userId: number | null, nowMs: number): Promise<boolean> {
  if (userId == null) return false;
  const today = kstDate(nowMs);
  const row = await tx.wishRoomSupport.findUnique({
    where: { roomId_userId_dateKey: { roomId, userId, dateKey: today } },
  });
  return !!row;
}

export async function getSupportRewardClaims(tx: Tx, roomId: number) {
  return tx.wishRoomSupportRewardClaim.findMany({ where: { roomId }, select: { at: true, itemCode: true } });
}

/** roomView까지 완전히 채워서 반환하는 헬퍼(여러 라우트에서 공용으로 사용). */
export async function buildRoomView(tx: Tx, roomRow: WishRoomRow, currentUserId: number | null, nowMs: number = Date.now()) {
  const [ownedOutfits, supportedToday, claims] = await Promise.all([
    getOwnedOutfits(tx, roomRow.userId),
    getSupportedToday(tx, roomRow.id, currentUserId, nowMs),
    getSupportRewardClaims(tx, roomRow.id),
  ]);
  return roomView(roomRow, {
    currentUserId,
    ownedOutfits,
    supportedToday,
    supportRewardClaims: claims,
    nowMs,
  });
}

// ---------------- 보유 판정(아이템/캐릭터) ----------------
/**
 * price===0 또는 freeTier인 아이템은 구매 기록 없이도 항상 "보유"로 간주한다
 * (app/api.js freshDb()의 `ownedItems: D.ITEMS.filter(i => i.owned).map(...)` 시드와
 * 동치 — c_basic/f_none/b_night/s_none(가격0, 방 생성 시 기본 장착) + t_bible 등
 * freeTier 테마 소품 4종). 실제 DB(WishRoomItemOwned)에는 "구매한" 유료 아이템만 기록한다.
 */
export function isAlwaysOwnedItem(item: WrItemDef): boolean {
  return !!item.freeTier || item.price === 0;
}

export async function getOwnedItemIds(tx: Tx, userId: number): Promise<Set<string>> {
  const purchased = await tx.wishRoomItemOwned.findMany({ where: { userId }, select: { itemId: true } });
  const set = new Set(purchased.map((p) => p.itemId));
  for (const it of WR.ITEMS) {
    if (isAlwaysOwnedItem(it)) set.add(it.id);
  }
  return set;
}

/** F00/M00(price:0, grade:basic)은 항상 보유로 간주 — 그 외는 WishRoomCharacterOwned 기록 필요. */
export function isAlwaysOwnedCharacter(c: WrCharacterDef): boolean {
  return c.price === 0;
}

export async function getOwnedCharacterIds(tx: Tx, userId: number): Promise<Set<string>> {
  const purchased = await tx.wishRoomCharacterOwned.findMany({ where: { userId }, select: { charCode: true } });
  const set = new Set(purchased.map((p) => p.charCode));
  for (const c of WR.CHARACTERS) {
    if (isAlwaysOwnedCharacter(c)) set.add(c.code ?? c.id);
  }
  return set;
}

// ---------------- Me DTO (meView 포팅) ----------------
export interface MeRow {
  userId: number;
  nickname: string;
  joinedAt: Date; // User.createdAt
  pouch: number; // Wallet.balance
  repCharCode: string;
  skipIntro: boolean;
  wallpaper?: Record<string, unknown> | null;
}

export interface MeViewOptions {
  ownedChars: string[];
  ownedItems: string[];
  ownedOutfits: string[];
  giftToday: number;
  unreadCount: number;
  earnToday: Record<string, number>;
  nowMs?: number;
}

export function meView(m: MeRow, opts: MeViewOptions) {
  const now = opts.nowMs ?? Date.now();
  const today = kstDate(now);
  return {
    id: String(m.userId),
    nick: m.nickname,
    pouch: m.pouch,
    repChar: m.repCharCode,
    ownedChars: opts.ownedChars,
    ownedItems: opts.ownedItems,
    ownedOutfits: opts.ownedOutfits,
    settings: { skipIntro: m.skipIntro },
    accountAgeDays: daysBetween(m.joinedAt, new Date(now)),
    earnToday: opts.earnToday,
    giftToday: opts.giftToday,
    wallpaper: m.wallpaper ?? null,
    unread: opts.unreadCount,
    today,
    now,
  };
}
