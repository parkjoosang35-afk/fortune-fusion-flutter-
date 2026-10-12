-- [귀인지도 초대링크 재발급 v1.1] guinji_map에 초대 링크 상태 필드 3종 추가.
-- SQLite는 enum을 지원하지 않아 String으로 관리("active" | "revoked", 스키마 전체 컨벤션과 동일).
-- 기존 status(지도 자체 소프트삭제)와는 별개 개념이므로 컬럼명을 invite_status로 분리한다.
-- 참고: SQLite는 ALTER TABLE ADD COLUMN에서 non-constant DEFAULT(CURRENT_TIMESTAMP 등)를
-- 허용하지 않으므로, token_issued_at은 nullable로 추가한 뒤 아래 UPDATE로 백필한다.

-- [fresh DB 배포 결함 수정 2026-10-12] guinji_map 생성은 이 마이그레이션보다
-- 늦은 20261005161500_add_missing_legacy_tables에 들어 있어, 빈 DB에서
-- migrate deploy를 하면 여기서 "no such table: guinji_map"으로 실패했다.
-- 테이블이 없을 때만 초대 필드 이전의 기본 형태로 먼저 만든다. 기존 운영 DB는
-- 테이블이 이미 있어 이 문장이 아무 일도 하지 않으므로 동작이 바뀌지 않는다.
-- 뒤쪽 legacy 마이그레이션의 CREATE TABLE IF NOT EXISTS는 그대로 건너뛴다.
CREATE TABLE IF NOT EXISTS "guinji_map" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "owner_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "owner_saju_parsed" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "guinji_map_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS "guinji_map_token_key" ON "guinji_map"("token");
CREATE UNIQUE INDEX IF NOT EXISTS "guinji_map_owner_id_key" ON "guinji_map"("owner_id");

ALTER TABLE "guinji_map" ADD COLUMN "invite_status" TEXT NOT NULL DEFAULT 'active';
ALTER TABLE "guinji_map" ADD COLUMN "token_issued_at" DATETIME;
ALTER TABLE "guinji_map" ADD COLUMN "revoked_at" DATETIME;

-- 백필: 기존 row는 token이 최초 생성 시점(created_at)에 발급된 것으로 간주.
UPDATE "guinji_map" SET "token_issued_at" = "created_at" WHERE "token_issued_at" IS NULL;
