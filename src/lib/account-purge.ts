// ─────────────────────────────────────────────────────────────────────────
// 6-7-4-B-4: 회원 탈퇴 데이터 파기 로직 라이브러리
//
// [예외 승인 근거] 이 파일은 "신규기능개발 금지" 원칙의 명시적 예외로,
// 사용자가 개인정보처리방침 준수를 위해 직접 요청한 "탈퇴 후 실제 데이터 파기
// 구현"(옵션 B)에 해당한다. 6-7-4-B-3 조사에서 확정된 Critical 이슈
// (`UserWithdrawalLog.dataPurgeScheduledAt`만 기록되고 실제 파기가 전혀
// 일어나지 않음)를 해소하기 위한 최소 범위 구현이다.
//
// [파기 방식 원칙]
// Prisma schema 전수조사 결과 User와 연결된 34개 이상의 테이블 중 32개가
// non-nullable `userId` FK를 가지고 있어 User row의 물리적 완전삭제(hard
// delete)는 불가능하다(FK 제약 위반). 개인정보보호법상 "복구 불가능한
// 비식별화(익명화)"도 파기로 인정되므로, 아래 4개 버킷으로 분류해 처리한다.
//
//   [A] HARD DELETE  — 생년월일시 등 극도로 민감한 정보이거나 1:1 상담/궁합
//       콘텐츠처럼 사용자 본인 외 제3자 표시 가치가 없는 데이터.
//       대상: UserProfile, FortuneRequest/FortuneResult,
//             ConsultationSession/ConsultationMessage/ConsultationReview,
//             CompatibilityRequest(본인이 요청자인 건)/CompatibilityResult
//
//   [B] ANONYMIZE    — 행(row)은 남기되 식별정보 필드만 비식별화.
//       대상: User(email/phone/nickname/passwordHash/gender),
//             MatchingProfile(introText/preferences/isPublic)
//       CompatibilityRequest(본인이 대상자였던 건)의 targetUserId는
//       nullable이므로 null 처리해 연결만 끊는다.
//
//   [C] RETAIN AS-IS — Wish/Comment/CommunityPost/Like/Report/MatchingLike/
//       MatchingPair/Friend/Follow/ChatRoom/ChatMessage/AmuletGift/
//       UserAmulet/AmuletCollection/GiftcardIssue/CouponIssue/
//       RankingSnapshot/UserAchievement/UserMission/Attendance/
//       EventParticipation/UserSubscription/Notification/
//       NotificationPreference/PushToken/UserPass/PassCategoryUsage/
//       OpenPassAdRewardLog/FortuneAdWatchLog/LuckPouchWallet/
//       LuckPouchHistory — 이 테이블들은 userId FK 외에 별도의 식별정보
//       (이름/이메일/전화번호) 컬럼을 갖지 않으므로, [B]에서 User 자체가
//       비식별화되면 자동으로 "작성자를 알 수 없는" 상태가 된다. 별도
//       처리를 하지 않는 것이 최소수정 원칙에 부합한다.
//
//   [D] 법정 보존     — 전자상거래법 시행령 §6(결제기록 5년) 등 법령상
//       보존의무가 있는 재무 원장. 절대 삭제/수정하지 않는다.
//       대상: Payment(04A 명시: deletedAt 애플리케이션 레벨 사용 금지),
//             Wallet/PointHistory(원장 무결성 보존 — WalletService 외
//             직접 UPDATE 금지 원칙과 동일 맥락)
//
// [인증정보 즉시무효화] withdraw API가 이미 `status: "withdrawn"`으로
// 전환하며, `/api/public/auth/login`·`/api/public/auth/me` 양쪽 모두
// `status !== "active"`를 체크해 재로그인/세션복원을 즉시 차단한다(기존
// 인프라, 이번 파일에서 변경하지 않음). 이 파기 로직은 여기에 더해
// `passwordHash`를 null로 만들어 방어적으로 한 번 더 로그인을 원천 차단한다.
//
// [실행 시점] 이 라이브러리 자체는 즉시 파기를 수행하지 않는다.
// `purgeDueAccounts()`가 `dataPurgeScheduledAt <= now`인 건만 골라
// `purgeUserData()`를 호출하는 구조이며, 실제 트리거는 6-7-4-B-4의
// 별도 배치 스크립트(Task #2, `scripts/purge-withdrawn-accounts.ts`)이다.
// ─────────────────────────────────────────────────────────────────────────

