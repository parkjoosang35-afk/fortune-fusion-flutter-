// [애드센스 승인 개선 — 2026-11-02] 신통방통 전체 서비스 가이드 SSR 페이지.
//
// [배경] /saju/page.tsx와 동일한 목적 — AdSense "게시자 콘텐츠가 없는
// 화면에 광고 게재" 거부 사유를 해소하기 위해, 7개 서비스를 실제 구현된
// 기능 기준으로 소개하는 독창적 설명 콘텐츠를 제공한다.
//
// [내용 검증 — 2026-11-02 코드 직접 확인 후 작성]
//  · 소원방: lib/features/wishroom/** — 운세 예측 기능이 아니라 촛불
//    제단에 소원을 올려 매일 치성(정성)을 쌓아 성장시키는 개인 리추얼
//    공간(WishGrowthStage 5단계: 불씨→작은 촛불→안정된 촛불→환한 촛불→
//    황금 성화). docs/WISH_ROOM_DESIGN_DOC.md 기준.
//  · 관상/손금: lib/features/fortune/face·palm/** — 사진 촬영/업로드 →
//    Vision LLM 분석(admin_web src/app/api/public/fortune/face·palm/
//    route.ts). 이미지는 분석 요청에만 사용되고 서버 DB/파일시스템에
//    저장되지 않음(inputPayload에는 hasImage 플래그만 저장) — 2026-11-02
//    코드 전수 확인 완료.
//  · 신당부적: lib/features/shrine/** — 사연+사주 기반으로 "자동 생성이
//    아니라 한 장씩 손으로 쓰는" 부적(기존 UI 문구 그대로 반영).
//  · 정통사주/귀인지도/타로: 기존 landing-v7-content.js 카피의 취지를
//    유지하되, 확정적 어투를 참고 정보 어투로 교정.
//
// [문구 승인 상태] 2026-11-02 사용자 승인 완료.
// [범위] 신규 생성 파일. 기존 Flutter 앱/API/회원가입/공유 기능 미변경.
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "서비스 가이드 | 신통방통",
  description:
    "정통사주, 귀인지도, 타로, 소원방, 관상, 손금, 신당부적 — 신통방통이 제공하는 7가지 서비스를 소개합니다.",
};

function ServiceCard({
  tag,
  title,
  children,
}: {
  tag: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mb-7 rounded-xl border border-slate-200 p-5">
      <p className="mb-1 text-xs font-semibold tracking-wide text-amber-700">
        {tag}
      </p>
      <h2 className="mb-2 text-base font-bold text-slate-900">{title}</h2>
      <p className="text-sm leading-relaxed text-slate-700">{children}</p>
    </section>
  );
}

