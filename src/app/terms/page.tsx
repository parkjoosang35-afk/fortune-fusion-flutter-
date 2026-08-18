// 6-7-4-B-4: 이용약관 공개 페이지
// (privacy-policy/page.tsx와 동일한 예외 승인 근거 — 신규 페이지 생성이나
// "최소 수정 원칙" 범위 내 개인정보처리방침 준수를 위한 필수 페이지)

export const metadata = {
  title: "이용약관 | Fortune Fusion",
  description: "Fortune Fusion(신통방통) 서비스 이용약관",
};

const EFFECTIVE_DATE = "2026년 8월 18일";
const CONTACT_EMAIL = "parkjoosang35@gmail.com";
const OPERATOR_NAME = "라이즈주식회사";

function Article({
  no,
  title,
  children,
}: {
  no: number;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mb-8">
      <h2 className="mb-3 text-lg font-bold text-slate-900">
        제{no}조 ({title})
      </h2>
      <div className="space-y-2 text-sm leading-relaxed text-slate-700">{children}</div>
    </section>
  );
}

export default function TermsPage() {
  return (
    <div className="mx-auto min-h-screen max-w-3xl px-6 py-12">
      <header className="mb-10 border-b border-slate-200 pb-6">
        <h1 className="text-2xl font-bold text-slate-900">이용약관</h1>
        <p className="mt-2 text-sm text-slate-500">
          시행일: {EFFECTIVE_DATE} · 운영주체: {OPERATOR_NAME}
        </p>
      </header>

      <Article no={1} title="목적">
        <p>
          이 약관은 {OPERATOR_NAME}(이하 &ldquo;회사&rdquo;)가 제공하는
          신통방통(Fortune Fusion) 애플리케이션 서비스(이하 &ldquo;서비스&rdquo;)의
          이용과 관련하여 회사와 이용자의 권리, 의무 및 책임사항, 기타 필요한
          사항을 규정함을 목적으로 합니다.
        </p>
      </Article>

      <Article no={2} title="정의">
        <ul className="ml-4 list-disc space-y-1">
          <li>
            &ldquo;서비스&rdquo;란 회사가 제공하는 사주, 운세, 타로, 얼굴관상,
            손금, 궁합, AI 운세 상담, 커뮤니티(소원방), 매칭 등 일체의 서비스를
            의미합니다.
          </li>
          <li>
            &ldquo;이용자&rdquo;란 이 약관에 따라 회사가 제공하는 서비스를
            이용하는 회원을 말합니다.
          </li>
          <li>
            &ldquo;복주머니&rdquo;란 서비스 내에서 유료 콘텐츠 이용 등에
            사용되는 재화(포인트)로서, 현금으로 환금되지 않는 서비스 전용
            가상 자산입니다.
          </li>
          <li>
            &ldquo;유료서비스&rdquo;란 회사가 유상으로 제공하는 구독, 상품권,
            부적 등 일체의 콘텐츠 및 재화를 의미합니다.
          </li>
        </ul>
      </Article>

      <Article no={3} title="약관의 효력 및 변경">
        <p>
          이 약관은 서비스 화면에 게시하거나 기타의 방법으로 이용자에게
          공지함으로써 효력이 발생합니다. 회사는 관련 법령을 위배하지 않는
          범위에서 이 약관을 개정할 수 있으며, 개정 시 적용일자 및 개정사유를
          명시하여 최소 7일 전(이용자에게 불리한 변경의 경우 30일 전)부터
          공지합니다.
        </p>
      </Article>

      <Article no={4} title="회원가입">
        <p>
          이용자는 회사가 정한 가입 양식에 따라 이메일, 비밀번호, 닉네임 등
          필수 정보를 기재하고 이 약관 및 개인정보처리방침에 동의함으로써
          회원가입을 신청합니다. 회사는 다음 각 호에 해당하는 신청에 대해서는
          승낙을 하지 않거나 사후에 이용계약을 해지할 수 있습니다.
        </p>
        <ul className="ml-4 list-disc space-y-1">
          <li>타인의 명의를 이용하거나 허위 정보를 기재한 경우</li>
          <li>이미 가입된 이메일 또는 닉네임으로 재가입을 시도하는 경우</li>
          <li>기타 회사가 정한 이용신청 요건을 충족하지 못한 경우</li>
        </ul>
      </Article>

      <Article no={5} title="서비스의 제공 및 변경">
        <p>
          회사는 사주/운세/타로/얼굴관상/손금 등 AI 기반 콘텐츠, 커뮤니티,
          매칭, AI 상담, 유료 구독 및 재화 판매 서비스를 제공합니다. 서비스의
          내용, 화면 구성 등은 운영상·기술상의 필요에 따라 변경될 수 있으며,
          이 경우 사전에 공지합니다.
        </p>
        <p>
          AI가 생성하는 사주/운세/관상/궁합 등의 결과는 오락 및 참고 목적으로
          제공되는 것이며, 의학적·법률적·재정적 조언을 대체하지 않습니다.
        </p>
      </Article>

      <Article no={6} title="서비스 이용시간 및 중단">
        <p>
          서비스는 연중무휴, 1일 24시간 제공을 원칙으로 합니다. 다만 시스템
          점검, 서버 장애, 국가비상사태 등 불가피한 사유가 있는 경우 서비스
          제공이 일시 중단될 수 있으며, 이 경우 사전에 공지합니다(사전 공지가
          불가능한 부득이한 사정이 있는 경우 사후에 공지할 수 있습니다).
        </p>
      </Article>

      <Article no={7} title="유료서비스 및 결제">
        <ul className="ml-4 list-disc space-y-1">
          <li>
            이용자는 구독, 상품권, 부적 등 유료서비스를 이용하기 위해 회사가
            정한 결제수단으로 대금을 결제할 수 있습니다.
          </li>
          <li>
            결제는 결제대행사(PG)를 통해 처리되며, 회사는 카드번호 등 결제수단
            원본정보를 직접 보관하지 않습니다.
          </li>
          <li>
            유료서비스의 청약철회, 환불 등은 「전자상거래 등에서의
            소비자보호에 관한 법률」 등 관련 법령에 따르며, 이미 사용되었거나
            제공이 개시된 콘텐츠(예: 이미 확인한 AI 운세 결과, 사용된 복주머니
            등)에 대해서는 관련 법령이 정한 예외 사유에 따라 환불이 제한될 수
            있습니다.
          </li>
          <li>
            복주머니는 현금으로 환금되지 않으며, 회원 탈퇴 시 잔여 복주머니는
            소멸됩니다.
          </li>
        </ul>
      </Article>

      <Article no={8} title="이용자의 의무">
        <p>이용자는 다음 각 호의 행위를 하여서는 안 됩니다.</p>
        <ul className="ml-4 list-disc space-y-1">
          <li>타인의 개인정보를 도용하거나 허위 정보를 등록하는 행위</li>
          <li>
            커뮤니티(소원방), 매칭, 채팅 등에서 타인을 비방하거나 명예를
            훼손하는 행위, 음란물 게시, 불법정보 유통 행위
          </li>
          <li>서비스의 정상적인 운영을 방해하는 행위(자동화된 접근 등)</li>
          <li>회사의 지적재산권, 제3자의 권리를 침해하는 행위</li>
        </ul>
      </Article>

      <Article no={9} title="계약해지 및 이용제한 (회원탈퇴)">
        <p>
          이용자는 앱 내 &ldquo;마이페이지 &gt; 설정 &gt; 회원탈퇴&rdquo; 메뉴
          또는{" "}
          <a href="/account-deletion" className="text-indigo-600 underline">
            외부 계정삭제 페이지
          </a>
          를 통해 언제든지 이용계약을 해지(회원탈퇴)할 수 있습니다. 탈퇴 시
          개인정보 처리에 관한 사항은 개인정보처리방침이 정한 바에 따릅니다.
        </p>
        <p>
          회사는 이용자가 제8조(이용자의 의무)를 위반하거나 서비스의 정상적인
          운영을 방해한 경우, 사전 통지 후 이용계약을 해지하거나 서비스 이용을
          제한할 수 있습니다.
        </p>
      </Article>

      <Article no={10} title="면책조항">
        <p>
          회사는 천재지변, 불가항력적 사유로 서비스를 제공할 수 없는 경우
          책임이 면제됩니다. 회사는 이용자가 서비스를 통해 얻은 AI 운세/사주
          등 콘텐츠를 근거로 한 판단 및 그로 인해 발생한 손해에 대해 법령이
          허용하는 범위 내에서 책임을 지지 않습니다.
        </p>
      </Article>

      <Article no={11} title="분쟁해결 및 준거법">
        <p>
          이 약관과 관련하여 회사와 이용자 간에 발생한 분쟁에 대해서는
          대한민국 법령을 준거법으로 하며, 관할 법원은 민사소송법상의
          관할법원으로 합니다.
        </p>
      </Article>

      <Article no={12} title="문의처">
        <p>
          서비스 이용 및 약관에 관한 문의는 아래 이메일로 연락해 주시기
          바랍니다.
        </p>
        <ul className="ml-4 list-disc space-y-1">
          <li>운영주체: {OPERATOR_NAME}</li>
          <li>
            문의 이메일:{" "}
            <a href={`mailto:${CONTACT_EMAIL}`} className="text-indigo-600 underline">
              {CONTACT_EMAIL}
            </a>
          </li>
        </ul>
      </Article>

      <p className="mt-4 text-sm text-slate-500">
        부칙: 이 약관은 {EFFECTIVE_DATE}부터 시행합니다.
      </p>

      <footer className="mt-12 border-t border-slate-200 pt-6 text-xs text-slate-400">
        <a href="/privacy-policy" className="underline hover:text-slate-600">
          개인정보처리방침 보기
        </a>
      </footer>
    </div>
  );
}
