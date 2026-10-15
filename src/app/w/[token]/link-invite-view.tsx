"use client";

// [소원방 공유 랜딩 — 클라이언트 뷰] 서버 컴포넌트(page.tsx)가 조회한
// 최소 정보(OG 메타용)로 먼저 그려지고, 마운트 직후 공개 API
// `GET /api/public/wishroom/share/{token}`(로그인 불필요 — Flutter
// WrRepository.roomByToken()과 동일 엔드포인트, 기존 그대로 재사용)를
// 호출해 실제 방 데이터(레벨/점등일수/응원수/복주머니수/댓글수)와
// 응원 메시지 목록(`GET /wish-rooms/{id}/comments`, 역시 로그인 불필요)을
// 추가로 받아와 "진짜 소원방 화면"을 그 자리에서 완성한다.
//
// [2026-11, 초대장 최종 정상화 지시서] 사용자 지시: "웹에서 소원방
// 초대시 그대로 그사람에 소원방으로 바로 들어가게 해주면돼 그리고
// 응원을 하던지 복주머니 할때 회원가입 후 할수 있다고 안내하면돼."
// 기존엔 이 페이지가 "제목/본문/레벨"만 보여주는 홍보용 티저 카드였고
// 응원·메시지·복주머니는 전부 앱 설치를 요구했다. 이제 이 페이지
// 자체가 실제 방(OtherRoomScreen에 대응하는 웹 버전) 콘텐츠를 보여주고,
// 참여 액션(응원/메시지/복주머니)은 기존 API가 전부 JWT 로그인을
// 강제하므로(`requireUser` 필수) 그 액션 버튼을 누르면 "회원가입 후
// 이용 가능" 안내 패널만 띄운다 — 기존 인증 체계·API는 전혀 건드리지
// 않는다(지시서 §4 "기존 시스템 보호").
import { useEffect, useState } from "react";

type ViewState = "ok" | "not_found" | "error";

type LinkInviteViewProps = {
  token: string;
  state: ViewState;
  ownerNickname?: string;
  text?: string;
  level?: number;
  levelName?: string;
  daysLit?: number;
};

const SERIF = "'Noto Serif KR', serif";
const SINTONG_SIGNUP_URL = "https://sintong.kr/app/#/signup";

function tryOpenApp(token: string) {
  // [Android App Links 검증 실패/iOS 폴백 대응] 커스텀 스킴 우선 시도.
  window.location.href = `fortunefusion://w/${token}`;
}

// 소원 빛깔(WISH_COLORS, wishroom_data.json) — 색상 표시용 최소 발췌.
// 전체 카탈로그를 들여오지 않고, 이 페이지가 필요로 하는 hex/한자/라벨만
// 하드코딩한다(Flutter wr_catalog.dart의 wishColors와 동일 값).
const WISH_COLOR_META: Record<string, { hanja: string; label: string; color: string; deep: string }> = {
  health: { hanja: "康", label: "건강", color: "#7fd6a0", deep: "#2f7a52" },
  wealth: { hanja: "財", label: "재물", color: "#f5cf6a", deep: "#9a6a12" },
  love: { hanja: "緣", label: "사랑·인연", color: "#ff8fb1", deep: "#a8325a" },
  study: { hanja: "合", label: "학업·합격", color: "#8ab8ff", deep: "#2f5aa8" },
  family: { hanja: "安", label: "가족·평안", color: "#c8a8ff", deep: "#5a3aa8" },
  career: { hanja: "成", label: "일·성공", color: "#ffa860", deep: "#a8541a" },
  peace: { hanja: "靜", label: "마음·평온", color: "#9ad8e8", deep: "#2f6a7a" },
  hope: { hanja: "願", label: "마음·희망", color: "#fff0d8", deep: "#8a6a4a" },
};

