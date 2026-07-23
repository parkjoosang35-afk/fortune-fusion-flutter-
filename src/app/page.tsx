import { redirect } from "next/navigation";

// 루트 경로는 항상 /dashboard로 리다이렉트한다.
// 미인증 사용자는 proxy.ts에서 이미 /login으로 리다이렉트되므로,
// 이 페이지에 도달하는 것은 인증된 사용자뿐이다.
export default function RootPage() {
  redirect("/dashboard");
}
