// 궁합지도(Gunghap Map) 초대 링크 — 공개 웹 랜딩페이지.
// [신통방통 궁합지도 — 통합 최종 개발 지시서, Phase 1 승인]
//
// [배경 — 실제 운영 404 버그] Flutter `buildGunghapInviteLink()`
// (`lib/features/gunghap/share/gunghap_share_kakao.dart`)가 카카오톡
// 공유 메시지에 `https://sintong.kr/gh/{token}` 링크를 이미 내보내고
// 있었지만, admin_web에는 `/gh/[token]/page.tsx` 자체가 존재하지 않아
// 앱이 설치되지 않은 사람이 이 링크를 열면 Next.js 기본 404가 떴다
// (curl로 직접 확인된 실제 운영 버그 — 테스트 서버 문제가 아님).
// 이미 완전히 구현·검증된 백엔드 API(`/api/public/gunghap/g/{token}`
// GET·`/join` POST)는 전혀 손대지 않고, 누락되어 있던 이 웹 랜딩
// 페이지만 신설한다.
//
// [템플릿 — 귀인지도 `/g/[token]/page.tsx` 재사용] 구조(서버 컴포넌트의
// generateMetadata + Prisma 조회, ok/revoked/not_found+error 3분기 렌더,
// 바이럴 디자인 톤)를 그대로 따른다. 기존 귀인지도 파일은 1바이트도
// 수정하지 않고, 궁합지도 전용 컴포넌트(gunghap-invite-interactive.tsx,
// make-my-gunghap-button.tsx, layout.tsx)를 이 디렉터리에 새로 만들어
// 완전히 독립적으로 동작한다.
//
// [인증 없이 접근 가능] `/api/public/gunghap/g/[token]` GET은 궁합지도
// 설계 원칙(초대받은 사람이 로그인/앱설치 없이 링크만으로 참여) 때문에
// 애초에 `requireUser()`를 쓰지 않으므로, 이 페이지는 그 라우트를 그대로
// 재사용하지 않고(그 라우트는 클라이언트 fetch용 공개 API) 서버
// 컴포넌트에서 직접 Prisma로 "존재 여부/중단 여부/소유자 이름"만 조회한다
// (귀인지도 `loadInvite()`와 동일한 패턴 — 그 쪽도 전용 Prisma 조회를
// 쓰고 guinji GET API를 호출하지 않는다).
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { categoryLabel } from "@/lib/gunghap/gunghap-narrative";
import type { GunghapCategoryId } from "@/lib/gunghap/gunghap-category-rules";
import { GunghapInviteInteractive } from "./gunghap-invite-interactive";
import { MakeMyGunghapButton } from "./make-my-gunghap-button";
import { SintongBottomNavBar } from "../../g/[token]/sintong-bottom-nav-bar";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ token: string }>;
};

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { token } = await params;
  const invite = await loadInvite(token);
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  // [OG 이미지 — Phase 1 범위] 궁합지도 전용 동적 OG PNG 라우트
  // (`/api/public/og/gunghap/...`)는 아직 없다(귀인지도 전용
  // `/api/public/og/guinji/[token].png`만 존재). 이번 Phase는 "링크가
  // 404 없이 정상적으로 열리는 것"이 목표이므로, 신규 OG 이미지 생성
  // 파이프라인을 새로 만들지 않고 기존 정적 히어로 이미지를 재사용한다
  // (추후 Phase에서 궁합 전용 동적 OG가 필요하면 별도 작업으로 추가).
  const ogImageUrl = `${baseUrl}/images/hero-hanbok.png`;

  // [2026-11 궁합 주제 반영 지시서 — Section 1] 초대 생성 시 선택한 주제가
  // 있으면 OG 제목/설명에 반영한다(예: "OO님이 보낸 연애 궁합 초대장").
  // 미선택(레거시 초대)이면 기존 일반 문구를 그대로 쓴다.
  const topicSuffix =
    invite.state === "ok" && invite.majorLabel ? ` · ${invite.majorLabel}` : "";
  const title =
    invite.state === "ok"
      ? `${invite.ownerName}님이 보낸${topicSuffix ? ` ${invite.majorLabel}` : ""} 궁합지도 초대장`
      : "신통방통 · 궁합지도";
  const description =
    invite.state === "ok" && invite.majorLabel
      ? `${invite.majorLabel} 궁합, 이름과 생년월일만 넣으면 바로 나와요.`
      : "이름과 생년월일만 넣으면, 두 사람의 궁합이 바로 나와요.";

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
    const invite = await prisma.gunghapInvite.findUnique({
      where: { token },
      include: {
        owner: { select: { nickname: true } },
        result: { select: { id: true } },
      },
    });

    if (!invite || invite.deletedAt != null || invite.status !== "active") {
      return { state: "not_found" as const };
    }

    const ownerName = invite.ownerName ?? invite.owner.nickname;
    const majorLabel = invite.majorId
      ? categoryLabel(invite.majorId as GunghapCategoryId)
      : null;

    // [중요 — 귀인지도 g/[token]/route.ts와 동일 순서 원칙] 이미 결과가
    // 존재하면(누군가 이미 참여를 완료했다면) revoke/만료 여부와 무관하게
    // 그 사실(joined=true)만 알려준다 — 단, 이 랜딩페이지 자체는 "참여
    // 완료된 초대 링크를 다시 열었을 때 무엇을 보여줄지"까지는 Phase 1
    // 범위에 포함하지 않는다(1초대 1결과 스키마 제약 — 재참여 폼을
    // 보여주면 서버가 거부할 뿐 오류는 아니다). 일단 안내만 명확히
    // 보여주고, revoked/expired보다 먼저 판정한다(확정 기준 "완료된
    // 궁합 결과는 보존").
    if (invite.result != null) {
      return { state: "joined" as const, ownerName, majorLabel };
    }

    if (invite.revokedAt != null) {
      return { state: "revoked" as const, ownerName, majorLabel };
    }

    // [2026-11 궁합 주제 반영 지시서 — Section 3] 미응답 상태에서 7일
    // 경과 시 만료 처리(신규 상태, 기존 revoked와 별도 안내문 노출).
    if (invite.expiresAt != null && invite.expiresAt.getTime() < Date.now()) {
      return { state: "expired" as const, ownerName, majorLabel };
    }

    return { state: "ok" as const, ownerName, majorLabel };
  } catch (e) {
    console.error("[GET /gh/[token]] 조회 실패:", e);
    return { state: "error" as const };
  }
}

