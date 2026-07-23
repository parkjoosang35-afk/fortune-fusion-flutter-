import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

async function main() {
  const noticesData = [
    {
      title: "[필독] 서비스 이용약관 개정 안내",
      content:
        "안녕하세요. Fortune Fusion입니다.\n2026년 2월 1일부터 개정된 서비스 이용약관이 적용됩니다. 주요 변경사항은 개인정보 처리방침 세부 조항 및 유료 서비스 환불 정책입니다. 자세한 내용은 앱 내 공지사항을 참고해 주세요.",
      isPinned: true,
    },
    {
      title: "설 연휴 고객센터 운영시간 안내",
      content:
        "설 연휴 기간(2월 8일~2월 10일) 동안 고객센터 운영시간이 단축됩니다. 오전 10시~오후 4시까지 운영하며, 긴급 문의는 앱 내 1:1 문의를 이용해 주세요.",
      isPinned: true,
    },
    {
      title: "신규 궁합 분석 기능 업데이트",
      content:
        "AI 기반 정밀 궁합 분석 기능이 새롭게 추가되었습니다. 사주/타로/MBTI를 결합한 종합 궁합 리포트를 확인해보세요!",
      isPinned: false,
    },
    {
      title: "앱 버전 2.4.0 업데이트 안내",
      content:
        "버그 수정 및 성능 개선이 포함된 업데이트입니다. 최신 버전으로 업데이트하시면 더욱 안정적인 서비스를 이용하실 수 있습니다.",
      isPinned: false,
    },
    {
      title: "개인정보 처리방침 변경 사전 안내",
      content:
        "개인정보 처리방침이 일부 변경될 예정입니다. 변경 사항은 시행일 7일 전에 별도 공지하겠습니다.",
      isPinned: false,
    },
    {
      title: "(종료) 신규가입 이벤트 결과 안내",
      content:
        "지난 신규가입 이벤트에 참여해주신 모든 분들께 감사드립니다. 당첨자는 개별 안내드렸습니다.",
      isPinned: false,
    },
  ];

  for (const n of noticesData) {
    await prisma.notice.create({ data: { ...n, createdBy: "system", updatedBy: "system" } });
  }
  console.log(`Notices created: ${noticesData.length}건`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