import "server-only";
import { prisma } from "@/lib/db";

export interface PurgeSummary {
  userId: number;
  skipped: boolean;
  reason?: string;
  deletedCounts?: Record<string, number>;
}

/**
 * 단일 회원의 데이터를 파기(비식별화+하드삭제)한다.
 *
 * 멱등성(idempotent) 보장: 이미 파기된 계정(`dataPurgedAt` not null)이거나
 * `status !== "withdrawn"`인 계정은 아무 것도 하지 않고 skipped=true를 반환한다.
 *
 * @param userId 파기 대상 회원 ID
 * @param options.force true면 `dataPurgeScheduledAt` 유예기간을 무시하고 즉시 파기한다.
 *   (관리자가 법적 삭제요청 등으로 즉시 파기를 수행해야 하는 경우를 위한 안전판.
 *    이번 6-7-4-B-4 범위의 배치 스크립트는 force를 사용하지 않는다.)
 */
export async function purgeUserData(
  userId: number,
  options: { force?: boolean } = {}
): Promise<PurgeSummary> {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) {
    return { userId, skipped: true, reason: "존재하지 않는 회원입니다." };
  }
  if (user.status !== "withdrawn") {
    return { userId, skipped: true, reason: "탈퇴 처리되지 않은 계정입니다(status!=withdrawn)." };
  }

  const withdrawalLog = await prisma.userWithdrawalLog.findFirst({
    where: { userId, dataPurgedAt: null },
    orderBy: { requestedAt: "desc" },
  });
  if (!withdrawalLog) {
    return {
      userId,
      skipped: true,
      reason: "파기 대상 탈퇴 로그가 없습니다(이미 파기되었거나 탈퇴 로그 누락).",
    };
  }

  const now = new Date();
  if (!options.force && withdrawalLog.dataPurgeScheduledAt > now) {
    return {
      userId,
      skipped: true,
      reason: `아직 유예기간입니다(파기예정일: ${withdrawalLog.dataPurgeScheduledAt.toISOString()}).`,
    };
  }

  // 익명화 필드 값(결정적·유니크 보장 — email/nickname은 unique 제약 존재)
  const anonymizedEmail = `withdrawn_user_${userId}@deleted.local`;
  const anonymizedNickname = `탈퇴회원_${userId}`;

  const before = {
    email: user.email,
    phone: user.phone,
    nickname: user.nickname,
    gender: user.gender,
  };

  const results = await prisma.$transaction([
    // ── [A] HARD DELETE ──────────────────────────────────────────
    // 상담(consultation) 콘텐츠 — 자녀 테이블부터 삭제(FK 제약 순서)
    prisma.consultationMessage.deleteMany({ where: { session: { userId } } }),
    prisma.consultationReview.deleteMany({ where: { userId } }),
    prisma.consultationSession.deleteMany({ where: { userId } }),

    // 운세(fortune) 요청/결과 — 생년월일시 등 민감 입력값(inputPayload) 포함
    prisma.fortuneResult.deleteMany({ where: { request: { userId } } }),
    prisma.fortuneRequest.deleteMany({ where: { userId } }),

    // 궁합(compatibility) — 본인이 "요청자"인 건은 결과까지 완전 삭제
    prisma.compatibilityResult.deleteMany({
      where: { request: { requesterUserId: userId } },
    }),
    prisma.compatibilityRequest.deleteMany({ where: { requesterUserId: userId } }),
    // 본인이 "대상자"로 지목되었던 건(제3자의 요청)은 삭제하지 않고 연결만 해제
    prisma.compatibilityRequest.updateMany({
      where: { targetUserId: userId },
      data: { targetUserId: null },
    }),

    // 사주 프로필(생년월일시/음력/윤달 등 극도로 민감한 정보) 완전 삭제
    prisma.userProfile.deleteMany({ where: { userId } }),

    // ── [B] ANONYMIZE ────────────────────────────────────────────
    // 매칭 프로필 — 자기소개/이상형 조건 텍스트 비식별화 + 비공개 전환
    prisma.matchingProfile.updateMany({
      where: { userId },
      data: { introText: null, preferences: null, isPublic: false },
    }),

    // 회원 본체 — 식별정보(이메일/전화/닉네임/비밀번호해시/성별) 비식별화.
    // status는 이미 "withdrawn"이므로 유지(로그인/세션복원 차단은 기존
    // 인프라가 이미 담당). passwordHash를 null로 만들어 방어적으로 한 번 더
    // 로그인 경로를 차단한다(defense in depth).
    prisma.user.update({
      where: { id: userId },
      data: {
        email: anonymizedEmail,
        phone: null,
        nickname: anonymizedNickname,
        passwordHash: null,
        gender: null,
        marketingAgreed: false,
        updatedBy: "system:account-purge",
      },
    }),

    // ── 파기 완료 기록 ───────────────────────────────────────────
    prisma.userWithdrawalLog.update({
      where: { id: withdrawalLog.id },
      data: { dataPurgedAt: now },
    }),

    // ── 04A O-2 감사로그: 모든 CUD는 예외 없이 operation_logs 기록 ──
    prisma.operationLog.create({
      data: {
        actorType: "system",
        actorId: null,
        action: "data_purge",
        targetType: "user",
        targetId: userId,
        before: JSON.stringify(before),
        after: JSON.stringify({ email: anonymizedEmail, nickname: anonymizedNickname }),
      },
    }),
  ]);

  const deletedCounts: Record<string, number> = {
    consultationMessage: results[0].count,
    consultationReview: results[1].count,
    consultationSession: results[2].count,
    fortuneResult: results[3].count,
    fortuneRequest: results[4].count,
    compatibilityResult: results[5].count,
    compatibilityRequest: results[6].count,
    compatibilityRequestTargetUnlinked: results[7].count,
    userProfile: results[8].count,
    matchingProfileAnonymized: results[9].count,
  };

  return { userId, skipped: false, deletedCounts };
}

