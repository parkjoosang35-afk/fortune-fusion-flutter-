// 05_Admin_System_Design.md §3.11 "시스템 설정" — 2차 소단위: 접근/에러 로그 조회
// 04A O-3 access_logs + O-4 error_logs 시딩 데이터.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

const API_PATHS = [
  { path: "/api/fortune/tarot", method: "POST" },
  { path: "/api/fortune/saju", method: "POST" },
  { path: "/api/users/me", method: "GET" },
  { path: "/api/matching/profiles", method: "GET" },
  { path: "/api/matching/likes", method: "POST" },
  { path: "/api/community/posts", method: "GET" },
  { path: "/api/community/posts", method: "POST" },
  { path: "/api/payments/checkout", method: "POST" },
  { path: "/api/shop/amulets", method: "GET" },
  { path: "/api/notifications/preferences", method: "GET" },
];

const STATUS_WEIGHTED = [200, 200, 200, 200, 200, 200, 201, 400, 401, 404, 429, 500, 503];

// 04A O-4 명시 화이트리스트
const SOURCES = ["api", "batch", "ai"] as const;
const SEVERITIES = ["info", "warning", "critical"] as const;

const ERROR_SAMPLES: { source: string; errorCode: string; message: string; severity: string }[] = [
  {
    source: "api",
    errorCode: "AUTH_TOKEN_EXPIRED",
    message: "JWT 토큰이 만료되어 요청이 거부되었습니다.",
    severity: "warning",
  },
  {
    source: "api",
    errorCode: "VALIDATION_FAILED",
    message: "요청 파라미터 유효성 검증 실패: birth_date 형식 오류",
    severity: "info",
  },
  {
    source: "api",
    errorCode: "DB_CONNECTION_TIMEOUT",
    message: "데이터베이스 연결 타임아웃이 발생했습니다(5000ms 초과).",
    severity: "critical",
  },
  {
    source: "batch",
    errorCode: "POINT_EXPIRY_BATCH_FAILED",
    message: "포인트 만료 배치 작업 중 일부 레코드 처리 실패(재시도 필요).",
    severity: "critical",
  },
  {
    source: "batch",
    errorCode: "STATISTICS_SNAPSHOT_DELAY",
    message: "통계 스냅샷 배치가 예정 시각보다 12분 지연되어 완료되었습니다.",
    severity: "warning",
  },
  {
    source: "ai",
    errorCode: "AI_PROVIDER_TIMEOUT",
    message: "AI 운세 생성 요청이 외부 프로바이더 응답 지연으로 타임아웃되었습니다.",
    severity: "critical",
  },
  {
    source: "ai",
    errorCode: "AI_CONTENT_FILTER_BLOCKED",
    message: "AI 응답이 콘텐츠 필터에 의해 차단되어 재생성이 필요합니다.",
    severity: "warning",
  },
  {
    source: "api",
    errorCode: "PAYMENT_GATEWAY_ERROR",
    message: "결제 게이트웨이 응답 코드 오류로 결제가 실패했습니다.",
    severity: "critical",
  },
  {
    source: "api",
    errorCode: "RATE_LIMIT_EXCEEDED",
    message: "동일 IP에서 짧은 시간 내 과다 요청이 감지되어 제한되었습니다.",
    severity: "info",
  },
  {
    source: "batch",
    errorCode: "GIFTCARD_EXPIRY_CHECK_WARNING",
    message: "상품권 만료 예정 알림 발송 대상 중 일부 회원의 푸시토큰이 유효하지 않습니다.",
    severity: "warning",
  },
];

function randomIp(idx: number): string {
  return `203.${(idx * 7) % 255}.${(idx * 13) % 255}.${(idx * 3) % 255}`;
}

async function main() {
  const existingAccess = await prisma.accessLog.count();
  const existingError = await prisma.errorLog.count();
  if (existingAccess > 0 && existingError > 0) {
    console.log(
      `이미 접근로그 ${existingAccess}건 / 에러로그 ${existingError}건이 존재합니다. 시딩을 건너뜁니다.`
    );
    return;
  }

  const users = await prisma.user.findMany({ select: { id: true }, take: 30 });
  if (users.length === 0) {
    throw new Error("시딩할 User가 없습니다. users 테이블을 먼저 채워주세요.");
  }

  // ── access_logs: 40건 생성(다양한 path/method/status/latency) ──
  const now = Date.now();
  const accessData = Array.from({ length: 40 }, (_, idx) => {
    const api = API_PATHS[idx % API_PATHS.length];
    const status = STATUS_WEIGHTED[idx % STATUS_WEIGHTED.length];
    const user = users[idx % users.length];
    return {
      userId: idx % 5 === 0 ? null : user.id, // 일부는 비로그인 요청(user_id NULL 허용)
      ipAddress: randomIp(idx),
      path: api.path,
      method: api.method,
      responseStatus: status,
      latencyMs: 30 + ((idx * 17) % 470),
      createdAt: new Date(now - idx * 1000 * 60 * 7), // 7분 간격으로 과거 시각 분산
    };
  });
  await prisma.accessLog.createMany({ data: accessData });
  console.log(`접근 로그(access_logs) ${accessData.length}건 시딩 완료.`);

  // ── error_logs: 샘플 10종을 반복하여 25건 생성(시간 분산) ──
  const errorData = Array.from({ length: 25 }, (_, idx) => {
    const sample = ERROR_SAMPLES[idx % ERROR_SAMPLES.length];
    return {
      source: sample.source,
      errorCode: sample.errorCode,
      message: sample.message,
      stackTraceRef: `s3://ff-logs/error/${sample.errorCode.toLowerCase()}/${idx}.log`,
      severity: sample.severity,
      createdAt: new Date(now - idx * 1000 * 60 * 23), // 23분 간격으로 분산
    };
  });
  await prisma.errorLog.createMany({ data: errorData });
  console.log(`에러 로그(error_logs) ${errorData.length}건 시딩 완료.`);

  // 화이트리스트 상수 사용 확인(타입 안전성 검증용, 실제 로직에서 재사용)
  console.log(`(참고) source 화이트리스트: ${SOURCES.join(", ")}`);
  console.log(`(참고) severity 화이트리스트: ${SEVERITIES.join(", ")}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
