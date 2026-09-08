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
//
// [2026-09, 바이럴 디자인 이식] 사용자가 예전에 전달한 "바이럴 디자인"
// 핸드오프 패키지(`nextjs_guiindo`, HANDOFF.md)의 아이보리+로즈골드 팔레트
// (--bg-ivory:#FBF7EF, --bg-cream:#F5EBDC, --rose-500:#C99B7F,
// --rose-700:#A6795E, --blush:#E8B4A5, --gold:#D4A574, --ink:#2A2438,
// --ink-soft:#6E5A54)로 전면 리스킨한다. Flutter `/guinji-map/*`
// (GmColors)와 정확히 같은 색상 토큰이므로, 카톡 → 이 랜딩 → 앱까지
// 이어지는 전체 바이럴 여정이 하나의 디자인 언어로 통일된다.
// admin_web은 Tailwind v4(설정파일 없는 CSS 기반)를 쓰므로, 전역 테마를
// 건드리지 않고 이 라우트에만 arbitrary value(`bg-[#FBF7EF]` 등)로 색을
// 지정한다 — 관리자 대시보드 나머지 화면에는 영향이 없다. 아래
// `loadInvite()`의 조회 로직, `generateMetadata()`의 OG 개인화,
// 캐시버스팅 구조는 전혀 손대지 않았다(디자인만 교체).
import type { Metadata } from "next";
import { prisma } from "@/lib/db";
import { isGuinjiInviteExpired } from "@/app/api/public/guinji/_shared";
import { GuinjiInviteInteractive } from "./guinji-invite-interactive";
import { ServiceGrid } from "./service-grid";
import { type RelationCount } from "./relation-network-graph";
import { deriveCharacterType } from "@/lib/guinji-character-type";
import { GUINJI_RELATION_TYPES } from "./relation-meta";
import { GUINJI_RELATION_TYPE_ORDER } from "@/lib/guinji-relation-judger";
import { SintongBottomNavBar } from "./sintong-bottom-nav-bar";

// [2026-09, 즉시 리다이렉트(B-1) 전면 폐기 — 원상복구] 직전 세션에서
// "초대 링크는 플러터 원본 페이지 기반으로 가야 한다"는 사용자 지시를
// "마운트 즉시 강제 리다이렉트"로 잘못 해석해 `RedirectToApp`을 붙였다.
// 이는 doryeong.app(경쟁 서비스) 레퍼런스 스크린샷을 근거로 사용자가
// 강하게 정정한 원칙을 정면으로 위반한 것이었다:
//   1) 카톡을 눌러 들어오면 "첨부한 콘텐츠"(귀인지도 캐릭터 카드)가 먼저
//      보여야 한다 — 즉시 다른 화면으로 튕기면 안 된다.
//   2) 콘텐츠를 보고 받은 사람이 자기 이름+생년월일을 입력하면, 그 자리에서
//      관계·점수·랭킹이 나오고 지도에 등록되어야 한다(웹에서 완결).
//   3) 앱 전환은 받은 사람이 "나도 지도를 만들어볼까" 하고 스스로 원할
//      때만 일어난다 — 자동 강제 전환 금지.
// 이 원칙을 정확히 구현한 컴포넌트(`GuinjiInviteInteractive` + 실제 DB에
// 반영하는 `/api/public/guinji/g/{token}/join`)는 이미 완성되어 있었으나,
// B-1 작업 때 실수로 페이지에서 떼어내고 `RedirectToApp`으로 바꿔버렸다.
// 여기서 그 실수를 되돌리고 원래 흐름을 복원한다.

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{ token: string }>;
  searchParams: Promise<{ v?: string }>;
};