/**
 * 파기 유예기간(`dataPurgeScheduledAt`)이 도래했지만 아직 파기되지 않은
 * (`dataPurgedAt IS NULL`) 탈퇴 계정 목록을 조회한다.
 */
export async function findUsersDuePurge(now: Date = new Date()): Promise<number[]> {
  const logs = await prisma.userWithdrawalLog.findMany({
    where: { dataPurgedAt: null, dataPurgeScheduledAt: { lte: now } },
    select: { userId: true },
  });
  return [...new Set(logs.map((l) => l.userId))];
}

/**
 * 파기 유예기간이 도래한 모든 탈퇴 계정을 일괄 파기한다.
 * (Task #2 배치 스크립트에서 호출)
 */
export async function purgeDueAccounts(): Promise<PurgeSummary[]> {
  const userIds = await findUsersDuePurge();
  const summaries: PurgeSummary[] = [];
  for (const userId of userIds) {
    // 계정별로 개별 트랜잭션 처리 — 한 건이 실패해도 나머지 계정 파기에
    // 영향을 주지 않도록 순차 처리한다.
    try {
      const summary = await purgeUserData(userId);
      summaries.push(summary);
    } catch (e) {
      summaries.push({
        userId,
        skipped: true,
        reason: `파기 중 오류: ${e instanceof Error ? e.message : String(e)}`,
      });
    }
  }
  return summaries;
}
