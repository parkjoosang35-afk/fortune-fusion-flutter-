-- [B안 정정 — 2026-10-13] 배포 스크립트가 `prisma migrate deploy` 체제라서
-- schema.prisma 블록만으로는 운영 서버에 반영되지 않는다(dev.db에만 db push
-- 적용된 상태였음). 사용자 승인에 따라 멱등 마이그레이션 SQL을 추가한다.
-- CREATE TABLE IF NOT EXISTS + CREATE INDEX IF NOT EXISTS만 사용하여 기존
-- 테이블을 건드리지 않는다. 컬럼/인덱스는 schema.prisma FunnelEvent 블록과
-- 1:1 일치(npx prisma migrate diff --from-empty --to-schema로 생성한 SQL에
-- IF NOT EXISTS만 추가).

-- CreateTable
CREATE TABLE IF NOT EXISTS "funnel_events" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "event_name" TEXT NOT NULL,
    "anonymous_id" TEXT NOT NULL,
    "map_token" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "funnel_events_event_name_created_at_idx" ON "funnel_events"("event_name", "created_at");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "funnel_events_map_token_idx" ON "funnel_events"("map_token");
