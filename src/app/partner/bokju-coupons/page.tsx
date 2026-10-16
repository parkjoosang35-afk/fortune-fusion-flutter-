import { redirect } from "next/navigation";
import { getPartnerSession } from "@/lib/partner-session";

// [복주머니 마케팅 쿠폰] /partner/bokju-coupons 루트 접근 시 로그인 여부에 따라 분기.
export default async function PartnerRootPage() {
  const session = await getPartnerSession();
  redirect(session ? "/partner/bokju-coupons/allocations" : "/partner/bokju-coupons/login");
}
