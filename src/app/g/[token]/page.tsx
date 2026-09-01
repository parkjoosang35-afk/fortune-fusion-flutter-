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
import { GuinjiInviteInteractive } from "./guinji-invite-interactive";
import { type RelationCount } from "./relation-network-graph";
import { deriveCharacterType } from "@/lib/guinji-character-type";
import { GUINJI_RELATION_TYPES } from "./relation-meta";
import { GUINJI_RELATION_TYPE_ORDER } from "@/lib/guinji-relation-judger";

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
// RelationLabel enum과 동일한 색상값] 기존 5색을 12라벨 색상으로 전면 교체.
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

// [바이럴 UI 개편 — 2026-09] 사용자가 경쟁 서비스 레퍼런스를 보고 "이렇게
// 나와야 바이럴이 된다"고 명시적으로 요구했다(스크린샷 4장 비교 지시).
// 기존 다크(인디고) 미니멀 카드 1장짜리 구조를 다음으로 교체한다:
//   1) 캐릭터 일러스트 + 오행 기반 캐릭터 유형 타이틀 + 상세 해설(신설)
//   2)+3) 이름·생년월일 입력폼 + 관계 지도 그래프(`GuinjiInviteInteractive`,
//      신설 — 폼 제출이 실제로 DB에 참여를 기록하고, 그 응답으로 그래프를
//      새로고침 없이 즉시 갱신한다. 기존 `GuinjiPreviewForm`은 DB에 아무
//      것도 저장하지 않아 "지도에 반영되지 않는다"는 사용자 지적의 근본
//      원인이었다 — 완전히 폐기하고 이 컴포넌트로 교체했다.)
// 배경도 레퍼런스와 동일하게 크림/베이지 톤으로 바꾼다(기존 OG 카드
// buildOgPng.tsx의 #FAF3E0과 동일 계열로 카톡→랜딩 시각 일관성 확보).
export default async function GuinjiInviteLandingPage({ params }: PageProps) {
  const { token } = await params;
  const invite = await loadInvite(token);

  return (
    <div className="min-h-screen bg-[#FAF3E0] px-4 py-8">
      <div className="mx-auto w-full max-w-sm">
        <p className="mb-4 text-center text-xs font-medium uppercase tracking-widest text-amber-800/70">
          신통방통 · 귀인지도
        </p>

        {invite.state === "ok" && (
          <div className="space-y-4">
            {/* 1) 캐릭터 카드 — 일러스트 + 오행 캐릭터 유형 + 상세 해설 */}
            <div className="rounded-2xl border border-amber-900/10 bg-white/70 p-6 text-center shadow-sm">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/guinji/bangtong_fairy.png"
                alt=""
                className="mx-auto mb-3 h-24 w-24 rounded-full object-cover shadow"
              />
              <h1 className="text-lg font-bold text-stone-800">
                {invite.ownerName}님의 귀인 지도
              </h1>
              {invite.characterType && (
                <>
                  <p
                    className="mt-1 text-2xl font-bold"
                    style={{ color: invite.characterType.color }}
                  >
                    {invite.characterType.hanja} {invite.characterType.title}
                  </p>
                  <p className="mt-1 text-sm text-stone-500">{invite.characterType.tagline}</p>
                  <p className="mt-4 rounded-xl bg-amber-900/5 px-4 py-3 text-left text-sm leading-relaxed text-stone-600">
                    {invite.characterType.description}
                  </p>
                </>
              )}
              <p className="mt-4 text-sm leading-relaxed text-stone-500">
                생일만 넣으면, 내가 이 사람에게
                <br />
                어떤 사람인지 바로 나와요.
              </p>
            </div>

            {/* 2)+3) 웹 참여 폼 + 관계 지도 그래프 — 로그인/앱 설치 없이
                이름+생년월일을 한 번 입력하면 즉시 결과가 나오고, 실제로
                지도(GuinjiMapMember/GuinjiRelationship)에 반영되어 아래
                그래프가 새로고침 없이 그 자리에서 갱신된다(2026-09 수정 —
                기존에는 폼이 DB에 아무것도 저장하지 않는 "미리보기"뿐이라
                지도에 전혀 반영되지 않던 문제를 근본적으로 해결). */}
            <GuinjiInviteInteractive
              token={token}
              ownerName={invite.ownerName}
              initialCounts={invite.relationCounts}
            />
          </div>
        )}

        {invite.state === "expired" && (
          <div className="rounded-2xl border border-amber-900/10 bg-white/70 p-8 text-center shadow-sm">
            <h1 className="mb-4 text-xl font-bold text-stone-800">
              초대 링크가 만료되었어요
            </h1>
            <p className="mb-2 text-sm leading-relaxed text-stone-500">
              이 초대 링크는 생성된 지 7일이 지나
              <br />
              더 이상 사용할 수 없어요.
              <br />
              지도 주인에게 새 링크를 요청해 주세요.
            </p>
          </div>
        )}

        {(invite.state === "not_found" || invite.state === "error") && (
          <div className="rounded-2xl border border-amber-900/10 bg-white/70 p-8 text-center shadow-sm">
            <h1 className="mb-4 text-xl font-bold text-stone-800">
              지도를 찾을 수 없어요
            </h1>
            <p className="mb-2 text-sm leading-relaxed text-stone-500">
              링크가 잘못되었거나 지도 주인이
              <br />
              봉인을 거두었을 수 있어요.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
