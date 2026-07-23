import { verifyAdminSession } from "@/lib/dal";

// Phase18-0 범위: 대시보드 스켈레톤만 구현(레이아웃/사이드바만).
// 라이브 운영센터 위젯(10종)과 통계 대시보드는 각 도메인 메뉴 구현 이후
// 별도 Phase18-x 단계에서 순차적으로 추가한다(05_Admin_System_Design.md §3.0).
export default async function DashboardPage() {
  const session = await verifyAdminSession();

  return (
    <div>
      <h1 className="text-2xl font-bold text-white">대시보드</h1>
      <p className="mt-1 text-sm text-slate-400">
        {session.name}님, 환영합니다 ({session.roleCode})
      </p>

      <div className="mt-6 rounded-xl border border-dashed border-slate-700 bg-slate-800/50 p-8 text-center">
        <p className="text-slate-400">
          라이브 운영센터 · 통계 대시보드 위젯은 이후 단계(Phase18-x)에서
          <br />
          각 도메인(회원/AI콘텐츠/리워드 등) 구현과 함께 순차적으로 추가됩니다.
        </p>
      </div>
    </div>
  );
}
