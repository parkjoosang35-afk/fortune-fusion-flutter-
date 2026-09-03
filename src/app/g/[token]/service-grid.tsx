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
import { useState } from "react";

const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.fortunefusion.fortune";

type ServiceKey = "wish-room" | "tarot" | "jeontong" | "today";

const SERVICES: { key: ServiceKey; label: string; emoji: string }[] = [
  { key: "wish-room", label: "소원방", emoji: "🕯️" },
  { key: "tarot", label: "타로", emoji: "🔮" },
  { key: "jeontong", label: "정통사주", emoji: "📜" },
  { key: "today", label: "오늘의 운세", emoji: "🌙" },
];

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
      <p className="mb-3 text-center text-xs font-medium text-[#A08C82]">
        신통방통의 다른 서비스도 만나보세요
      </p>
      <div className="grid grid-cols-4 gap-2">
        {SERVICES.map((s) => (
          <button
            key={s.key}
            type="button"
            onClick={() => openServiceOrFallback(s.key, setFallbackKey)}
            className="flex flex-col items-center gap-1.5 rounded-2xl border border-[#E8DDD0] bg-white px-1 py-3 text-center transition hover:border-[#C99B7F]/50 hover:bg-[#FBEFE8]"
          >
            <span className="text-2xl">{s.emoji}</span>
            <span className="text-[11px] font-medium text-[#6E5A54]">{s.label}</span>
          </button>
        ))}
      </div>

      {fallbackKey && (
        <div className="mt-3 rounded-2xl border border-[#E8DDD0] bg-white p-3">
          <p className="mb-2 text-xs text-[#6E5A54]">
            앱이 설치되어 있지 않은 것 같아요. 스토어에서 신통방통을 설치하면
            {" "}
            {SERVICES.find((s) => s.key === fallbackKey)?.label}을 바로 이용할 수 있어요.
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
