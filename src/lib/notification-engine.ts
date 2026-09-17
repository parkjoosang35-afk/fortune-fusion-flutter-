// ══════════════════════════════════════════════════════════════════
// NotificationEngine — 인앱 알림(알림센터/벨) 생성의 단일 소스.
//
// [배경] `shintongbangtong-noti-dev.pdf`(알림/푸시 개발기획서)는 별도의
// FCM 전용 알림 서버(Redis 규칙엔진, dedup/coalescing/quiet-hours 등)를
// 새로 만드는 대형 설계였으나, 이 프로젝트에는 OS 네이티브 푸시(FCM)를
// 실제로 발송할 서비스 계정 키가 전혀 없다(package.json에 firebase-admin
// 없음, .env에 FCM 키 없음). 대신 이미 존재하는 `notifications` 테이블 +
// `/api/public/notifications` 조회 API + Flutter NotificationProvider를
// 그대로 활용해 "이벤트 발생 시 실제로 알림센터에 알림이 쌓이는 것"을
// 실사용으로 구현한다(발명 없이 기존 자산 연결만 추가).
//
// [단일 진실 소스 패턴] luck-pouch-engine.ts와 동일하게, 알림을 생성하는
// 모든 이벤트(응원/댓글/복주머니 등)는 이 파일의 createNotification()만
// 호출한다 — 각 라우트에 알림 생성 로직을 복붙하지 않는다.
//
// prisma.$transaction 콜백 안에서 사용하는 것을 전제로, tx(트랜잭션
// 클라이언트)를 첫 인자로 받는다(luck-pouch-engine.ts와 동일 관례).
// ══════════════════════════════════════════════════════════════════
import type { Prisma } from "@/generated/prisma/client";

type Tx = Prisma.TransactionClient;

/**
 * [NotificationPreference.category 확정 화이트리스트] 04A N-3 명시 값
 * (marketing/fortune_update/matching/community) — seed_notification_settings.ts와
 * 동일. 새 카테고리를 발명하지 않고 소원방 이벤트(응원/댓글/복주머니)는
 * 모두 "community"로 분류한다.
 */
export type NotificationCategory =
  | "marketing"
  | "fortune_update"
  | "matching"
  | "community";

export interface CreateNotificationInput {
  /** 알림을 받을 사용자. */
  userId: number;
  category: NotificationCategory;
  title: string;
  body: string;
  /** 탭 시 이동할 목적지. 예: "wish:w_123" (콜론 앞이 타입, 뒤가 대상 id). */
  deepLink?: string;
  templateId?: number;
}

export interface CreateNotificationResult {
  /** 알림이 실제로 생성되었는지. 사용자가 해당 category를 꺼둔 경우 false. */
  created: boolean;
  notificationId: number | null;
}

/**
 * 알림 생성 전 `NotificationPreference`(userId, category)로 수신 거부
 * 여부를 확인한다. 레코드가 없으면(=한 번도 설정을 건드리지 않음) 기본
 * 수신 동의 상태로 간주한다(schema.prisma의 `isEnabled @default(true)`와
 * 동일한 기본값 원칙).
 */
async function isCategoryEnabled(
  tx: Tx,
  userId: number,
  category: NotificationCategory
): Promise<boolean> {
  const pref = await tx.notificationPreference.findUnique({
    where: { userId_category: { userId, category } },
  });
  if (!pref || pref.deletedAt != null) return true;
  return pref.isEnabled;
}

/**
 * 알림센터(`notifications` 테이블)에 실제로 알림 1건을 기록한다.
 *
 * - 수신자가 해당 category 알림을 꺼둔 경우 아무것도 생성하지 않고
 *   `{ created: false, notificationId: null }`을 반환한다(호출부는 이
 *   결과로 실패 처리를 할 필요 없음 — 정상적인 opt-out 케이스).
 * - 이 함수는 부수효과(insert)만 수행하며, 트랜잭션 커밋/롤백은 호출부의
 *   `$transaction` 블록이 책임진다(luck-pouch-engine.ts와 동일 관례).
 */
export async function createNotification(
  tx: Tx,
  input: CreateNotificationInput
): Promise<CreateNotificationResult> {
  const enabled = await isCategoryEnabled(tx, input.userId, input.category);
  if (!enabled) {
    return { created: false, notificationId: null };
  }

  const notification = await tx.notification.create({
    data: {
      userId: input.userId,
      templateId: input.templateId ?? null,
      title: input.title,
      body: input.body,
      category: input.category,
      deepLink: input.deepLink ?? null,
    },
  });

  return { created: true, notificationId: notification.id };
}

/** 소원방 알림 딥링크 포맷 — Flutter가 파싱할 "wish:{publicId}" 문자열. */
export function wishDeepLink(wishPublicId: string): string {
  return `wish:${wishPublicId}`;
}
