"use client";

// [결과 공유 랜딩 — 클라이언트 뷰] 서버 컴포넌트(page.tsx)가 조회한 데이터를
// 그대로 받아 렌더링만 담당한다(OG 메타태그는 이미 서버에서 generateMetadata로
// 처리 완료 — 이 컴포넌트는 화면 본문에만 관여).
//
// [앱 설치자 대응] Android App Links(autoVerify, pathPrefix="/r")가 정상
// 검증되면 OS가 이 페이지 자체를 열지 않고 앱을 직접 띄운다. 이 페이지가
// 보인다는 것은 "미설치 또는 검증 실패" 상태라는 뜻이므로, 상단에 설치
// 유도 배너를 항상 노출한다(guinji `/g/[token]` 2단계 구조와 동일 원칙).
// "앱에서 보기" 버튼은 커스텀 스킴(`fortunefusion://r/{shareId}`)을 먼저
// 시도해, 실제로 앱이 설치돼 있는데 App Links 검증만 실패한 케이스도
// 구제한다(guinji `g` host와 동일한 폴백 스킴 컨벤션).
import { useState } from "react";

type ViewState = "ok" | "not_found" | "error";

type SharedResultViewProps = {
  shareId: string;
  state: ViewState;
  title?: string;
  description?: string;
  resultType?: string;
  resultTypeLabel?: string;
  payload?: unknown;
  ownerNickname?: string;
};

const SERIF = "'Noto Serif KR', serif";

function tryOpenApp(shareId: string) {
  // [Android App Links 검증 실패/iOS 폴백 대응] 커스텀 스킴 우선 시도.
  window.location.href = `fortunefusion://r/${shareId}`;
}

/** payload는 결과 타입별로 자유 형식이므로, 알려진 키만 골라 안전하게
 * 화면에 나열한다(임의 객체를 그대로 JSON.stringify해 노출하지 않음 —
 * 혹시 모를 예기치 않은 필드 노출을 방지하는 최소한의 안전장치). */
function renderPayloadLines(payload: unknown): string[] {
  if (!payload || typeof payload !== "object") return [];
  const obj = payload as Record<string, unknown>;
  const lines: string[] = [];
  if (typeof obj.summary === "string" && obj.summary) lines.push(obj.summary);
  if (Array.isArray(obj.highlights)) {
    for (const h of obj.highlights) {
      if (typeof h === "string") lines.push(h);
    }
  }
  if (typeof obj.category === "string" && obj.category) lines.push(`카테고리: ${obj.category}`);
  return lines.slice(0, 6);
}

export function SharedResultView({
  shareId,
  state,
  title,
  description,
  resultTypeLabel,
  payload,
}: SharedResultViewProps) {
  const [attemptedAppOpen, setAttemptedAppOpen] = useState(false);
  const payloadLines = renderPayloadLines(payload);

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
          <h1 style={{ fontFamily: SERIF }} className="mb-4 text-xl font-bold text-[#2A2438]">
            결과를 찾을 수 없어요
          </h1>
          <p className="mb-2 text-sm leading-relaxed text-[#6E5A54]">
            링크가 잘못되었거나
            <br />
            공유한 사람이 링크를 삭제했을 수 있어요.
          </p>
        </div>
      </div>
    );
  }

  return (
    <>
      {/* [설치 유도 배너] App Links 검증 실패/미설치 상태에서만 이 페이지가
          보이므로 항상 상단에 노출한다. */}
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

          {resultTypeLabel && (
            <div className="mb-4 inline-flex items-center gap-2 whitespace-nowrap rounded-full border border-[#F5D9C9] bg-[#FBEFE8] px-3 py-1.5">
              <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#C99B7F]" />
              <span className="whitespace-nowrap text-[11px] font-semibold text-[#A6795E]">
                {resultTypeLabel}
              </span>
            </div>
          )}

          <h1
            style={{ fontFamily: SERIF }}
            className="mb-3 text-[28px] font-bold leading-[1.3] tracking-tight text-[#2A2438]"
          >
            {title}
          </h1>
          {description && (
            <p className="mb-5 text-[14px] leading-relaxed text-[#6E5A54]">{description}</p>
          )}

          {payloadLines.length > 0 && (
            <div className="mb-5 space-y-2 rounded-3xl border border-[#E8DDD0] bg-white/85 p-4 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
              {payloadLines.map((line, i) => (
                <p key={i} className="text-[13.5px] leading-relaxed text-[#2A2438]">
                  {line}
                </p>
              ))}
            </div>
          )}

          <button
            onClick={() => {
              setAttemptedAppOpen(true);
              tryOpenApp(shareId);
            }}
            className="w-full rounded-2xl py-3.5 text-center text-[15px] font-bold text-white shadow-[0_4px_20px_-4px_rgba(166,121,94,0.4)]"
            style={{ backgroundImage: "linear-gradient(90deg, #A6795E, #E8B4A5)" }}
          >
            앱에서 전체 결과 보기
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