const SERIF = "'Noto Serif KR', serif";

const HERO_STARS_BG =
  "radial-gradient(1px 1px at 20% 30%, rgba(212,165,116,.6) 50%, transparent 100%)," +
  "radial-gradient(1px 1px at 70% 20%, rgba(232,180,165,.5) 50%, transparent 100%)," +
  "radial-gradient(1.2px 1.2px at 40% 70%, rgba(212,165,116,.4) 50%, transparent 100%)," +
  "radial-gradient(1px 1px at 85% 60%, rgba(232,180,165,.5) 50%, transparent 100%)";

function BrandMark() {
  return (
    <div className="relative mb-5 flex items-center gap-1.5">
      <span
        className="flex h-6 w-6 items-center justify-center rounded-full"
        style={{ backgroundImage: "linear-gradient(135deg, #FADFA0, #F5CF6A)" }}
      >
        <span className="text-[10px] font-bold leading-none text-white">신</span>
      </span>
      <span style={{ fontFamily: SERIF }} className="text-[13px] font-bold text-[#F8F2E6]">
        신통방통
      </span>
    </div>
  );
}

export default async function GunghapInviteLandingPage({ params }: PageProps) {
  const { token } = await params;
  const invite = await loadInvite(token);

  return (
    <div className="min-h-screen bg-[#0A0716] pb-[76px]">
      {invite.state === "ok" && (
        <>
          <section className="relative overflow-hidden">
            <div
              className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-70"
              style={{ backgroundImage: HERO_STARS_BG }}
              aria-hidden
            />
            <div className="relative mx-auto w-full max-w-[440px] px-5 pt-6 pb-8">
              <BrandMark />

              <div className="mb-4 inline-flex items-center gap-2 whitespace-nowrap rounded-full border border-[#F5CF6A]/25 bg-[#F5CF6A]/10 px-3 py-1.5">
                <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#F5CF6A]" />
                <span className="whitespace-nowrap text-[11px] font-semibold text-[#F5CF6A]">
                  {invite.ownerName}님이 궁합을 물어봤어요
                </span>
              </div>

              <h1
                style={{ fontFamily: SERIF }}
                className="mb-2 text-[36px] font-bold leading-[1.15] tracking-tight text-[#F8F2E6]"
              >
                <span className="mb-1 block text-[18px] font-medium text-[#C9BBA8]">
                  {invite.ownerName}님과 나의
                </span>
                <span
                  className="bg-clip-text text-transparent"
                  style={{ backgroundImage: "linear-gradient(90deg, #F5CF6A, #F5CF6A)" }}
                >
                  궁합지도
                </span>
              </h1>
              <p className="mb-5 text-[14px] leading-relaxed text-[#C9BBA8]">
                정통 사주로 보는
                <br />
                두 사람의 인연
              </p>

              <div className="relative mb-5 overflow-hidden rounded-3xl shadow-[0_8px_32px_-12px_rgba(245,207,106,0.22)]">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/images/hero-hanbok.png" alt="" className="block h-auto w-full" />
                <div className="absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-[#0A0716] to-transparent" />
              </div>

              <div className="space-y-2 text-[13.5px] leading-relaxed text-[#C9BBA8]">
                <p>
                  연애, 결혼, 속궁합, 성격, 재물, 사업, 친구, 가족까지{" "}
                  <b className="text-[#F8F2E6]">8개 분야</b>의 궁합을 한 번에 확인할 수 있어요.
                </p>
                <p className="pt-1 font-semibold text-[#F8F2E6]">
                  이름과 생년월일만 넣으면,
                  <br />
                  바로 결과가 나와요.
                </p>
              </div>
            </div>
          </section>

          <div className="mx-auto w-full max-w-[440px] space-y-4 px-5 pb-8">
            <GunghapInviteInteractive token={token} ownerName={invite.ownerName} />
          </div>
        </>
      )}

      {invite.state === "joined" && (
        <div className="relative mx-auto w-full max-w-[440px] px-4 py-8">
          <div
            className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-70"
            style={{ backgroundImage: HERO_STARS_BG }}
            aria-hidden
          />
          <div className="relative mb-5 flex items-center justify-center gap-1.5">
            <BrandMark />
          </div>
          <div className="relative rounded-3xl border border-[#3A2A52] bg-[#1F1133] p-8 text-center shadow-[0_4px_20px_-8px_rgba(245,207,106,0.15)]">
            <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#F8F2E6]">
              이미 궁합을 확인한 링크예요
            </h1>
            <p className="mb-2 text-sm leading-relaxed text-[#C9BBA8]">
              이 초대 링크는 이미 한 번 응답이 완료됐어요.
              <br />
              궁합 결과는 {invite.ownerName}님의 앱에서
              <br />
              확인할 수 있어요.
            </p>
            <MakeMyGunghapButton />
          </div>
        </div>
      )}

      {invite.state === "revoked" && (
        <div className="relative mx-auto w-full max-w-[440px] px-4 py-8">
          <div
            className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-70"
            style={{ backgroundImage: HERO_STARS_BG }}
            aria-hidden
          />
          <div className="relative mb-5 flex items-center justify-center gap-1.5">
            <BrandMark />
          </div>
          <div className="relative rounded-3xl border border-[#3A2A52] bg-[#1F1133] p-8 text-center shadow-[0_4px_20px_-8px_rgba(245,207,106,0.15)]">
            <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#F8F2E6]">
              {invite.ownerName}님이 이 링크를 닫았어요
            </h1>
            <p className="mb-2 text-sm leading-relaxed text-[#C9BBA8]">
              이 초대 링크는 더 이상 사용할 수 없어요.
              <br />
              그래도 괜찮아요 — 나만의 궁합지도는
              <br />
              언제든 만들 수 있어요.
            </p>
            <MakeMyGunghapButton />
          </div>
        </div>
      )}

      {invite.state === "expired" && (
        <div className="relative mx-auto w-full max-w-[440px] px-4 py-8">
          <div
            className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-70"
            style={{ backgroundImage: HERO_STARS_BG }}
            aria-hidden
          />
          <div className="relative mb-5 flex items-center justify-center gap-1.5">
            <BrandMark />
          </div>
          <div className="relative rounded-3xl border border-[#3A2A52] bg-[#1F1133] p-8 text-center shadow-[0_4px_20px_-8px_rgba(245,207,106,0.15)]">
            <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#F8F2E6]">
              초대 링크가 만료됐어요
            </h1>
            <p className="mb-2 text-sm leading-relaxed text-[#C9BBA8]">
              발급 후 7일이 지나 이 링크는
              <br />
              더 이상 사용할 수 없어요.
              <br />
              {invite.ownerName}님에게 새 링크를 요청해 주세요.
            </p>
            <MakeMyGunghapButton />
          </div>
        </div>
      )}

      {(invite.state === "not_found" || invite.state === "error") && (
        <div className="relative mx-auto w-full max-w-[440px] px-4 py-8">
          <div
            className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-70"
            style={{ backgroundImage: HERO_STARS_BG }}
            aria-hidden
          />
          <div className="relative mb-5 flex items-center justify-center gap-1.5">
            <BrandMark />
          </div>
          <div className="relative rounded-3xl border border-[#3A2A52] bg-[#1F1133] p-8 text-center shadow-[0_4px_20px_-8px_rgba(245,207,106,0.15)]">
            <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#F8F2E6]">
              링크를 찾을 수 없어요
            </h1>
            <p className="mb-2 text-sm leading-relaxed text-[#C9BBA8]">
              주소가 잘못되었거나, 초대장이
              <br />
              삭제되었을 수 있어요.
              <br />
              링크를 다시 확인해 주세요.
            </p>
            <MakeMyGunghapButton />
          </div>
        </div>
      )}

      <footer className="mx-auto w-full max-w-[440px] border-t border-[#3A2A52] px-5 pt-5 pb-8 text-center">
        <p className="text-[10px] text-[#8C7F6E]">© 2026 Sintongbangtong. All rights reserved.</p>
      </footer>

      <SintongBottomNavBar />
    </div>
  );
}
