import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import GiftcardProductCreateForm from "@/components/GiftcardProductCreateForm";
import GiftcardProductRow from "@/components/GiftcardProductRow";

// 05_Admin_System_Design.md §3.4 "상점 관리" — 4차 소단위(도메인 J 1단계): 상품권 상품 관리
// 04A J-1 giftcard_products CRUD(재고 stock_count 관리 포함).
// [범위 결정] 원칙⑤(소단위 개발)에 따라 이번 단계는 상품 관리까지만 다룬다.
//   giftcard_issues~expiry_logs(J-2~J-7 생명주기 조회, 환불/재발급)와 coupons/coupon_issues(J-8/J-9)는
//   다음 소단위에서 순서대로 추가한다(08§3.2 라우트매핑: /shop/giftcards).
export const dynamic = "force-dynamic";

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

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">상점 관리 — 상품권</h1>
        <p className="mt-1 text-sm text-slate-400">
          상품권(기프트카드) 상품을 등록하고 재고(stock_count)를 관리합니다. 발급/사용/취소/환불/재발급
          등 생명주기 조회는 다음 소단위에서 추가됩니다.
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
    </div>
  );
}
