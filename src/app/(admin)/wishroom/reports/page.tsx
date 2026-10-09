import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import ReportRow from "@/components/ReportRow";
import WishroomSubNav from "@/components/WishroomSubNav";

// [신통방통 관리자 통합 간소화 실행 지시서 task 6] 소원방(WishRoom) 신고 처리함.
//
// [배경 — 전수조사 발견 사항] prisma/schema.prisma의 Report 모델 주석에는 이미
// target_type 화이트리스트로 wish_room/wish_room_comment/wish_room_review가
// 명시되어 있고, api/public/wishroom/reports/route.ts와
// api/public/wishroom/reviews/[id]/report/route.ts가 실제로 이 타입들로
// reports 테이블에 신고를 기록하고 있었다. 하지만 기존 신고 처리함
// (community/reports/page.tsx)은 post/comment/wish/user/fortune_result 5종만
// 처리하도록 만들어져 있어, 소원방 신고는 "접수는 되지만 담당자 배정도 조치도
// 할 수 없는" 상태로 영구히 쌓이고 있었다(actions/reports.ts의 actionReport에
// wish_room* 3종 조치 로직은 이번 task에서 함께 추가했다).
//
// [구현 방식] community/reports/page.tsx와 동일한 폴리모픽 배치조회 패턴을
// 그대로 복제하되, 대상을 wish_room/wish_room_comment/wish_room_review 3종으로
// 한정하고(prisma.report.findMany where targetType in [...]), 대상 테이블을
// WishRoom/WishRoomComment/WishRoomReview로 교체했다. 행 렌더링은 기존
// ReportRow 컴포넌트를 그대로 재사용한다(TARGET_TYPE_LABEL에 3종 라벨만 추가).
export const dynamic = "force-dynamic";

const WISHROOM_TARGET_TYPES = ["wish_room", "wish_room_comment", "wish_room_review"] as const;

export default async function WishroomReportsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "wishroom")) {
    redirect("/dashboard");
  }
  const canWrite = canWriteMenu(session.roleCode, "wishroom");

  const reports = await prisma.report.findMany({
    where: { targetType: { in: [...WISHROOM_TARGET_TYPES] } },
    orderBy: { createdAt: "desc" },
    take: 50,
    include: {
      reporter: { select: { nickname: true } },
      assignedAdmin: { select: { name: true } },
    },
  });

  const roomIds = reports.filter((r) => r.targetType === "wish_room").map((r) => r.targetId);
  const commentIds = reports.filter((r) => r.targetType === "wish_room_comment").map((r) => r.targetId);
  const reviewIds = reports.filter((r) => r.targetType === "wish_room_review").map((r) => r.targetId);

  const [rooms, comments, reviews] = await Promise.all([
    roomIds.length > 0
      ? prisma.wishRoom.findMany({ where: { id: { in: roomIds } }, select: { id: true, text: true } })
      : Promise.resolve([]),
    commentIds.length > 0
      ? prisma.wishRoomComment.findMany({ where: { id: { in: commentIds } }, select: { id: true, text: true } })
      : Promise.resolve([]),
    reviewIds.length > 0
      ? prisma.wishRoomReview.findMany({ where: { id: { in: reviewIds } }, select: { id: true, text: true } })
      : Promise.resolve([]),
  ]);
  const roomMap = new Map(rooms.map((r) => [r.id, r.text]));
  const commentMap = new Map(comments.map((c) => [c.id, c.text]));
  const reviewMap = new Map(reviews.map((r) => [r.id, r.text]));

  function truncate(text: string, len: number): string {
    return text.length > len ? text.slice(0, len) + "…" : text;
  }

  function targetLabel(targetType: string, targetId: number): string {
    if (targetType === "wish_room") {
      const text = roomMap.get(targetId);
      return text ? truncate(text, 20) : `(삭제된 소원방 #${targetId})`;
    }
    if (targetType === "wish_room_comment") {
      const text = commentMap.get(targetId);
      return text ? truncate(text, 20) : `(삭제된 댓글 #${targetId})`;
    }
    if (targetType === "wish_room_review") {
      const text = reviewMap.get(targetId);
      return text ? truncate(text, 20) : `(삭제된 후기 #${targetId})`;
    }
    return `#${targetId}`;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">소원방 운영 — 신고 처리함</h1>
        <p className="mt-1 text-sm text-slate-500">
          소원방/소원방 댓글/소원방 후기 신고를 통합 조회하고 담당자 배정, 조치(삭제·경고·계정정지)
          또는 반려 처리를 합니다. (레거시 소원게시판 신고는 커뮤니티 관리 &gt; 신고 처리함에서
          별도로 다룹니다)
        </p>
        <WishroomSubNav />
      </div>

      <section>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">대상</th>
                <th className="px-4 py-3">신고 사유</th>
                <th className="px-4 py-3">신고자</th>
                <th className="px-4 py-3">담당자/조치</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">접수일</th>
                <th className="px-4 py-3">처리</th>
              </tr>
            </thead>
            <tbody>
              {reports.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    접수된 신고가 없습니다.
                  </td>
                </tr>
              )}
              {reports.map((r) => (
                <ReportRow
                  key={r.id}
                  report={{
                    id: r.id,
                    targetType: r.targetType,
                    targetLabel: targetLabel(r.targetType, r.targetId),
                    reporterNickname: r.reporter.nickname,
                    reason: r.reason,
                    assignedAdminName: r.assignedAdmin?.name ?? null,
                    action: r.action,
                    status: r.status,
                    createdAt: r.createdAt,
                  }}
                  canWrite={canWrite}
                />
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