// [Phase A-2 — 카톡 공유 바이럴 개선, OG 미리보기 카드] 지금까지 이
// 페이지에 오픈그래프 메타태그가 전혀 없어, 카톡/문자 등에 링크를
// 붙여넣어도 그냥 파란 텍스트 링크로만 보였다(2026-08 실사용자 리포트로
// 발견 — "이미지가 예쁘게 나와야 한다"). 이미 신설되어 있던 정적 OG
// 이미지 라우트(`/api/public/og/guinji/[token].png`, M8 확정: 동적 생성
// 아님·고정 PNG)를 여기 연결해, 카카오톡 등 SNS 크롤러가 og:title/
// og:description/og:image를 읽어 카드 미리보기를 만들 수 있게 한다.
//
// [결정 매모 D1/D6 — 2026-08-31, 카톡 OG 캐시버스팅] Flutter
// `buildGuinjiInviteLink()`가 공유 링크에 `?v={shareCode}`를 붙여 보낸다.
// 이 값을 그대로 버리지 않고 OG 이미지 URL의 **경로**에 심어
// (`/og/guinji/{token}/{shareCode}.png`) 내보낸다 — 쿼리스트링 변경만으론
// 카톡이 캐시를 갱신하지 않는 경우에도, 이미지 경로 자체가 매번 달라지므로
// 새로 크롤링하게 만드는 것이 목적(2단 캐시버스팅). `v`가 없는 구버전
// 링크(이미 퍼진 링크 호환)는 캐시버스팅 세그먼트 없는 기존 라우트로 그대로
// 간다.
export async function generateMetadata({ params, searchParams }: PageProps): Promise<Metadata> {
  const { token } = await params;
  const { v: shareCode } = await searchParams;
  const invite = await loadInvite(token);
  const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
  const ogImageUrl = shareCode
    ? `${baseUrl}/api/public/og/guinji/${token}/${shareCode}.png`
    : `${baseUrl}/api/public/og/guinji/${token}.png`;

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
      include: {
        owner: { select: { nickname: true } },
        relationships: { select: { relationType: true } },
      },
    });

    if (!map || map.deletedAt != null || map.status !== "active") {
      return { state: "not_found" as const };
    }
    if (isGuinjiInviteExpired(map.createdAt)) {
      return { state: "expired" as const };
    }

    // [캐릭터 유형] `ownerSajuParsed`(이미 클라이언트가 계산해 캐싱해 둔 실제
    // 오행 카운트)에서 우세 오행 1개를 뽑아 5종 캐릭터 유형에 대입한다(새로운
    // 사주 계산을 만들지 않는다 — deriveCharacterType 참고). 파싱 실패 시
    // 캐릭터 섹션만 조용히 생략한다(랜딩페이지 전체를 막지 않음).
    let characterType = null;
    try {
      if (map.ownerSajuParsed) {
        const saju = JSON.parse(map.ownerSajuParsed) as { fiveElementsCount?: Record<string, number> };
        if (saju.fiveElementsCount) characterType = deriveCharacterType(saju.fiveElementsCount);
      }
    } catch (e) {
      console.error("[GET /g/[token]] 캐릭터 유형 계산 실패:", e);
    }

    // [비식별 원칙] 멤버 개별 정보는 절대 넘기지 않고, 관계유형별 집계
    // 카운트만 만든다(RelationNetworkGraph에는 이 counts만 전달).
    const rawCounts: Record<string, number> = {};
    for (const t of GUINJI_RELATION_TYPE_ORDER) rawCounts[t] = 0;
    for (const r of map.relationships) {
      if (rawCounts[r.relationType] != null) rawCounts[r.relationType] += 1;
    }
    const relationCounts: RelationCount[] = GUINJI_RELATION_TYPE_ORDER.map((key) => ({
      key,
      label: GUINJI_RELATION_TYPES[key].label,
      hanja: GUINJI_RELATION_TYPES[key].hanja,
      color: RELATION_COLOR[key],
      count: rawCounts[key],
    }));

    return {
      state: "ok" as const,
      ownerName: map.owner.nickname,
      characterType,
      relationCounts,
    };
  } catch (e) {
    console.error("[GET /g/[token]] 조회 실패:", e);
    return { state: "error" as const };
  }
}