export default function GuidePage() {
  return (
    <div className="mx-auto min-h-screen max-w-3xl px-6 py-12">
      <header className="mb-10 border-b border-slate-200 pb-6">
        <h1 className="text-2xl font-bold text-slate-900">
          신통방통 서비스 안내
        </h1>
        <p className="mt-2 text-sm leading-relaxed text-slate-500">
          신통방통은 동양 전통 명리학에 기반한 분석 서비스와, 소원을
          기록하고 키워가는 리추얼 공간을 함께 제공합니다. 각 서비스는
          보는 관점과 쓰임이 다릅니다.
        </p>
      </header>

      <ServiceCard tag="四柱 · 命" title="정통사주">
        생년월일시로 세운 원국·대운·세운을 원전 명리학의 원칙으로
        해석합니다. 타고난 기질과 인생의 장기적 흐름을 참고하고 싶을 때
        확인하는 서비스입니다. 자세한 해석 기준은{" "}
        <a href="/saju" className="text-indigo-600 underline">
          정통사주 안내 페이지
        </a>
        에서 확인하실 수 있습니다.
      </ServiceCard>

      <ServiceCard tag="貴人 · 緣" title="귀인지도">
        사주 원국을 바탕으로, 나에게 도움이 되는 사람이 어떤 모습으로
        언제 나타날 수 있는지를 짚어보는 인연 분석입니다.
      </ServiceCard>

      <ServiceCard tag="ARCANA · 卜" title="타로">
        사주가 인생 전체의 흐름을 본다면, 타로는 지금 이 순간의 구체적인
        질문에 카드로 답을 찾아보는 방식입니다. 연애, 이직, 선택의
        갈림길처럼 당장 마주한 고민이 있을 때 활용합니다.
      </ServiceCard>

      <ServiceCard tag="所願 · 願" title="소원방">
        이루고 싶은 소원을 촛불 제단 위에 올려두고, 매일 정성(치성)을
        쌓아가며 소원을 키워가는 개인 공간입니다. 정성이 쌓일수록 촛불이
        불씨에서 성화로 성장하는 과정을 눈으로 확인할 수 있으며, 연속
        방문 기록에 따라 공간 전체의 분위기도 함께 달라집니다. 운세를
        예측하는 기능이 아니라, 소원을 꾸준히 되새기고 다짐을 이어가도록
        돕는 리추얼(의식) 공간입니다.
      </ServiceCard>

      <ServiceCard tag="觀相 · 觀" title="관상">
        얼굴 사진을 촬영하거나 선택해 올리면, AI가 이목구비의 특징을
        분석해 전통 관상학적 해석을 제공합니다. 촬영한 사진은 분석 즉시
        파기되며 저장되지 않습니다.
      </ServiceCard>

      <ServiceCard tag="手紋 · 紋" title="손금">
        손바닥 사진을 촬영하거나 선택해 올리면, AI가 손금의 선(인생선·
        지혜선·감정선 등)을 분석해 전통 손금학적 해석을 제공합니다. 역시
        촬영한 사진은 분석 후 저장되지 않습니다.
      </ServiceCard>

      <ServiceCard tag="神堂 · 符" title="신당부적">
        사용자가 전한 사연과 사주를 바탕으로, 한 장 한 장 손으로 쓰는
        부적을 받을 수 있는 서비스입니다. 자동으로 생성되는 것이 아니라
        사람이 직접 작성하며, 정해진 기간 동안 보관하며 의미를 되새길 수
        있도록 안내합니다.
      </ServiceCard>

      <section className="mb-8 mt-10">
        <h2 className="mb-3 text-lg font-bold text-slate-900">
          어떤 순서로 보면 좋을까요
        </h2>
        <p className="text-sm leading-relaxed text-slate-700">
          먼저 <strong>정통사주</strong>로 타고난 바탕과 큰 흐름을 참고하고,
          지금 당장의 구체적인 고민은 <strong>타로</strong>로, 사람과의
          관계가 궁금하면 <strong>귀인지도</strong>로 확인해보시길 권합니다.
          이루고 싶은 목표나 바람이 있다면 <strong>소원방</strong>에서
          꾸준히 정성을 쌓아보세요. 관상·손금은 사주 해석을 보완하는 또
          다른 관점으로 참고하시면 좋습니다.
        </p>
      </section>

      <div className="mt-10 rounded-xl border border-amber-200 bg-amber-50 p-5 text-sm leading-relaxed text-amber-900">
        <p className="font-semibold">안내</p>
        <p className="mt-1">
          신통방통이 제공하는 모든 분석(사주·타로·관상·손금·귀인지도)은
          전통 명리학·점술 이론에 근거한 해석이며, 미래나 결과를 보장하거나
          단정하지 않습니다. 참고 정보로 활용해 주시기 바랍니다.
        </p>
      </div>

      <footer className="mt-12 border-t border-slate-200 pt-6 text-xs text-slate-400">
        <a href="/saju" className="underline hover:text-slate-600">
          정통사주 안내 자세히 보기
        </a>
      </footer>
    </div>
  );
}
