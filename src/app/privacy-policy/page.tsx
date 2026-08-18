// 6-7-4-B-4: 개인정보처리방침 공개 페이지
//
// [예외 승인 근거] "신규기능개발 금지" 원칙의 명시적 예외 — 사용자가 Google Play
// 정책 준수를 위해 직접 요청한 "공개적으로 접근 가능한 활성 URL" 형태의 개인정보
// 처리방침이다. 인증/로그인 없이 접근 가능해야 하므로 (admin) 그룹 밖에 위치한다.
//
// [내용 근거] 6-7-4-B-3에서 admin_web 백엔드를 read-only로 조사해 확정한 사실관계
// (손금/관상 사진 미저장, 회원탈퇴 파기 미구현이었던 부분은 6-7-4-B-4에서 구현 완료,
// 로그인 로그 실작동, 쿠팡파트너스 실사용, 소셜로그인/PG결제는 501/시뮬레이션 상태 등)
// 만을 반영했으며, 실제로 수집·처리하지 않는 항목은 기재하지 않았다.
//
// [사업자 정보] 사용자 확정: 운영주체 "라이즈주식회사", 문의 이메일
// "parkjoosang35@gmail.com". 전화번호는 사용자가 "임의로 만들지 않는다"고 명시해
// 기재하지 않는다.

export const metadata = {
  title: "개인정보처리방침 | Fortune Fusion",
  description: "Fortune Fusion(신통방통) 개인정보처리방침",
};

const EFFECTIVE_DATE = "2026년 8월 18일";
const CONTACT_EMAIL = "parkjoosang35@gmail.com";
const OPERATOR_NAME = "라이즈주식회사";

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
      <div className="space-y-2 text-sm leading-relaxed text-slate-700">{children}</div>
    </section>
  );
}

