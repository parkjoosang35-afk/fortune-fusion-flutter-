import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import ReviewApprovalRow from "@/components/ReviewApprovalRow";
import WishroomSubNav from "@/components/WishroomSubNav";

// [신통방통 관리자 통합 간소화 실행 지시서 task 6] 소원방 어뷰징 의심 후기 승인 대기열.
//
// [배경 — 전수조사 발견 사항] WishRoomReview.status 필드 주석: "통과: visible(보상
// 즉시 지급) · 의심 플래그 있음: review(보상 보류 + 관리자 검토) · hidden_by_report ·
// deleted_by_admin". wishroom-engine.ts의 reviewAbuseFlags()가 TOO_SHORT/REPEAT_CHAR/
// NUMBERS_ONLY/JAMO/GIBBERISH/SEQUENCE/REPEAT_PHRASE/LOW_VARIETY/DUPLICATE/RAPID 등의
// 의심 신호를 감지하면 [id]/review/route.ts가 status="review"로 저장하고 보상 지급을
// 보류하지만, 이 "review" 상태를 승인(보상지급+visible전환)하거나 반려
// (hidden_by_report전환)할 관리자 기능이 전혀 없어 영구 보류 상태였다. 이 화면과
// actions/wishroom-admin.ts의 approveReview/rejectReview가 그 공백을 메운다.
export const dynamic = "force-dynamic";

export default async function WishroomReviewsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "wishroom")) {
    redirect("/dashboard");
  }
  const canWrite = canWriteMenu(session.roleCode, "wishroom");

  const reviews = await prisma.wishRoomReview.findMany({
    where: { status: "review" },
    orderBy: { createdAt: "desc" },
    take: 50,
    include: {
      user: { select: { nickname: true } },
      room: { select: { text: true } },
    },
  });

  function parseFlags(flagsJson: string): string[] {
    try {
      const parsed = JSON.parse(flagsJson);
      return Array.isArray(parsed) ? parsed.map((f) => String(f)) : [];
    } catch {
      return [];
    }
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">소원방 운영 — 후기 승인 대기</h1>
        <p className="mt-1 text-sm text-slate-500">
          어뷰징 의심 신호(짧은글/반복문자/숫자만/초성/의미없는글 등)가 감지되어 보상 지급이
          보류된 성취 후기 목록입니다. 승인하면 실제 후기 등록과 동일한 복주머니 보상(기본
          30 + 사진첨부 20)이 지급되고 공개 피드에 노출됩니다. 반려하면 보상 없이 숨김
          처리됩니다.
        </p>
        <WishroomSubNav />
      </div>

      <section>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">소원방</th>
                <th className="px-4 py-3">작성자</th>
                <th className="px-4 py-3">후기 내용</th>
                <th className="px-4 py-3">의심 신호</th>
                <th className="px-4 py-3">작성일</th>
                <th className="px-4 py-3">처리</th>
              </tr>
            </thead>
            <tbody>
              {reviews.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    승인 대기 중인 후기가 없습니다.
                  </td>
                </tr>
              )}
              {reviews.map((r) => (
                <ReviewApprovalRow
                  key={r.id}
                  review={{
                    id: r.id,
                    roomId: r.roomId,
                    text: r.text,
                    photoUrl: r.photoUrl,
                    flags: parseFlags(r.flagsJson),
                    userNickname: r.user.nickname,
                    roomWishText: r.room.text,
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
