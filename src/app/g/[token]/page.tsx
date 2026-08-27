// 귀인지도 초대 링크 — 공개 웹 랜딩페이지.
// [Phase A — 딥링크 버그수정] Flutter 앱이 지금까지 공유 메시지에 박아
// 넣던 `sintong.app/g/{token}`은 실존하지 않는(미등록) 도메인이었다. 그
// 결과 카톡 등에서 이 링크를 열면 카카오톡 인앱 브라우저가 DNS 조회부터
// 실패해 "해당 페이지를 찾을 수 없습니다" 404를 표시했다(2026-08 실사용자
// 리포트로 발견). 이 페이지는 실제로 살아있는 admin_web 서버
// (`EnvConfig.adminApiBaseUrl`) 아래 `/g/{token}` 경로에 신설되어, 최소한
// "정상적으로 열리는 페이지"를 보장하고, "앱에서 열기" 버튼으로 커스텀
// URI 스킴(`fortunefusion://g/{token}`)을 호출해 앱 실행을 시도한다.
//
// [인증 없이 접근 가능] 이 페이지는 (admin) 그룹 밖에 위치하며, 로그인
// 여부와 무관하게 열람 가능해야 한다(카톡에서 링크를 연 사람은 아직 로그인
// 상태를 알 수 없음). 기존 `GET /api/public/guinji/g/[token]` API는
// `requireUser`로 로그인을 강제하므로 이 페이지에서 재사용할 수 없어,
// 서버 컴포넌트에서 Prisma로 직접 "존재 여부/만료 여부/소유자 닉네임"만
// 조회한다(로그인이 필요한 관계 판정 자체는 앱 내부에서만 수행 — 이
// 페이지는 그 실제 참여 로직을 대체하지 않는다).
//
// [Phase B, 아직 미착수] 실제 운영 도메인이 확정되면 이 서버가 그 도메인
// 아래 배포되고, Android App Links(autoVerify) + assetlinks.json으로
// "링크 클릭 즉시 앱이 열리는" 완전한 딥링크가 된다. 지금은 그 전 단계로,
// 이 중간 웹페이지를 거쳐 앱을 여는 2단계 구조다.
import { prisma } from "@/lib/db";
import { isGuinjiInviteExpired } from "@/app/api/public/guinji/_shared";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ token: string }>;
};

async function loadInvite(token: string) {
  try {
    const map = await prisma.guinjiMap.findUnique({
      where: { token },
      include: { owner: { select: { nickname: true } } },
    });

    if (!map || map.deletedAt != null || map.status !== "active") {
      return { state: "not_found" as const };
    }
    if (isGuinjiInviteExpired(map.createdAt)) {
      return { state: "expired" as const };
    }
    return { state: "ok" as const, ownerName: map.owner.nickname };
  } catch (e) {
    console.error("[GET /g/[token]] 조회 실패:", e);
    return { state: "error" as const };
  }
}

export default async function GuinjiInviteLandingPage({ params }: PageProps) {
  const { token } = await params;
  const invite = await loadInvite(token);
  const deepLink = `fortunefusion://g/${token}`;

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-b from-indigo-950 via-slate-900 to-slate-950 px-6 py-12">
      <div className="w-full max-w-sm rounded-2xl border border-white/10 bg-white/5 p-8 text-center shadow-xl backdrop-blur">
        <p className="mb-2 text-xs font-medium uppercase tracking-widest text-indigo-300">
          신통방통 · 귀인지도
        </p>

        {invite.state === "ok" && (
          <>
            <h1 className="mb-4 text-xl font-bold text-white">
              {invite.ownerName}님이
              <br />
              당신을 귀인지도에 초대했어요
            </h1>
            <p className="mb-8 text-sm leading-relaxed text-slate-300">
              앱에서 열면 생일만 입력해도
              <br />두 사람의 관계가 채워져요.
            </p>
            <a
              href={deepLink}
              className="mb-3 block w-full rounded-xl bg-indigo-400 px-4 py-3 text-sm font-bold text-slate-900 transition hover:bg-indigo-300"
            >
              앱에서 열기
            </a>
            <p className="text-xs text-slate-500">
              앱이 열리지 않는다면 신통방통 앱을 먼저 설치해 주세요.
            </p>
          </>
        )}

        {invite.state === "expired" && (
          <>
            <h1 className="mb-4 text-xl font-bold text-white">
              초대 링크가 만료되었어요
            </h1>
            <p className="mb-8 text-sm leading-relaxed text-slate-300">
              이 초대 링크는 생성된 지 7일이 지나
              <br />
              더 이상 사용할 수 없어요.
              <br />
              지도 주인에게 새 링크를 요청해 주세요.
            </p>
          </>
        )}

        {(invite.state === "not_found" || invite.state === "error") && (
          <>
            <h1 className="mb-4 text-xl font-bold text-white">
              지도를 찾을 수 없어요
            </h1>
            <p className="mb-8 text-sm leading-relaxed text-slate-300">
              링크가 잘못되었거나 지도 주인이
              <br />
              봉인을 거두었을 수 있어요.
            </p>
          </>
        )}
      </div>
    </div>
  );
}
