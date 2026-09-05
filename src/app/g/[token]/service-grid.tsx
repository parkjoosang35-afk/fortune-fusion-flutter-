"use client";

// [귀인지도 바이럴 랜딩 - ServiceGrid 신설, 2026-09] 사용자 명시 요구사항:
// "소원방 누르면 신통방통 소원방, 타로 누르면 신통방통 타로로 들어가야
// 하는데 왜 이게 안돼?" — 실제 코드 조사 결과 이 4개 카드(소원방/타로/
// 정통사주/오늘의 운세) 자체가 지금까지 랜딩페이지에 전혀 구현되어 있지
// 않았다(첨부 디자인 목업에만 있던 레이아웃). 이 컴포넌트가 그 카드를
// 신설하고, "내 지도 만들기" 버튼(`openAppOrFallback`)과 동일한 딥링크+
// 폴백 패턴으로 각 서비스에 "즉시 이동"시킨다.
//
// [딥링크 스킴] `fortunefusion://svc/{key}` (앱 설치 시 즉시 처리 —
// Flutter GuinjiDeepLinkHandler._serviceRouteFor 참고). 앱이 없으면
// 1.5초 후 플레이스토어 안내로 폴백한다(openAppOrFallback과 동일 원칙 —
// 자동 강제 전환 없음, 사용자가 카드를 "직접 눌렀을 때"만 전환 시도).
//
// [바이럴 원칙 재확인] 귀인지도 결과 자체(케미 점수/관계지도 그래프)는
// 이미 이 웹페이지 안에서 완결된다. 이 ServiceGrid는 "다른 신통방통
// 서비스도 궁금하면" 눌러보는 선택적 다음 단계일 뿐, 결과 확인의 필수
// 경로가 아니다.
import { useState, type ReactElement } from "react";

const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.fortunefusion.fortune";

type ServiceKey = "wish-room" | "tarot" | "jeontong" | "today";

const SERVICES: { key: ServiceKey; title: string; desc: string; color: string }[] = [
  { key: "wish-room", title: "소원방", desc: "간절한 소망을\n담아 빌어봐요", color: "#E8B4A5" },
  { key: "tarot", title: "타로", desc: "오늘의 마음\n방향을 살펴요", color: "#D4A574" },
  { key: "jeontong", title: "정통사주", desc: "만세력 기반\n정통 사주 풀이", color: "#C99B7F" },
  { key: "today", title: "오늘의 운세", desc: "매일 새롭게\n갱신되는 운세", color: "#7E5A47" },
];

const ICONS: Record<ServiceKey, ReactElement> = {
  "wish-room": (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <path d="M12 2C8.5 6 6 8.5 6 12a6 6 0 0012 0c0-3.5-2.5-6-6-10z" />
      <circle cx="12" cy="13" r="2" />
    </svg>
  ),
  tarot: (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <rect x="6" y="3" width="12" height="18" rx="2" />
      <path d="M12 8v8M9 12h6" />
    </svg>
  ),
  jeontong: (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <circle cx="12" cy="12" r="9" />
      <path d="M12 3v18M3 12h18M5.6 5.6l12.8 12.8M18.4 5.6L5.6 18.4" />
    </svg>
  ),
  today: (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" />
    </svg>
  ),
};

function openServiceOrFallback(key: ServiceKey, setFallbackKey: (k: ServiceKey | null) => void) {
  const deepLink = `fortunefusion://svc/${key}`;
  const start = Date.now();
  window.location.href = deepLink;
  window.setTimeout(() => {
    if (Date.now() - start < 5000 && document.visibilityState === "visible") {
      setFallbackKey(key);
    }
  }, 1500);
}

export function ServiceGrid() {
  const [fallbackKey, setFallbackKey] = useState<ServiceKey | null>(null);

  return (
    <div className="rounded-3xl border border-[#E8DDD0] bg-white/85 p-5 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
      <div className="mb-4 text-center">
        <div className="mb-1 text-[11px] font-semibold uppercase tracking-widest text-[#A6795E]">
          신통방통 다른 서비스
        </div>
        <h3 style={{ fontFamily: "'Noto Serif KR', serif" }} className="text-[16px] font-bold text-[#2A2438]">
          신통방통에서 더 많은 운세를 만나보세요
        </h3>
      </div>
      <div className="grid grid-cols-4 gap-2">
        {SERVICES.map((s) => (
          <button
            key={s.key}
            type="button"
            onClick={() => openServiceOrFallback(s.key, setFallbackKey)}
            className="group relative rounded-2xl border border-[#E8DDD0] bg-white p-3 text-center transition hover:shadow-[0_8px_32px_-12px_rgba(166,121,94,0.22)]"
          >
            <span className="absolute right-2 top-2 rounded-full bg-[#C99B7F] px-1.5 py-0.5 text-[8px] font-bold uppercase tracking-wider text-white">
              Free
            </span>
            <div
              className="mx-auto mb-2 flex h-11 w-11 items-center justify-center rounded-2xl"
              style={{ backgroundColor: `${s.color}20`, color: s.color }}
            >
              {ICONS[s.key]}
            </div>
            <div className="mb-0.5 text-[12px] font-semibold text-[#2A2438]">{s.title}</div>
            <div className="whitespace-pre-line text-[9.5px] leading-tight text-[#6E5A54]">{s.desc}</div>
            <div className="mt-1.5 text-[9.5px] text-[#A6795E]">바로가기 →</div>
          </button>
        ))}
      </div>

      {fallbackKey && (
        <div className="mt-3 rounded-2xl border border-[#E8DDD0] bg-white p-3">
          <p className="mb-2 text-xs text-[#6E5A54]">
            앱이 설치되어 있지 않은 것 같아요. 스토어에서 신통방통을 설치하면
            {" "}
            {SERVICES.find((s) => s.key === fallbackKey)?.title}을 바로 이용할 수 있어요.
          </p>
          <a
            href={PLAY_STORE_URL}
            className="block w-full rounded-xl bg-[#2A2438] px-4 py-2 text-center text-xs font-bold text-white"
          >
            신통방통 설치하기
          </a>
        </div>
      )}
    </div>
  );
}
