// [애드센스 승인 개선 — 2026-11-02] 정통사주 안내 SSR 페이지.
//
// [배경] AdSense가 "게시자 콘텐츠가 없는 화면에 광고 게재"를 승인 거부
// 사유로 지적했다. 이 페이지는 정통사주(원국·대운·세운) 개념을 원전
// 명리학 기준으로 설명하는 독창적 설명 콘텐츠를 제공해, 검색엔진/광고
// 심사 크롤러가 읽을 수 있는 실제 콘텐츠를 갖춘 공개 페이지로 만든다.
//
// [경로 충돌 없음 확인] 운영 nginx는 `location /saju/`(트레일링 슬래시
// 포함, prefix match)만 사주 엔진 FastAPI(127.0.0.1:8000)로 프록시한다.
// 슬래시 없이 정확히 `/saju`로 들어오는 요청은 이 블록에 매치되지 않고
// `location /`(admin_web Next.js, 127.0.0.1:3000)로 전달되므로, 이
// Next.js 페이지(`src/app/saju/page.tsx`)가 정상적으로 서빙된다.
// (2026-11-02 운영 nginx -T 재확인 — 충돌 없음)
//
// [문구 승인 상태] 2026-11-02 사용자 승인 완료 — "단정적 표현 금지, 전통
// 명리학 참고 정보" 원칙 반영판. 실제 구현된 기능(엔진 API 연동)과 일치.
//
// [범위 — 최소 수정 원칙] 이 페이지는 신규 생성 파일이며, 기존 Flutter 앱/
// 사주 엔진 API/회원가입/공유 기능 코드는 전혀 건드리지 않는다. AdSense
// 로더는 AdSenseLoader.tsx의 화이트리스트(AD_ALLOWED_PATHS)에 이미
// "/saju"가 포함되어 있어 별도 조치 없이 이 페이지에서 광고가 허용된다.
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "정통사주 안내 | 신통방통",
  description:
    "원국·대운·세운, 원전 명리학의 원칙으로 정통사주를 이해하는 방법. 신통방통이 사주를 해석하는 기준을 소개합니다.",
};

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mb-8">
      <h2 className="mb-3 text-lg font-bold text-slate-900">{title}</h2>
      <div className="space-y-3 text-sm leading-relaxed text-slate-700">
        {children}
      </div>
    </section>
  );
}

export default function SajuGuidePage() {
  return (
    <div className="mx-auto min-h-screen max-w-3xl px-6 py-12">
      <header className="mb-10 border-b border-slate-200 pb-6">
        <p className="mb-2 text-xs font-semibold tracking-wide text-amber-700">
          四柱 · 原典
        </p>
        <h1 className="text-2xl font-bold text-slate-900">
          정통사주, 원전으로 풀어내는 나의 사주
        </h1>
        <p className="mt-2 text-sm text-slate-500">
          신통방통이 정통사주를 해석하는 기준에 대한 안내입니다.
        </p>
      </header>

      <p className="mb-8 text-sm leading-relaxed text-slate-700">
        사주명리학은 생년월일시를 네 개의 기둥(四柱)으로 세우고, 그 안에
        담긴 오행(五行)과 십신(十神)의 흐름을 읽어 한 사람의 타고난 기질과
        인생의 흐름을 가늠해보는 동양의 전통 학문입니다. 신통방통의
        정통사주는 원전 명리학의 원칙 위에서, 다음 세 가지 층위를 순서대로
        풀어드립니다.
      </p>

      <Section title="1. 원국(原局) — 타고난 바탕">
        <p>
          태어난 순간의 연주·월주·일주·시주, 네 기둥에 새겨진 천간과 지지의
          조합을 원국이라 부릅니다. 원국은 &lsquo;타고난 설계도&rsquo;로,
          성격의 뿌리와 타고난 기운의 강약을 보여줍니다. 신통방통은 이
          원국을 십신(비견·겁재·식신·상관·편재·정재·편관·정관·편인·정인)의
          구조로 분해해, 어떤 기운이 강하고 어떤 기운이 약한지부터
          짚어드립니다.
        </p>
      </Section>

      <Section title="2. 대운(大運) — 10년 단위의 흐름">
        <p>
          원국이라는 설계도 위로 흘러가는 10년 단위의 흐름이 대운입니다.
          같은 사주를 타고났어도 대운이 어느 방향으로 흐르느냐에 따라
          살아가는 국면이 달라진다고 보는 것이 명리학의 전통적인 해석
          방식입니다.
        </p>
      </Section>

      <Section title="3. 세운(歲運) — 한 해의 흐름">
        <p>
          대운이라는 큰 흐름 위에 한 해 단위로 더해지는 것이 세운입니다.
          올해의 간지가 원국·대운과 어떻게 어우러지는지를 참고하면, 한 해의
          흐름을 가늠하는 데 참고가 됩니다.
        </p>
      </Section>

      <Section title="신통방통 정통사주의 해석 방식">
        <p>
          신통방통의 정통사주는 생년월일시만으로 정형화된 문구를 보여주는
          방식이 아니라, 원국·대운·세운을 순서대로 쌓아 해석하는 원전
          명리학의 절차를 그대로 따르며, 십신과 오행의 상생상극 관계를
          짚어 해석의 근거를 함께 제시하는 것을 원칙으로 합니다.
        </p>
      </Section>

      <div className="mt-10 rounded-xl border border-amber-200 bg-amber-50 p-5 text-sm leading-relaxed text-amber-900">
        <p className="font-semibold">안내</p>
        <p className="mt-1">
          본 콘텐츠는 전통 명리학 이론에 대한 일반적인 소개이며, 특정
          개인의 미래나 결과를 단정하지 않습니다. 명리학은 참고할 만한
          전통적 해석 체계이며, 실제 선택과 결정은 본인의 상황과 판단에
          따라 이루어져야 합니다. 개인별 사주 해석은 앱 내 &lsquo;정통사주&rsquo;
          메뉴에서 생년월일시를 입력해 확인하실 수 있습니다.
        </p>
      </div>

      <footer className="mt-12 border-t border-slate-200 pt-6 text-xs text-slate-400">
        <a href="/guide" className="underline hover:text-slate-600">
          신통방통 전체 서비스 가이드 보기
        </a>
      </footer>
    </div>
  );
}