export default function PrivacyPolicyPage() {
  return (
    <div className="mx-auto min-h-screen max-w-3xl px-6 py-12">
      <header className="mb-10 border-b border-slate-200 pb-6">
        <h1 className="text-2xl font-bold text-slate-900">개인정보처리방침</h1>
        <p className="mt-2 text-sm text-slate-500">
          시행일: {EFFECTIVE_DATE} · 운영주체: {OPERATOR_NAME}
        </p>
      </header>

      <p className="mb-8 text-sm leading-relaxed text-slate-700">
        {OPERATOR_NAME}(이하 &ldquo;회사&rdquo;)이 운영하는 신통방통(Fortune
        Fusion, 이하 &ldquo;서비스&rdquo;)은 「개인정보 보호법」 등 관련 법령을
        준수하며, 이용자의 개인정보를 안전하게 처리하기 위하여 다음과 같이
        개인정보처리방침을 수립·공개합니다.
      </p>

      <Section title="1. 수집하는 개인정보 항목 및 수집 방법">
        <p className="font-semibold text-slate-900">가. 회원가입 시 수집 항목</p>
        <ul className="ml-4 list-disc space-y-1">
          <li>필수: 이메일 주소, 비밀번호(암호화 저장), 닉네임</li>
        </ul>
        <p className="mt-3 font-semibold text-slate-900">
          나. 서비스 이용 과정에서 수집되는 항목
        </p>
        <ul className="ml-4 list-disc space-y-1">
          <li>
            사주/운세 프로필: 생년월일, 출생시간(모름 선택 가능), 음력/양력·윤달
            여부, 출생지역, 성별, MBTI, 자기소개(선택 입력)
          </li>
          <li>
            얼굴/손금 관상 서비스: 이용자가 업로드한 사진은 AI 분석 요청 시에만
            일시적으로 처리되며, 회사 서버(데이터베이스)에 저장하지 않습니다.
          </li>
          <li>
            결제 정보: 주문내역, 결제금액, 결제수단(PG사), 결제 승인번호 —
            카드번호 등 결제수단 원본 정보는 PG사(결제대행사)가 처리하며 회사는
            보관하지 않습니다.
          </li>
          <li>
            커뮤니티/매칭/상담 이용기록: 게시글, 댓글, 소원카드 내용, 매칭
            프로필, 채팅 메시지, AI 상담 대화 내용
          </li>
          <li>기기정보 및 접속 로그: 접속 IP, 접속일시, 로그인 성공/실패 기록</li>
          <li>푸시 알림 수신을 위한 기기 토큰(FCM 토큰)</li>
        </ul>
        <p className="mt-3 font-semibold text-slate-900">다. 수집 방법</p>
        <ul className="ml-4 list-disc space-y-1">
          <li>회원가입, 서비스 이용 과정에서 이용자가 직접 입력</li>
          <li>서비스 이용 과정에서 자동으로 생성·수집(접속 로그 등)</li>
        </ul>
      </Section>

      <Section title="2. 개인정보의 수집 및 이용 목적">
        <ul className="ml-4 list-disc space-y-1">
          <li>회원 가입 의사 확인, 회원제 서비스 제공에 따른 본인 식별·인증</li>
          <li>사주/운세/궁합/얼굴관상/손금 등 개인화된 콘텐츠 생성 및 제공</li>
          <li>유료 상품(구독, 상품권, 부적 등) 결제 및 정산</li>
          <li>커뮤니티(소원방), 매칭, 채팅, AI 상담 등 부가 서비스 제공</li>
          <li>공지사항 전달, 이벤트 및 광고성 정보 제공(수신 동의자에 한함)</li>
          <li>서비스 부정이용 방지, 접속 기록 보관 등 서비스 운영 및 개선</li>
        </ul>
      </Section>

      <Section title="3. 개인정보의 보유 및 이용 기간">
        <p>
          회사는 원칙적으로 개인정보 수집 및 이용목적이 달성된 후에는 해당
          정보를 지체 없이 파기합니다. 다만 아래의 정보에 대해서는 명시한
          사유에 따라 보존 기간 동안 보관 후 파기합니다.
        </p>
        <ul className="ml-4 list-disc space-y-1">
          <li>
            <span className="font-semibold">회원 탈퇴 시:</span> 탈퇴 신청일로부터
            30일간 유예기간을 두며, 유예기간 경과 후 이메일, 전화번호, 닉네임 등
            개인식별정보를 복구 불가능한 방식으로 비식별화하고, 사주 프로필·AI
            운세 이용기록·상담 내역 등 민감한 이용기록은 완전 삭제합니다.
          </li>
          <li>
            <span className="font-semibold">
              결제 관련 기록(계약 또는 청약철회 등에 관한 기록, 대금결제 및
              재화 공급에 관한 기록):
            </span>{" "}
            5년 (전자상거래 등에서의 소비자보호에 관한 법률)
          </li>
          <li>
            <span className="font-semibold">소비자 불만 또는 분쟁처리에 관한 기록:</span>{" "}
            3년 (전자상거래 등에서의 소비자보호에 관한 법률)
          </li>
          <li>
            <span className="font-semibold">로그인 기록:</span> 관련 법령에 따른
            보존기간 동안 보관 후 파기 (통신비밀보호법)
          </li>
        </ul>
      </Section>

      <Section title="4. 개인정보의 제3자 제공">
        <p>
          회사는 이용자의 개인정보를 &ldquo;2. 개인정보의 수집 및 이용
          목적&rdquo;에서 명시한 범위 내에서만 처리하며, 이용자의 사전 동의
          없이는 동 범위를 초과하여 처리하거나 제3자에게 제공하지 않습니다.
        </p>
      </Section>

      <Section title="5. 개인정보 처리업무의 위탁">
        <p>
          회사는 원활한 서비스 제공을 위하여 아래와 같이 개인정보 처리업무를
          외부에 위탁하고 있습니다.
        </p>
        <ul className="ml-4 list-disc space-y-1">
          <li>
            <span className="font-semibold">AI 콘텐츠 생성:</span> 이용자가
            입력한 생년월일 등 정보 및 업로드한 사진을 AI(인공지능) 모델
            제공업체에 실시간으로 전송하여 사주/얼굴관상/손금 등 분석 결과를
            생성합니다. 전송된 사진 및 입력정보는 분석 응답 생성 목적으로만
            일시적으로 처리되며 회사 서버에 별도 저장되지 않습니다.
          </li>
          <li>
            <span className="font-semibold">결제 처리(PG):</span> 유료 상품 결제
            시 결제대행사(PG사)를 통해 결제가 처리됩니다.
          </li>
          <li>
            <span className="font-semibold">제휴 마케팅(쿠팡파트너스):</span>{" "}
            서비스 내 일부 화면에서 쿠팡파트너스 제휴 링크/배너를 통해 외부
            쇼핑몰로 연결될 수 있으며, 이 경우 해당 서비스(쿠팡)의 개인정보
            처리방침이 별도로 적용됩니다.
          </li>
        </ul>
      </Section>

      <Section title="6. 이용자 및 법정대리인의 권리와 그 행사방법">
        <p>
          이용자는 언제든지 등록되어 있는 자신의 개인정보를 조회하거나 수정할
          수 있으며, 회원탈퇴를 통해 개인정보의 수집 및 이용에 대한 동의를
          철회할 수 있습니다. 개인정보 열람, 정정, 삭제, 처리정지 요구는 앱 내
          &ldquo;마이페이지 &gt; 설정&rdquo;에서 직접 처리하거나, 아래
          문의처를 통해 요청할 수 있습니다. 계정을 삭제(회원탈퇴)하는 경우
          서비스 앱 내부뿐 아니라 웹을 통해서도 요청할 수 있도록{" "}
          <a href="/account-deletion" className="text-indigo-600 underline">
            외부 계정삭제 페이지
          </a>
          를 제공합니다.
        </p>
      </Section>

      <Section title="7. 개인정보의 파기 절차 및 방법">
        <ul className="ml-4 list-disc space-y-1">
          <li>
            <span className="font-semibold">파기 절차:</span> 이용자가 회원가입
            등을 위해 입력한 정보는 목적이 달성된 후 별도의 보관 기간(위 3항
            참조)이 경과하면 파기됩니다.
          </li>
          <li>
            <span className="font-semibold">파기 방법:</span> 전자적 파일 형태의
            정보는 기록을 복구할 수 없는 방법으로 영구 삭제하거나, 개인을
            식별할 수 없는 형태로 비식별화(익명화) 처리합니다.
          </li>
        </ul>
      </Section>

      <Section title="8. 개인정보의 안전성 확보 조치">
        <ul className="ml-4 list-disc space-y-1">
          <li>비밀번호의 암호화 저장 및 일방향 암호화(해시) 처리</li>
          <li>개인정보에 대한 접근 권한 관리(관리자 계정 역할 기반 접근 제어)</li>
          <li>결제수단 원본정보(카드번호 등) 비저장 원칙(PG사 위탁 처리)</li>
        </ul>
      </Section>

      <Section title="9. 개인정보 보호책임자 및 문의처">
        <p>
          회사는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와
          관련한 이용자의 불만처리 및 피해구제 등을 위하여 아래와 같이 문의처를
          운영하고 있습니다.
        </p>
        <ul className="ml-4 list-disc space-y-1">
          <li>운영주체: {OPERATOR_NAME}</li>
          <li>
            개인정보 관련 문의 이메일:{" "}
            <a href={`mailto:${CONTACT_EMAIL}`} className="text-indigo-600 underline">
              {CONTACT_EMAIL}
            </a>
          </li>
        </ul>
        <p className="mt-2">
          기타 개인정보침해에 대한 신고나 상담이 필요하신 경우에는 아래
          기관에 문의하실 수 있습니다.
        </p>
        <ul className="ml-4 list-disc space-y-1">
          <li>개인정보분쟁조정위원회 (privacy.kollo.or.kr / 국번없이 1833-6972)</li>
          <li>개인정보침해신고센터 (privacy.kisa.or.kr / 국번없이 118)</li>
        </ul>
      </Section>

      <Section title="10. 개인정보처리방침의 변경">
        <p>
          이 개인정보처리방침은 {EFFECTIVE_DATE}부터 적용되며, 법령·정책 또는
          보안기술의 변경에 따라 내용의 추가·삭제 및 수정이 있을 시에는 시행
          최소 7일 전부터 앱 내 공지사항 및 본 페이지를 통하여 고지할 것입니다.
        </p>
      </Section>

      <footer className="mt-12 border-t border-slate-200 pt-6 text-xs text-slate-400">
        <a href="/terms" className="underline hover:text-slate-600">
          이용약관 보기
        </a>
      </footer>
    </div>
  );
}
