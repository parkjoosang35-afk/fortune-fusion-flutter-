import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import GiftcardProductCreateForm from "@/components/GiftcardProductCreateForm";
import GiftcardProductRow from "@/components/GiftcardProductRow";
import GiftcardIssueActionCell from "@/components/GiftcardIssueActionCell";

// 05_Admin_System_Design.md §3.4 "상점 관리" — 4차 소단위(도메인 J 1단계): 상품권 상품 관리
// 04A J-1 giftcard_products CRUD(재고 stock_count 관리 포함).
// 5차 소단위(도메인 J 2단계): 상품권 생명주기 조회 — 04A J-2~J-7
//   (giftcard_issues/usages/cancels/refunds/reissues/expiry_logs) 조회 전용 통합.
// 6차 소단위(도메인 J 3단계): 상품권 환불/재발급 처리 — 2단계 확인 필수, 환불 시
//   포인트 복원 로직은 시스템(WalletService 트랜잭션 패턴)이 자동 처리한다
//   (관리자 수동 balance 수정 없음). GiftcardIssueActionCell(client)에서 처리.
// [범위 결정] coupons/coupon_issues(J-8/J-9)는 다음 소단위에서 순서대로 추가한다
//   (08§3.2 라우트매핑: /shop/giftcards).
export const dynamic = "force-dynamic";

const ISSUE_STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  requested: { label: "요청됨", cls: "bg-slate-800 text-slate-400" },
  issued: { label: "발급완료", cls: "bg-emerald-950/60 text-emerald-400" },
  failed: { label: "발급실패", cls: "bg-rose-950/60 text-rose-400" },
  cancelled: { label: "취소됨", cls: "bg-amber-950/60 text-amber-400" },
  expired: { label: "만료", cls: "bg-slate-700 text-slate-300" },
};

const REFUND_STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  pending: { label: "처리중", cls: "bg-slate-800 text-slate-400" },
  completed: { label: "완료", cls: "bg-emerald-950/60 text-emerald-400" },
  failed: { label: "실패", cls: "bg-rose-950/60 text-rose-400" },
};

function fmtDate(d: Date | null): string {
  return d ? d.toISOString().slice(0, 19).replace("T", " ") : "-";
}