// 한지 색(PAPERS, wishroom_data.json) — 배경 그라디언트/먹색 최소 발췌.
const PAPER_META: Record<string, { bg: [string, string]; ink: string }> = {
  hanji: { bg: ["#fbf1dc", "#f1e0bd"], ink: "#4a2a1c" },
  blossom: { bg: ["#ffeef3", "#f9d2df"], ink: "#6a2440" },
  jade: { bg: ["#eef7e6", "#d4e8c4"], ink: "#2c4a24" },
  sky: { bg: ["#eaf4fb", "#cfe2f2"], ink: "#1f3a58" },
  lilac: { bg: ["#f4eefc", "#ddd0f2"], ink: "#3e2a66" },
  gold: { bg: ["#fff4d0", "#f0d48a"], ink: "#5a3a08" },
  indigo: { bg: ["#2c3566", "#1a1f44"], ink: "#f0eaff" },
  ink: { bg: ["#2e2622", "#171210"], ink: "#f8eedc" },
};

type RoomFull = {
  id: string;
  owner: string;
  text: string;
  level: number;
  levelName: string;
  daysLit: number;
  supportCount: number;
  pouchReceived: number;
  commentCount: number;
  wishColor: string;
  paper: string;
};

type CommentDto = { id: string; author: string; text: string; at: number };

