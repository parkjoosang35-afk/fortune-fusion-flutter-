import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

async function main() {
  const faqsData = [
    {
      category: "결제/구독",
      question: "구독 결제는 언제 갱신되나요?",
      answer: "구독 시작일을 기준으로 매월(월간) 또는 매년(연간) 동일한 날짜에 자동 갱신됩니다. 갱신 3일 전 앱 내 알림으로 안내드립니다.",
      sortOrder: 1,
    },
    {
      category: "결제/구독",
      question: "환불은 어떻게 요청하나요?",
      answer: "앱 내 [마이페이지 > 결제내역]에서 환불 요청이 가능합니다. 결제 후 7일 이내, 서비스 미사용 건에 한해 환불이 가능합니다.",
      sortOrder: 2,
    },
    {
      category: "계정",
      question: "비밀번호를 잊어버렸어요.",
      answer: "로그인 화면의 [비밀번호 찾기]를 통해 가입한 이메일로 재설정 링크를 받을 수 있습니다.",
      sortOrder: 1,
    },
    {
      category: "계정",
      question: "회원 탈퇴는 어떻게 하나요?",
      answer: "[마이페이지 > 설정 > 회원 탈퇴]에서 진행 가능합니다. 탈퇴 시 모든 데이터가 삭제되며 복구가 불가능합니다.",
      sortOrder: 2,
    },
    {
      category: "궁합/매칭",
      question: "궁합 분석 결과는 얼마나 정확한가요?",
      answer: "사주, 타로, MBTI 데이터를 종합한 AI 알고리즘으로 분석하며, 참고용 콘텐츠로 제공됩니다.",
      sortOrder: 1,
    },
    {
      category: "궁합/매칭",
      question: "매칭 상대를 차단하고 싶어요.",
      answer: "채팅방 또는 프로필 화면 우측 상단 메뉴에서 [차단하기]를 선택하면 즉시 차단됩니다.",
      sortOrder: 2,
    },
    {
      category: "포인트/리워드",
      question: "포인트는 어디에 사용할 수 있나요?",
      answer: "상점의 디지털 부적, 복주머니, 상품권 구매에 사용할 수 있습니다.",
      sortOrder: 1,
    },
    {
      category: "기타",
      question: "고객센터 운영시간이 어떻게 되나요?",
      answer: "평일 오전 10시~오후 6시(공휴일 제외)이며, 1:1 문의는 24시간 접수 가능합니다.",
      sortOrder: 1,
    },
  ];

  for (const f of faqsData) {
    await prisma.faq.create({ data: { ...f, createdBy: "system", updatedBy: "system" } });
  }
  console.log(`FAQs created: ${faqsData.length}건`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
