// 6-7-4-B-4: 이용약관 공개 페이지
// (privacy-policy/page.tsx와 동일한 예외 승인 근거 — 신규 페이지 생성이나
// "최소 수정 원칙" 범위 내 개인정보처리방침 준수를 위한 필수 페이지)
//
// [2026-10-29 전면개정 — 개발자 전달용 개정판 반영] 사용자가 제공한
// `신통방통_이용약관_개인정보처리방침_개정판.md`의 "이용약관(개정판)" 섹션을
// 그대로 텍스트로 옮겼다. 주요 변경점: 만14세 가입 제한 신설(제4조③), 소셜
// 로그인(카카오/구글) 가입 경로 명시(제4조②), 신고·게시중단 절차 신설(제8조②,
// 정보통신망법 제44조의2 근거), 지적재산권·게시물 조항 신설(제9조), 금지행위
// 구체화(혐오표현·스팸·사기 추가, 제8조①). 시행일은 공지(2026-10-29)로부터
// 30일 경과한 날짜로 확정했다(제3조의 "이용자에게 불리한 변경 시 30일 전 공지"
// 원칙 적용 — 만14세 제한 신설이 이에 해당).
export const metadata = {
  title: "이용약관 | Fortune Fusion",
  description: "Fortune Fusion(신통방통) 서비스 이용약관",
};

