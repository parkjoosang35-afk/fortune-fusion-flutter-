// 05_Admin_System_Design.md §3.11 "시스템 설정" — 1차 소단위: 전역 설정값 관리
// 04A O-1 system_settings 시딩 데이터.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

async function main() {
  const existing = await prisma.systemSetting.count();
  if (existing > 0) {
    console.log(`이미 시스템 설정 ${existing}건이 존재합니다. 시딩을 건너뜁니다.`);
    return;
  }

  const settingsData: { key: string; value: string; description: string }[] = [
    {
      key: "maintenance_mode",
      value: "false",
      description: "서비스 점검모드 on/off. true로 설정 시 앱 전체 점검 안내 화면 노출",
    },
    {
      key: "maintenance_message",
      value: JSON.stringify("서비스 안정화를 위한 점검이 진행 중입니다. 잠시 후 다시 이용해주세요."),
      description: "점검모드 활성 시 앱에 노출되는 안내 문구",
    },
    {
      key: "min_app_version_android",
      value: JSON.stringify("2.4.0"),
      description: "Android 최소 지원 앱버전(이하 버전은 강제 업데이트 유도)",
    },
    {
      key: "min_app_version_ios",
      value: JSON.stringify("2.4.0"),
      description: "iOS 최소 지원 앱버전(이하 버전은 강제 업데이트 유도)",
    },
    {
      key: "daily_free_fortune_limit",
      value: "3",
      description: "회원당 1일 무료 운세 조회 가능 횟수",
    },
    {
      key: "point_expiry_days",
      value: "365",
      description: "포인트 적립 후 만료까지 유효기간(일)",
    },
    {
      key: "community_post_report_threshold",
      value: "5",
      description: "게시글이 자동 숨김 처리되는 신고 누적 건수 기준",
    },
    {
      key: "customer_support_email",
      value: JSON.stringify("support@fortunefusion.app"),
      description: "고객지원 문의 접수 이메일 주소",
    },
    {
      key: "matching_daily_like_limit",
      value: "10",
      description: "회원당 1일 매칭 좋아요 발송 가능 횟수",
    },
    {
      key: "event_participation_notice",
      value: "true",
      description: "이벤트 참여 시 알림 발송 여부(전역 기본값)",
    },
  ];

  await prisma.systemSetting.createMany({
    data: settingsData.map((s) => ({ ...s, createdBy: "system", updatedBy: "system" })),
  });
  console.log(`시스템 설정(system_settings) ${settingsData.length}건 시딩 완료.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