// [PRD p.38 LABEL_HUE tone → HEX, `guinji_design_handoff/DEV_SPEC.md` Dart
// RelationLabel enum과 동일한 색상값] 12라벨 고유색 — 브랜드 팔레트(로즈골드)
// 와는 별개로 "관계 유형"을 구분하기 위한 파스텔 톤이라 그대로 유지한다.
const RELATION_COLOR: Record<string, string> = {
  CHEON_GWII: "#F5D97A",
  NA_SALRIDA: "#E8C8F5",
  JORYEOK: "#A8D5E3",
  GACHI_GA: "#C8F5D5",
  NA_SALJINDA: "#F5C8D5",
  CHANG_GYIM: "#E8C890",
  GAMJEONG: "#D5C8F5",
  DEUNGDEUNG: "#A5B5E8",
  KKEURIDA: "#F5A8BD",
  GACHI_BICH: "#F5D97A",
  JAGEUKJE: "#F5B880",
  GINGJANG: "#B5A8E8",
};

const SERIF = "'Noto Serif KR', serif";

// [2026-09, zip 프로토타입(nextjs_guiindo) 디자인 전면 이식] 사용자가
// "카톡 친구 초대하기 랜딩이 마음에 안 든다"며 첨부한 zip 파일(HeroSection+
// PreviewCard 컴포넌트 트리)의 비주얼로 완전히 교체한다. 작은 원형
// 아바타+단색 텍스트 카드 구조를 버리고, 큰 히어로 이미지+그라디언트
// 타이틀+"오늘 사주 미리보기" 카드 구조로 바꾼다. 참여폼(
// GuinjiInviteInteractive)과 관계지도 12그리드(RelationNetworkGraph),
// ServiceGrid는 실제 DB 반영 로직이 걸려 있어 그대로 유지하고 비주얼만
// zip 톤에 맞춘다 — 로직은 전혀 손대지 않았다.
const HERO_STARS_BG =
  "radial-gradient(1px 1px at 20% 30%, rgba(212,165,116,.6) 50%, transparent 100%)," +
  "radial-gradient(1px 1px at 70% 20%, rgba(232,180,165,.5) 50%, transparent 100%)," +
  "radial-gradient(1.2px 1.2px at 40% 70%, rgba(212,165,116,.4) 50%, transparent 100%)," +
  "radial-gradient(1px 1px at 85% 60%, rgba(232,180,165,.5) 50%, transparent 100%)";

// 오행별 해시태그 — zip PreviewCard의 "#감성발달 #절제 #관계형 지도자"와
// 같은 형식으로, 5종 캐릭터 유형(deriveCharacterType)에 맞춰 새로 정의.
// 새 사주 계산을 만들지 않고 이미 있는 element 키에 대응하는 표시용 태그만
// 추가한다.
const CHARACTER_TAGS: Record<string, string[]> = {
  목: ["#성장지향", "#꾸준함", "#리더십"],
  화: ["#열정", "#표현력", "#에너지"],
  토: ["#안정감", "#포용력", "#신뢰"],
  금: ["#결단력", "#원칙", "#완성도"],
  수: ["#유연함", "#통찰력", "#적응력"],
};