export default async function ShopGiftcardsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "shop")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.write;
  const canDelete = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.delete;

  const products = await prisma.giftcardProduct.findMany({
    where: { deletedAt: null },
    orderBy: { id: "asc" },
  });

  // ── 5차 소단위: 상품권 생명주기 조회 (조회 전용, 최근 50건) ──
  const issues = await prisma.giftcardIssue.findMany({
    where: { deletedAt: null },
    orderBy: { createdAt: "desc" },
    take: 50,
    include: {
      user: { select: { nickname: true } },
      product: { select: { name: true } },
      usage: { select: { usedAt: true } },
    },
  });

  const cancels = await prisma.giftcardCancel.findMany({
    where: { deletedAt: null },
    orderBy: { cancelledAt: "desc" },
    take: 20,
    include: {
      issue: { select: { user: { select: { nickname: true } }, product: { select: { name: true } } } },
      refunds: { select: { status: true } },
    },
  });

  const reissues = await prisma.giftcardReissue.findMany({
    where: { deletedAt: null },
    orderBy: { createdAt: "desc" },
    take: 20,
    include: {
      originalIssue: { select: { user: { select: { nickname: true } }, product: { select: { name: true } } } },
      newIssue: { select: { issuedCode: true } },
    },
  });

  const expiryLogs = await prisma.giftcardExpiryLog.findMany({
    orderBy: { expiredAt: "desc" },
    take: 20,
    include: {
      issue: { select: { user: { select: { nickname: true } }, product: { select: { name: true } } } },
    },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">상점 관리 — 상품권</h1>
        <p className="mt-1 text-sm text-slate-400">
          상품권(기프트카드) 상품을 등록/관리하고, 발급/사용/취소/환불/재발급/만료 등 생명주기
          이력을 조회합니다. 발급완료(미사용) 건은 발급 이력 표에서 환불/재발급 처리(2단계 확인
          필수)를 할 수 있습니다.
        </p>
      </div>

      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">상품권 상품 관리</h2>
        <GiftcardProductCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">이미지</th>
                <th className="px-4 py-3">상품명</th>
                <th className="px-4 py-3">브랜드</th>
                <th className="px-4 py-3">필요 포인트</th>
                <th className="px-4 py-3">재고</th>
                <th className="px-4 py-3">유효기간</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {products.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    등록된 상품권 상품이 없습니다.
                  </td>
                </tr>
              )}
              {products.map((p) => (
                <GiftcardProductRow key={p.id} product={p} canWrite={canWrite} canDelete={canDelete} />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          04A J-1 명시: stock_count는 CHECK(stock_count&gt;=0) 제약 대상이며, 실제 발급(J-2) 처리 시
          원자적으로 감소합니다. 이 화면에서는 관리자가 재고 수량을 직접 설정/조정합니다.
        </p>
      </section>

      {/* 상품권 생명주기 조회 (조회 전용) */}
      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-white">
          상품권 발급 이력 (최근 50건)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">상품권</th>
                <th className="px-4 py-3">사용 포인트</th>
                <th className="px-4 py-3">발급코드</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">사용여부</th>
                <th className="px-4 py-3">발급 시각</th>
                <th className="px-4 py-3">만료 시각</th>
                <th className="px-4 py-3">처리</th>
              </tr>
            </thead>
            <tbody>
              {issues.length === 0 && (
                <tr>
                  <td colSpan={9} className="px-4 py-10 text-center text-slate-500">
                    발급 이력이 없습니다.
                  </td>
                </tr>
              )}
              {issues.map((iss) => {
                const st = ISSUE_STATUS_LABEL[iss.status] ?? {
                  label: iss.status,
                  cls: "bg-slate-800 text-slate-400",
                };
                const eligible = iss.status === "issued" && !iss.usage;
                return (
                  <tr key={iss.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                    <td className="px-4 py-3 text-slate-200">{iss.user.nickname}</td>
                    <td className="px-4 py-3 text-slate-300">{iss.product.name}</td>
                    <td className="px-4 py-3 text-slate-400">{iss.pointSpent.toLocaleString()}P</td>
                    <td className="px-4 py-3 font-mono text-slate-500">{iss.issuedCode ?? "-"}</td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
                    </td>
                    <td className="px-4 py-3 text-slate-400">
                      {iss.usage ? `사용완료(${fmtDate(iss.usage.usedAt)})` : "미사용"}
                    </td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(iss.issuedAt)}</td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(iss.expiresAt)}</td>
                    <td className="px-4 py-3">
                      <GiftcardIssueActionCell
                        issueId={iss.id}
                        pointSpent={iss.pointSpent}
                        canWrite={canWrite}
                        eligible={eligible}
                      />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          &quot;사용여부&quot;는 04A J-3 giftcard_usages(UQ issue_id) 레코드 존재로 판단하며,
          issue.status 자체는 requested/issued/failed/cancelled/expired만 사용합니다(사용완료는
          별도 상태값이 아님). 환불/재발급 처리는 발급완료(issued) &amp; 미사용 건에 한해 2단계
          확인 절차를 거쳐 실행됩니다.
        </p>
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-white">
          상품권 취소/환불 이력 (조회 전용, 최근 20건)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">상품권</th>
                <th className="px-4 py-3">취소 사유</th>
                <th className="px-4 py-3">환불 포인트</th>
                <th className="px-4 py-3">환불 상태</th>
                <th className="px-4 py-3">취소 시각</th>
              </tr>
            </thead>
            <tbody>
              {cancels.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    취소/환불 이력이 없습니다.
                  </td>
                </tr>
              )}
              {cancels.map((c) => {
                const refund = c.refunds[0];
                const rst = refund
                  ? REFUND_STATUS_LABEL[refund.status] ?? { label: refund.status, cls: "bg-slate-800 text-slate-400" }
                  : null;
                return (
                  <tr key={c.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                    <td className="px-4 py-3 text-slate-200">{c.issue.user.nickname}</td>
                    <td className="px-4 py-3 text-slate-300">{c.issue.product.name}</td>
                    <td className="px-4 py-3 text-slate-400">{c.reason ?? "-"}</td>
                    <td className="px-4 py-3 text-slate-400">{c.refundedPoint.toLocaleString()}P</td>
                    <td className="px-4 py-3">
                      {rst ? (
                        <span className={`rounded-full px-2 py-0.5 text-xs ${rst.cls}`}>{rst.label}</span>
                      ) : (
                        <span className="text-slate-500">미연결</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(c.cancelledAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          환불 원장 레코드(point_histories, source_type=refund)와 1:N 연결되며, 실제 포인트 복원은
          지갑/포인트 시스템에서 자동 처리됩니다(관리자 수동 balance 수정 없음).
        </p>
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-white">
          상품권 재발급 이력 (조회 전용, 최근 20건)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">상품권</th>
                <th className="px-4 py-3">재발급 사유</th>
                <th className="px-4 py-3">신규 발급코드</th>
                <th className="px-4 py-3">시각</th>
              </tr>
            </thead>
            <tbody>
              {reissues.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    재발급 이력이 없습니다.
                  </td>
                </tr>
              )}
              {reissues.map((r) => (
                <tr key={r.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 text-slate-200">{r.originalIssue.user.nickname}</td>
                  <td className="px-4 py-3 text-slate-300">{r.originalIssue.product.name}</td>
                  <td className="px-4 py-3 text-slate-400">{r.reason ?? "-"}</td>
                  <td className="px-4 py-3 font-mono text-slate-500">{r.newIssue.issuedCode ?? "-"}</td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(r.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-white">
          상품권 만료 처리 로그 (조회 전용, 최근 20건)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">상품권</th>
                <th className="px-4 py-3">만료 처리 시각</th>
              </tr>
            </thead>
            <tbody>
              {expiryLogs.length === 0 && (
                <tr>
                  <td colSpan={3} className="px-4 py-10 text-center text-slate-500">
                    만료 처리 로그가 없습니다.
                  </td>
                </tr>
              )}
              {expiryLogs.map((log) => (
                <tr key={log.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 text-slate-200">{log.issue.user.nickname}</td>
                  <td className="px-4 py-3 text-slate-300">{log.issue.product.name}</td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(log.expiredAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          Append-only 로그입니다(배치가 만료 처리 시 기록). 만료된 건은 환불/재발급 대상이 아닙니다.
        </p>
      </section>
    </div>
  );
}