const EFFECTIVE_DATE = "2026년 11월 28일";
const PREVIOUS_EFFECTIVE_DATE = "2026년 8월 18일";
const CONTACT_EMAIL = "searciandmake@gmail.com";
const OPERATOR_NAME = "서치앤메이크";
const REPRESENTATIVE_NAME = "이권호";

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
          시행일: {EFFECTIVE_DATE} · 운영주체: {OPERATOR_NAME} (대표: {REPRESENTATIVE_NAME})
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
            &ldquo;복주머니&rdquo;란 광고 시청, 출석, 커뮤니티 활동 등을 통해
            무료로 적립되는 서비스 전용 가상 자산(포인트)으로서, 현금으로
            구매하거나 환금할 수 없습니다.
          </li>
          <li>
            &ldquo;소셜 계정&rdquo;이란 카카오, 구글 등 외부 플랫폼의 계정을
            통해 서비스에 가입·로그인하기 위해 이용자가 연결하는 계정을
            말합니다.
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
          ① 이용자는 회사가 정한 가입 양식에 따라 이메일, 비밀번호, 닉네임 등
          필수 정보를 기재하고 이 약관, 개인정보처리방침 및 만 14세 이상
          확인에 동의함으로써 회원가입을 신청합니다.
        </p>
        <p>
          ② 이용자는 카카오, 구글 등 소셜 계정을 통하여 회원가입을 신청할 수
          있습니다. 이 경우 해당 플랫폼에서 제공하는 계정 식별자, 이메일,
          닉네임 등 프로필 정보가 회사로 제공되며, 소셜 계정 자체에 관한
          분쟁은 해당 플랫폼과 이용자 간의 문제이지만, 서비스 이용과 관련한
          권리·의무는 본 약관에 따릅니다.
        </p>
        <p>
          ③ 회원가입은 만 14세 이상인 자에 한하여 신청할 수 있습니다. 회사는
          만 14세 미만 아동의 가입 신청을 승낙하지 않으며, 가입 후 만 14세
          미만임이 확인된 경우 이용계약을 해지할 수 있습니다.
        </p>
        <p>
          ④ 회사는 다음 각 호에 해당하는 신청에 대해서는 승낙을 하지 않거나
          사후에 이용계약을 해지할 수 있습니다.
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
          매칭, AI 상담 서비스를 제공합니다. 서비스의 내용, 화면 구성 등은
          운영상·기술상의 필요에 따라 변경될 수 있으며, 이 경우 사전에
          공지합니다.
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

      <Article no={7} title="복주머니 및 무료 재화 정책">
        <ul className="ml-4 list-disc space-y-1">
          <li>
            현재 서비스 내 복주머니는 광고 시청, 출석체크, 커뮤니티 활동 등을
            통해서만 적립되는 무료 재화이며, 현금 등 유상 결제를 통한 구매(충전)
            기능은 제공하지 않습니다.
          </li>
          <li>
            복주머니는 현금으로 환금되지 않으며, 회원 탈퇴 시 잔여 복주머니는
            소멸됩니다.
          </li>
          <li>
            향후 유료 구독, 상품권 등 유상 결제 서비스가 추가되는 경우, 회사는
            사전에 이 약관 및 관련 정책을 개정하여 공지하고 「전자상거래 등에서의
            소비자보호에 관한 법률」 등 관련 법령에 따른 청약철회, 환불 절차를
            별도로 마련합니다.
          </li>
        </ul>
      </Article>

      <Article no={8} title="이용자의 의무 및 금지행위">
        <p>① 이용자는 다음 각 호의 행위를 하여서는 안 됩니다.</p>
        <ul className="ml-4 list-disc space-y-1">
          <li>타인의 개인정보를 도용하거나 허위 정보를 등록하는 행위</li>
          <li>
            커뮤니티(소원방), 매칭, 채팅 등에서 타인을 비방하거나 명예를
            훼손하는 행위, 음란물 게시, 혐오·차별적 표현, 불법정보 유통 행위
          </li>
          <li>스팸, 사기, 무단 상업적 광고성 게시물을 게시하는 행위</li>
          <li>서비스의 정상적인 운영을 방해하는 행위(자동화된 접근 등)</li>
          <li>회사의 지적재산권 또는 제3자의 권리를 침해하는 행위</li>
        </ul>
        <p>
          ② 이용자는 제1항에 해당하는 게시물을 발견할 경우 앱 내 신고 기능
          또는 문의 이메일을 통해 신고할 수 있으며, 회사는 「정보통신망
          이용촉진 및 정보보호 등에 관한 법률」 제44조의2에 따른 게시물 중단
          요청 절차를 운영합니다. 회사는 신고 접수 또는 위반 확인 시 해당
          게시물의 삭제, 게시자 이용제한 등 필요한 조치를 할 수 있습니다.
        </p>
      </Article>

      <Article no={9} title="지적재산권 및 게시물">
        <p>
          ① 서비스에서 회사가 제공하는 콘텐츠(디자인, 텍스트, 화면 구성 등)에
          대한 권리는 회사에 귀속됩니다.
        </p>
        <p>
          ② 이용자가 게시한 게시물(소원카드, 댓글, 채팅 등)의 저작권은 해당
          이용자에게 있으며, 이용자는 회사에 대하여 서비스의 운영·제공·전시
          및 서비스 홍보에 필요한 범위 내에서 해당 게시물을 무상으로 이용할
          수 있는 권리를 허락합니다.
        </p>
        <p>
          ③ 이용자는 타인의 게시물을 임의로 복제·전송하여 서비스 외부에
          게시할 수 없습니다.
        </p>
        <p>
          ④ 회원 탈퇴 시 게시물 및 개인정보의 처리는 개인정보처리방침이 정한
          바에 따릅니다.
        </p>
      </Article>

      <Article no={10} title="계약해지 및 이용제한 (회원탈퇴)">
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
          회사는 이용자가 제8조(이용자의 의무 및 금지행위)를 위반하거나
          서비스의 정상적인 운영을 방해한 경우, 사전 통지 후 이용계약을
          해지하거나 서비스 이용을 제한할 수 있습니다.
        </p>
      </Article>

      <Article no={11} title="면책조항">
        <p>
          회사는 천재지변, 불가항력적 사유로 서비스를 제공할 수 없는 경우
          책임이 면제됩니다. 회사는 이용자가 서비스를 통해 얻은 AI 운세/사주
          등 콘텐츠를 근거로 한 판단 및 그로 인해 발생한 손해에 대해 법령이
          허용하는 범위 내에서 책임을 지지 않습니다.
        </p>
      </Article>

      <Article no={12} title="분쟁해결 및 준거법">
        <p>
          이 약관과 관련하여 회사와 이용자 간에 발생한 분쟁에 대해서는
          대한민국 법령을 준거법으로 하며, 관할 법원은 민사소송법상의
          관할법원으로 합니다.
        </p>
      </Article>

      <Article no={13} title="문의처">
        <p>
          서비스 이용 및 약관에 관한 문의는 아래 이메일로 연락해 주시기
          바랍니다.
        </p>
        <ul className="ml-4 list-disc space-y-1">
          <li>운영주체: {OPERATOR_NAME} (대표: {REPRESENTATIVE_NAME})</li>
          <li>
            문의 이메일:{" "}
            <a href={`mailto:${CONTACT_EMAIL}`} className="text-indigo-600 underline">
              {CONTACT_EMAIL}
            </a>
          </li>
        </ul>
      </Article>

      <p className="mt-4 text-sm text-slate-500">
        부칙: 이 약관은 {EFFECTIVE_DATE}부터 시행하며, 기존 약관({PREVIOUS_EFFECTIVE_DATE} 시행)을 대체합니다.
      </p>

      <footer className="mt-12 border-t border-slate-200 pt-6 text-xs text-slate-400">
        <a href="/privacy-policy" className="underline hover:text-slate-600">
          개인정보처리방침 보기
        </a>
      </footer>
    </div>
  );
}