export function LinkInviteView({
  token,
  state,
  ownerNickname,
  text,
  level,
  levelName,
  daysLit,
}: LinkInviteViewProps) {
  const [attemptedAppOpen, setAttemptedAppOpen] = useState(false);
  const [room, setRoom] = useState<RoomFull | null>(null);
  const [comments, setComments] = useState<CommentDto[]>([]);
  const [loadError, setLoadError] = useState(false);
  const [gatePanel, setGatePanel] = useState<null | "support" | "message" | "gift">(null);

  // [핵심 신설] 실제 방 데이터 + 응원 메시지를 기존 공개 API로 가져온다.
  // 두 API 모두 `requireUser(request)`가 auth 없으면 null을 반환할 뿐
  // 401을 던지지 않도록 이미 구현되어 있어(로그인 선택적), 비로그인
  // 방문자도 정상적으로 조회할 수 있다 — 새 API를 만들지 않고 기존
  // Flutter 앱과 동일한 엔드포인트를 그대로 재사용한다.
  useEffect(() => {
    if (state !== "ok") return;
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(`/api/public/wishroom/share/${token}`);
        const json = await res.json();
        if (cancelled) return;
        if (!res.ok || !json.success) {
          setLoadError(true);
          return;
        }
        const d = json.data;
        setRoom({
          id: d.id,
          owner: d.owner,
          text: d.text,
          level: d.level,
          levelName: d.levelName,
          daysLit: d.daysLit,
          supportCount: d.supportCount,
          pouchReceived: d.pouchReceived,
          commentCount: d.commentCount,
          wishColor: d.wishColor,
          paper: d.paper,
        });
        try {
          const cRes = await fetch(`/api/public/wishroom/wish-rooms/${d.id}/comments`);
          const cJson = await cRes.json();
          if (!cancelled && cRes.ok && cJson.success) {
            setComments(cJson.data as CommentDto[]);
          }
        } catch {
          // 댓글 로딩 실패는 방 전체를 막지 않는다(조용히 생략).
        }
      } catch {
        if (!cancelled) setLoadError(true);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [state, token]);

  if (state !== "ok") {
    return (
      <div className="relative mx-auto w-full max-w-[440px] px-4 py-8">
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
          <span className="mb-3 block text-[34px]">🔒</span>
          <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#2A2438]">
            더 이상 열 수 없는 링크예요
          </h1>
          <p className="mb-2 text-sm leading-relaxed text-[#6E5A54]">
            링크가 만료되었거나
            <br />
            소원방 주인이 공개 범위를 바꿨을 수 있어요.
          </p>
        </div>
      </div>
    );
  }

  const wc = WISH_COLOR_META[room?.wishColor ?? "hope"] ?? WISH_COLOR_META.hope;
  const paper = PAPER_META[room?.paper ?? "hanji"] ?? PAPER_META.hanji;
  const displayText = room?.text || text || "";
  // [버그 방지] 닉네임 미설정 사용자는 owner/ownerNickname이 빈 문자열("")로
  // 내려올 수 있다 — "??"는 null/undefined만 걸러내고 ""는 그대로 통과시켜
  // "님이 소원방에 초대했어요"처럼 이름이 빈 채로 보이는 문제가 생겼다
  // (실제 테스트 데이터로 라이브 확인 중 발견). "||"로 교체해 빈 문자열도
  // 폴백되게 한다.
  const displayOwner = room?.owner || ownerNickname || "누군가";
  const displayLevel = room?.level ?? level ?? 1;
  const displayLevelName = room?.levelName || levelName || "";
  const displayDaysLit = room?.daysLit ?? daysLit ?? 1;

  return (
    <>
      {/* [설치 유도 배너 — 보조 수단으로 축소] 지시서: "웹에서 초대시 그대로
          그 사람의 소원방으로 바로 들어가게" — 이 페이지 자체가 이제 실제
          방 콘텐츠를 보여주므로, 앱 설치는 더 이상 필수 경로가 아니라
          선택적 대안으로만 남긴다. */}
      <div className="sticky top-0 z-10 flex items-center justify-between gap-3 bg-[#2A2438] px-4 py-2.5 text-white">
        <span className="text-[12px] leading-snug">
          신통방통 앱에서 더 다양한 운세를 만나보세요
        </span>
        <a
          href="https://play.google.com/store/apps/details?id=com.fortunefusion.fortune"
          className="shrink-0 rounded-full bg-white px-3 py-1 text-[11px] font-bold text-[#2A2438]"
        >
          앱 설치
        </a>
      </div>

      <section className="relative overflow-hidden">
        <div className="relative mx-auto w-full max-w-[440px] px-5 pt-6 pb-6">
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

          <div className="mb-4 inline-flex items-center gap-2 whitespace-nowrap rounded-full border border-[#F5D9C9] bg-[#FBEFE8] px-3 py-1.5">
            <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#C99B7F]" />
            <span className="whitespace-nowrap text-[11px] font-semibold text-[#A6795E]">
              소원방 초대
            </span>
          </div>

          <h1
            style={{ fontFamily: SERIF }}
            className="mb-3 text-[26px] font-bold leading-[1.35] tracking-tight text-[#2A2438]"
          >
            {displayOwner}님이
            <br />
            소원방에 초대했어요
          </h1>

          {/* [핵심 신설] 실제 소원방 — 한지 색/소원 빛깔을 그대로 재현한
              카드. owner가 보는 자기 방과 동일한 시각 언어(papers·wishColor)
              를 써서, "그 사람 방에 들어왔다"는 느낌을 준다. */}
          <div
            className="mb-4 overflow-hidden rounded-3xl shadow-[0_4px_20px_-8px_rgba(166,121,94,0.2)]"
            style={{
              backgroundImage: `linear-gradient(180deg, ${paper.bg[0]}, ${paper.bg[1]})`,
            }}
          >
            <div className="p-5">
              <div className="mb-3 flex items-center gap-2">
                <div
                  className="flex h-8 w-8 items-center justify-center rounded-lg text-[16px] font-black"
                  style={{ backgroundColor: wc.deep, color: "#fff9e8", fontFamily: SERIF }}
                >
                  {wc.hanja}
                </div>
                <div>
                  <p className="text-[12px] font-semibold" style={{ color: paper.ink, opacity: 0.6 }}>
                    {displayDaysLit}일째 밝히는 중 · Lv.{displayLevel} {displayLevelName}
                  </p>
                  <p className="text-[11px]" style={{ color: paper.ink, opacity: 0.5 }}>
                    {wc.label}의 소원
                  </p>
                </div>
              </div>
              <p
                className="text-[16px] leading-relaxed"
                style={{ fontFamily: "'Gowun Batang', serif", color: paper.ink, fontWeight: 700 }}
              >
                &quot;{displayText}&quot;
              </p>
            </div>

            {/* 통계 칩 — ❤ 응원 · 💬 메시지 · 福 복주머니 (실제 서버 값) */}
            {room && (
              <div className="flex items-center gap-4 border-t border-black/5 bg-black/5 px-5 py-2.5">
                <span className="text-[12px] font-bold" style={{ color: paper.ink }}>
                  ❤ {room.supportCount}
                </span>
                <span className="text-[12px] font-bold" style={{ color: paper.ink }}>
                  💬 {room.commentCount}
                </span>
                <span className="text-[12px] font-bold" style={{ color: paper.ink }}>
                  福 {room.pouchReceived}
                </span>
              </div>
            )}
          </div>

          {!room && !loadError && (
            <p className="mb-4 text-center text-[12px] text-[#A08C82]">소원방을 불러오는 중이에요...</p>
          )}

          {/* [핵심 신설] 참여 액션 3종 — 실제 API는 로그인(JWT)을 요구하므로
              누르면 회원가입 안내 패널만 뜬다. 기존 supports/comments/gifts
              API는 전혀 수정하지 않는다. */}
          <div className="mb-4 grid grid-cols-3 gap-2">
            <button
              onClick={() => setGatePanel("support")}
              className="flex flex-col items-center gap-1 rounded-2xl border border-[#E8DDD0] bg-white/85 py-3 text-[#2A2438] active:scale-[0.97]"
            >
              <span className="text-[20px]">❤</span>
              <span className="text-[11px] font-semibold">응원하기</span>
            </button>
            <button
              onClick={() => setGatePanel("message")}
              className="flex flex-col items-center gap-1 rounded-2xl border border-[#E8DDD0] bg-white/85 py-3 text-[#2A2438] active:scale-[0.97]"
            >
              <span className="text-[20px]">💬</span>
              <span className="text-[11px] font-semibold">응원 메시지</span>
            </button>
            <button
              onClick={() => setGatePanel("gift")}
              className="flex flex-col items-center gap-1 rounded-2xl border border-[#E8DDD0] bg-white/85 py-3 text-[#2A2438] active:scale-[0.97]"
            >
              <span className="text-[20px]">🧧</span>
              <span className="text-[11px] font-semibold">복주머니</span>
            </button>
          </div>

          {/* 응원 메시지 목록 — 기존 사람들이 남긴 응원(로그인 없이도 조회 가능) */}
          {comments.length > 0 && (
            <div className="mb-4 rounded-3xl border border-[#E8DDD0] bg-white/85 p-4">
              <p className="mb-2 text-[12px] font-bold text-[#A6795E]">도착한 마음 {comments.length}</p>
              <div className="max-h-[180px] space-y-2 overflow-y-auto">
                {comments.map((c) => (
                  <div key={c.id} className="text-left">
                    <p className="text-[11px] font-bold text-[#C9879B]">{c.author}</p>
                    <p className="text-[13px] text-[#2A2438]">{c.text}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 회원가입 안내 패널 — 참여 액션 버튼을 눌렀을 때만 노출 */}
          {gatePanel && (
            <div className="mb-4 rounded-3xl border border-[#F5D9C9] bg-[#FBEFE8] p-5 text-center">
              <p className="mb-2 text-[14px] font-bold text-[#2A2438]">
                {gatePanel === "support" && "응원하기는 회원가입 후 이용할 수 있어요"}
                {gatePanel === "message" && "응원 메시지는 회원가입 후 남길 수 있어요"}
                {gatePanel === "gift" && "복주머니 보내기는 회원가입 후 이용할 수 있어요"}
              </p>
              <p className="mb-4 text-[12px] text-[#6E5A54]">
                신통방통 가입은 1분이면 충분해요. 가입 후 바로 이 소원방에 참여할 수 있어요.
              </p>
              <a
                href={SINTONG_SIGNUP_URL}
                className="mb-2 block w-full rounded-2xl py-3 text-center text-[14px] font-bold text-white"
                style={{ backgroundImage: "linear-gradient(90deg, #A6795E, #E8B4A5)" }}
              >
                신통방통 회원가입하기
              </a>
              <button
                onClick={() => setGatePanel(null)}
                className="text-[12px] text-[#A08C82] underline"
              >
                닫기
              </button>
            </div>
          )}

          <button
            onClick={() => {
              setAttemptedAppOpen(true);
              tryOpenApp(token);
            }}
            className="w-full rounded-2xl border border-[#E8DDD0] bg-white/60 py-3 text-center text-[13px] font-bold text-[#A6795E]"
          >
            앱으로 열기
          </button>
          {attemptedAppOpen && (
            <p className="mt-2 text-center text-[11px] text-[#A08C82]">
              앱이 설치되어 있지 않다면 위 설치 버튼을 눌러주세요.
            </p>
          )}
        </div>
      </section>

      <footer className="mx-auto w-full max-w-[440px] border-t border-[#E8DDD0] px-5 pt-5 pb-2 text-center">
        <p className="text-[10px] text-[#A08C82]">© 2026 Sintongbangtong. All rights reserved.</p>
      </footer>
    </>
  );
}
