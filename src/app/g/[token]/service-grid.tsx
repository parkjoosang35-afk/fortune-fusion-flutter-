"use client";

// [귀인지도 바이럴 랜딩 - ServiceGrid, 2026-09 웹 전환 최종 확정] 사용자
// 명시 지시: 이 페이지는 웹이므로, 소원방/타로/정통사주/오늘의 운세 카드는
// 앱 설치를 유도하는 딥링크+폴백이 아니라 `https://sintong.kr/app/`에
// 이미 배포된 신통방통 메인(Flutter Web)의 해당 화면으로 곧바로 이동한다.
//
// [바이럴 원칙 재확인] 귀인지도 결과 자체(케미 점수/관계지도 그래프)는
// 이미 이 웹페이지 안에서 완결된다. 이 ServiceGrid는 "다른 신통방통
// 서비스도 궁금하면" 눌러보는 선택적 다음 단계일 뿐, 결과 확인의 필수
// 경로가 아니다.
import { type ReactElement } from "react";
import { SINTONG_WEB_URLS } from "./sintong-web-urls";

type ServiceKey = "wish-room" | "tarot" | "jeontong" | "today";

// [귀인지도 랜딩 "다른 서비스" 카드 균형 버그수정 — 2026-12] 기존 desc
// 문구("간절한 소망을\n담아 빌어봐요" 등)가 좁은 4열 그리드 카드 폭에서
// 다시 자동 줄바꿈되어 조사·종결어미가 단독 줄로 떨어지고, 카드마다
// 텍스트 줄 수(2~4줄)가 달라져 "바로가기" 위치가 서로 어긋나 보였다
// ("귀인지도 글씨하고 균형이 안맞는데" 리포트 — Flutter 앱의 동일 컴포넌트
// `guinji_map_landing_widgets.dart`의 `GmServiceGrid`와 완전히 같은 원인).
// 문구를 각 줄 6자 이내로 짧게 다듬어 재줄바꿈 가능성을 낮췄다. 제목도
// "오늘의 운세"(5글자)가 카드 폭에서 줄바꿈되던 것을 "오늘 운세"(4글자)로
// 줄였다. 카드 레이아웃 자체(고정 높이 지정)도 아래에서 함께 수정한다.
const SERVICES: { key: ServiceKey; title: string; desc: string; color: string; url: string }[] = [
  { key: "wish-room", title: "소원방", desc: "소망을 담아\n빌어보세요", color: "#E8B4A5", url: SINTONG_WEB_URLS.wishRoom },
  { key: "tarot", title: "타로", desc: "마음의 방향을\n살펴보세요", color: "#D4A574", url: SINTONG_WEB_URLS.tarot },
  { key: "jeontong", title: "정통사주", desc: "만세력 기반\n사주 풀이", color: "#C99B7F", url: SINTONG_WEB_URLS.jeontong },
  { key: "today", title: "오늘 운세", desc: "매일 새롭게\n갱신돼요", color: "#7E5A47", url: SINTONG_WEB_URLS.todayFortune },
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

export function ServiceGrid() {
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
          <a
            key={s.key}
            href={s.url}
            // [균형 버그수정] flex-col + 고정 높이 텍스트 박스로, 카드마다
            // 실제 텍스트 줄 수(1줄/2줄)가 달라도 아이콘·제목·설명·
            // "바로가기"의 세로 위치가 4개 카드에서 항상 동일하게 정렬된다.
            className="group relative flex flex-col items-center rounded-2xl border border-[#E8DDD0] bg-white p-3 text-center transition hover:shadow-[0_8px_32px_-12px_rgba(166,121,94,0.22)]"
          >
            <span className="absolute right-2 top-2 rounded-full bg-[#C99B7F] px-1.5 py-0.5 text-[8px] font-bold uppercase tracking-wider text-white">
              Free
            </span>
            <div
              className="mb-2 flex h-11 w-11 items-center justify-center rounded-2xl"
              style={{ backgroundColor: `${s.color}20`, color: s.color }}
            >
              {ICONS[s.key]}
            </div>
            {/* 제목: 1줄 고정(넘치면 말줄임) — "오늘 운세"처럼 4글자라도
                카드 폭에서 재줄바꿈되지 않도록 nowrap+ellipsis. */}
            <div className="mb-0.5 w-full truncate whitespace-nowrap text-[12px] font-semibold text-[#2A2438]">
              {s.title}
            </div>
            {/* 설명: 항상 2줄 높이(leading-tight 9.5px * 2 ≈ 24px)만
                차지하도록 고정 높이 박스에 담아, 실제 줄 수가 1줄이든
                2줄이든 아래 "바로가기"가 카드마다 밀리지 않게 한다. */}
            <div className="flex h-6 w-full items-start justify-center whitespace-pre-line text-[9.5px] leading-tight text-[#6E5A54]">
              {s.desc}
            </div>
            <div className="mt-auto pt-1.5 text-[9.5px] text-[#A6795E]">바로가기 →</div>
          </a>
        ))}
      </div>
      <p className="mt-3 text-center text-[11px] text-[#A08C82]">
        설치 없이 바로 열려요 · 신통방통 웹
      </p>
    </div>
  );
}