export default async function GuinjiInviteLandingPage({ params }: PageProps) {
  const { token } = await params;
  const invite = await loadInvite(token);

  return (
    <div className="min-h-screen bg-[#FBF7EF] pb-[76px]">
      {invite.state === "ok" && (
        <>
          {/* 히어로 섹션 — zip HeroSection 이식: 큰 히어로 이미지 +
              그라디언트 "귀인 지도" 타이틀 */}
          <section className="relative overflow-hidden">
            <div
              className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-70"
              style={{ backgroundImage: HERO_STARS_BG }}
              aria-hidden
            />
            <div className="relative mx-auto w-full max-w-[440px] px-5 pt-6 pb-8">
              {/* 브랜드 마크 */}
              <div className="mb-5 flex items-center gap-1.5">
                <span
                  className="flex h-6 w-6 items-center justify-center rounded-full"
                  style={{ backgroundImage: "linear-gradient(135deg, #E2A88A, #A6795E)" }}
                >
                  <span className="text-[10px] font-bold leading-none text-white">신</span>
                </span>
                <span style={{ fontFamily: SERIF }} className="text-[13px] font-bold text-[#2A2438]">
                  신통방통
                </span>
              </div>

              {/* 초대 배지 */}
              <div className="mb-4 inline-flex items-center gap-2 whitespace-nowrap rounded-full border border-[#F5D9C9] bg-[#FBEFE8] px-3 py-1.5">
                <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#C99B7F]" />
                <span className="whitespace-nowrap text-[11px] font-semibold text-[#A6795E]">
                  {invite.ownerName}님이 초대했어요
                </span>
              </div>

              <h1
                style={{ fontFamily: SERIF }}
                className="mb-2 text-[36px] font-bold leading-[1.15] tracking-tight text-[#2A2438]"
              >
                <span className="mb-1 block text-[18px] font-medium text-[#6E5A54]">
                  {invite.ownerName}님의
                </span>
                <span
                  className="bg-clip-text text-transparent"
                  style={{ backgroundImage: "linear-gradient(90deg, #A6795E, #E8B4A5)" }}
                >
                  귀인 지도
                </span>
              </h1>
              <p className="mb-5 text-[14px] leading-relaxed text-[#6E5A54]">
                당신의 인연과 관계를
                <br />
                지도로 담았어요
              </p>

              {/* 히어로 이미지 (zip public/images/hero-hanbok.png) */}
              <div className="relative mb-5 overflow-hidden rounded-3xl shadow-[0_8px_32px_-12px_rgba(166,121,94,0.22)]">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/images/hero-hanbok.png" alt="" className="block h-auto w-full" />
                <div className="absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-[#FBF7EF] to-transparent" />
              </div>

              <div className="space-y-2 text-[13.5px] leading-relaxed text-[#6E5A54]">
                <p>
                  내 주변을 살펴보면 유난히 자신의 성장에만 힘이 되는, 나와 다른 인연이라
                  인식하지 못했던 <b className="text-[#2A2438]">귀인지도</b>가 있어요.
                </p>
                <p>귀인, 인연, 힘이 되는 사람, 서로 보완하는 관계까지 명확히 확인할 수 있어요.</p>
                <p className="pt-1 font-semibold text-[#2A2438]">
                  생일만 넣으면, 내가 이 사람에게
                  <br />
                  어떤 사람인지 바로 나와요.
                </p>
              </div>
            </div>
          </section>

          <div className="mx-auto w-full max-w-[440px] space-y-4 px-5 pb-8">
            {/* "오늘 사주 미리보기" 카드 — zip PreviewCard 이식, 실제
                deriveCharacterType() 결과(오행 5종) 그대로 사용 */}
            {invite.characterType && (
              <div className="rounded-3xl border border-[#E8DDD0] bg-white/85 p-4 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
                <div className="mb-2 inline-flex items-center gap-1 rounded-full border border-[#EFC4AB] bg-white px-3 py-1 text-[12px] text-[#A6795E]">
                  오늘 사주 미리보기
                </div>
                <div
                  style={{ fontFamily: SERIF, color: invite.characterType.color }}
                  className="mb-1 text-[17px] font-bold leading-snug"
                >
                  {invite.ownerName}님은
                  <br />
                  {invite.characterType.tagline}
                  <br />
                  {invite.characterType.hanja} {invite.characterType.title}
                </div>
                <div className="mb-3 text-[12px] text-[#6E5A54]">
                  {invite.characterType.description}
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {(CHARACTER_TAGS[invite.characterType.element] ?? []).map((tag) => (
                    <span
                      key={tag}
                      className="inline-flex items-center gap-1 rounded-full border border-[#E8DDD0] bg-[#F5EBDC] px-3 py-1 text-[12px] text-[#6E5A54]"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* [원상복구] 콘텐츠(위 캐릭터 카드) 다음에 이름+생년월일 입력폼이
                바로 이어진다. 제출하면 그 자리에서 관계·점수가 나오고
                RelationNetworkGraph가 새로고침 없이 갱신된다(웹 완결 경험).
                앱 전환은 결과 카드의 "내 지도 만들기" 버튼을 사용자가 직접
                눌렀을 때만 시도된다. */}
            <GuinjiInviteInteractive
              token={token}
              ownerName={invite.ownerName}
              initialCounts={invite.relationCounts}
            />
            <ServiceGrid />
          </div>
        </>
      )}

      {invite.state === "expired" && (
        <div className="relative mx-auto w-full max-w-[440px] px-4 py-8">
          <div
            className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-70"
            style={{ backgroundImage: HERO_STARS_BG }}
            aria-hidden
          />
          <div className="relative mb-5 flex items-center justify-center gap-1.5">
            <span
              className="flex h-6 w-6 items-center justify-center rounded-full"
              style={{ backgroundImage: "linear-gradient(135deg, #E2A88A, #A6795E)" }}
            >
              <span className="text-[10px] font-bold leading-none text-white">신</span>
            </span>
            <span style={{ fontFamily: SERIF }} className="text-[13px] font-bold text-[#2A2438]">
              신통방통
            </span>
          </div>
          <div className="relative rounded-3xl border border-[#E8DDD0] bg-white/85 p-8 text-center shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
            <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#2A2438]">
              초대 링크가 만료되었어요
            </h1>
            <p className="mb-2 text-sm leading-relaxed text-[#6E5A54]">
              이 초대 링크는 생성된 지 7일이 지나
              <br />
              더 이상 사용할 수 없어요.
              <br />
              지도 주인에게 새 링크를 요청해 주세요.
            </p>
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
            <span
              className="flex h-6 w-6 items-center justify-center rounded-full"
              style={{ backgroundImage: "linear-gradient(135deg, #E2A88A, #A6795E)" }}
            >
              <span className="text-[10px] font-bold leading-none text-white">신</span>
            </span>
            <span style={{ fontFamily: SERIF }} className="text-[13px] font-bold text-[#2A2438]">
              신통방통
            </span>
          </div>
          <div className="relative rounded-3xl border border-[#E8DDD0] bg-white/85 p-8 text-center shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
            <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#2A2438]">
              지도를 찾을 수 없어요
            </h1>
            <p className="mb-2 text-sm leading-relaxed text-[#6E5A54]">
              링크가 잘못되었거나 지도 주인이
              <br />
              봉인을 거두었을 수 있어요.
            </p>
          </div>
        </div>
      )}

      {/* 브랜드 푸터 */}
      <footer className="mx-auto w-full max-w-[440px] border-t border-[#E8DDD0] px-5 pt-5 pb-8 text-center">
        <p className="text-[10px] text-[#A08C82]">© 2026 Sintongbangtong. All rights reserved.</p>
      </footer>

      {/* [2026-09, 웹 하단바 신설 — 사용자 명시 지시 "웹이니까 신통방통 하단바를
          넣어주고"] 이 페이지는 웹(브라우저)에서 열리지만, 신통방통 앱의
          정체성을 그대로 느낄 수 있도록 화면 하단에 고정된 신통방통 브랜드
          내비게이션 바를 추가한다. 각 탭은 앱 설치 없이 곧바로
          `https://sintong.kr/app/` 웹 버전의 해당 화면으로 이동한다. */}
      <SintongBottomNavBar />
    </div>
  );
}
