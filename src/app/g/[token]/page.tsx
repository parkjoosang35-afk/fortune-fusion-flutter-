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
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { isGuinjiInviteExpired } from "@/app/api/public/guinji/_shared";
import { GuinjiPreviewForm } from "./preview-form";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ token: string }>;
};

// [Phase A-2 — 카톡 공유 바이럴 개선, OG 미리보기 카드] 지금까지 이
// 페이지에 오픈그래프 메타태그가 전혀 없어, 카톡/문자 등에 링크를
// 붙여넣어도 그냥 파란 텍스트 링크로만 보였다(2026-08 실사용자 리포트로
// 발견 — "이미지가 예쁘게 나와야 한다"). 이미 신설되어 있던 정적 OG
// 이미지 라우트(`/api/public/og/guinji/[token].png`, M8 확정: 동적 생성
// 아님·고정 PNG)를 여기 연결해, 카카오톡 등 SNS 크롤러가 og:title/
// og:description/og:image를 읽어 카드 미리보기를 만들 수 있게 한다.
export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { token } = await params;
  const invite = await loadInvite(token);
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const ogImageUrl = `${baseUrl}/api/public/og/guinji/${token}.png`;

  const title =
    invite.state === "ok"
      ? `${invite.ownerName}님이 초대한 귀인 지도`
      : "신통방통 · 귀인지도";
  const description = "생일만 넣으면, 내가 이 사람에게 어떤 사람인지 나와요.";

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      images: [{ url: ogImageUrl, width: 1200, height: 630 }],
      type: "website",
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [ogImageUrl],
    },
  };
}

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
            <p className="mb-2 text-sm leading-relaxed text-slate-300">
              앱 설치 없이, 아래에 생년월일만 넣어도
              <br />
              바로 관계를 확인할 수 있어요.
            </p>
            {/* [Phase A-2] 웹 미리보기 폼 — 로그인/앱 설치 없이 즉시 결과를
                보여줘 바이럴 이탈을 막는다(위 generateMetadata 주석 참고). */}
            <GuinjiPreviewForm
              token={token}
              ownerName={invite.ownerName}
              deepLink={deepLink}
            />
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
