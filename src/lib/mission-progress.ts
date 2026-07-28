// Phase5 - 게임화 보강(최소연동): 실제 사용자 행동(actionType)이 발생했을 때
// 관련된 활성 미션(Mission)의 UserMission.progressCount를 갱신하고, targetCount에
// 도달하면 즉시 완료 처리 + 보상 포인트를 자동 지급(claim)하는 공용 엔진.
//
// [배경] 조사 결과 admin_web에는 Mission/UserMission 스키마와 관리자 CRUD 화면만
// 존재했고, 실제로 진행률을 갱신하는 엔진이 어디에도 없었다(순수 Mock 상태).
// 이 함수를 "복 나누기(send_bok)"와 "오늘의 운세 확인(view_daily_fortune)" 두 실제
// API 라우트에서 호출하여, 최초로 미션이 실제로 동작하게 만든다(최소 연동 범위).
//
// [알려진 단순화] UserMission은 (userId, missionId) 조합당 1개만 존재한다
// (@@unique([userId, missionId])). 즉 daily/weekly 미션이라도 한 번 완료되면
// 기간이 지나도 다시 진행되지 않는다(주기별 리셋 미구현). 이는 이번 최소연동
// 범위에서 의도적으로 제외했으며, 추후 periodKey(예: "2026-07-30") 컬럼을
// 추가해 기간별로 새 레코드를 만드는 방식으로 확장할 수 있다.
import type { Prisma } from "@/generated/prisma/client";

type TxClient = Prisma.TransactionClient;

export interface MissionProgressUpdate {
  missionId: number;
  missionTitle: string;
  progressCount: number;
  targetCount: number;
  /** 이번 호출로 새로 완료(+보상지급)되었는지 여부 */
  completed: boolean;
  rewardPoint: number;
}

/**
 * userId가 actionType에 해당하는 행동을 1회 수행했을 때 호출한다.
 * 반드시 호출측의 $transaction 콜백 내부(tx)에서 호출해 원자성을 보장해야 한다.
 */
export async function incrementMissionProgress(
  tx: TxClient,
  userId: number,
  actionType: string
): Promise<MissionProgressUpdate[]> {
  const missions = await tx.mission.findMany({
    where: { actionType, isActive: true, deletedAt: null },
  });
  if (missions.length === 0) return [];

  const updates: MissionProgressUpdate[] = [];

  for (const mission of missions) {
    const existing = await tx.userMission.findUnique({
      where: { userId_missionId: { userId, missionId: mission.id } },
    });

    // 이미 완료(completed/claimed)된 미션은 더 이상 진행시키지 않음(단순화 정책)
    if (existing && existing.status !== "in_progress") {
      continue;
    }

    const nextProgress = (existing?.progressCount ?? 0) + 1;
    const willComplete = nextProgress >= mission.targetCount;

    const userMission = existing
      ? await tx.userMission.update({
          where: { id: existing.id },
          data: {
            progressCount: nextProgress,
            status: willComplete ? "completed" : "in_progress",
          },
        })
      : await tx.userMission.create({
          data: {
            userId,
            missionId: mission.id,
            progressCount: nextProgress,
            status: willComplete ? "completed" : "in_progress",
          },
        });

    let rewardPoint = 0;
    if (willComplete && mission.rewardPoint > 0) {
      // 완료 즉시 자동 수령(claim) 처리 — 지갑 적립 + 원장 기록
      let wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) {
        wallet = await tx.wallet.create({
          data: { userId, currencyType: "POINT", balance: 0 },
        });
      }
      const newBalance = wallet.balance + mission.rewardPoint;
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: newBalance, balanceSyncedAt: new Date() },
      });
      await tx.pointHistory.create({
        data: {
          walletId: wallet.id,
          userId,
          amount: mission.rewardPoint,
          type: "earn",
          sourceType: "mission",
          sourceId: mission.id,
          balanceAfter: newBalance,
          memo: `미션 완료: ${mission.title}`,
        },
      });
      await tx.userMission.update({
        where: { id: userMission.id },
        data: { status: "claimed", claimedAt: new Date() },
      });
      rewardPoint = mission.rewardPoint;

      await tx.operationLog.create({
        data: {
          actorType: "system",
          actorId: userId,
          action: "mission_auto_claim",
          targetType: "user_mission",
          targetId: userMission.id,
          before: JSON.stringify({
            status: existing?.status ?? "none",
            progressCount: existing?.progressCount ?? 0,
          }),
          after: JSON.stringify({
            status: "claimed",
            progressCount: nextProgress,
            rewardPoint: mission.rewardPoint,
          }),
        },
      });
    }

    updates.push({
      missionId: mission.id,
      missionTitle: mission.title,
      progressCount: nextProgress,
      targetCount: mission.targetCount,
      completed: willComplete,
      rewardPoint,
    });
  }

  return updates;
}
