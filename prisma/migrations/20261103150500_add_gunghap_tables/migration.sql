-- [긴급 검수 지시 — 신통방통 궁합지도] gunghap_invite / gunghap_pair_result /
-- gunghap_unlock_record / gunghap_share_event 4개 테이블 신규 생성.
--
-- [범위 주의] 이 파일은 `prisma migrate diff`가 산출한 전체 diff 중
-- 궁합지도(Gunghap) 관련 CREATE TABLE/CREATE INDEX 문만 선별해 수록한다.
-- 전체 diff에는 이번 작업과 무관한 기존 drift(users.google_id/kakao_id
-- 컬럼, guinji_map/pass_category_usages/wishes 등 RedefineTables)가 섞여
-- 있었는데, 운영 DB에는 이미 해당 변경이 반영되어 있음을 직접 확인했다
-- (ssh sqlite3 PRAGMA table_info(users) 조회로 google_id/kakao_id 기존
-- 존재 확인) — 그 부분까지 포함하면 "검증되지 않은 변경을 궁합지도
-- 배포에 끼워 넣는" 위험이 있어 의도적으로 제외한다.

-- CreateTable
CREATE TABLE "gunghap_invite" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "owner_id" INTEGER NOT NULL,
    "token" TEXT NOT NULL,
    "owner_name" TEXT,
    "owner_saju_parsed" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "token_issued_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revoked_at" DATETIME,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "gunghap_invite_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "gunghap_pair_result" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "invite_id" INTEGER NOT NULL,
    "joined_user_id" INTEGER,
    "guest_name" TEXT NOT NULL,
    "guest_gender" TEXT NOT NULL,
    "guest_solar_lunar" TEXT NOT NULL DEFAULT 'solar',
    "guest_birth_date" TEXT NOT NULL,
    "guest_birth_time" TEXT,
    "guest_birth_time_missing" BOOLEAN NOT NULL DEFAULT false,
    "guest_is_leap_month" BOOLEAN NOT NULL DEFAULT false,
    "guest_saju_parsed" TEXT NOT NULL,
    "fact_trace" TEXT NOT NULL,
    "category_results" TEXT NOT NULL,
    "engine_version" TEXT NOT NULL DEFAULT 'gunghap-1.0.0',
    "rule_version" TEXT NOT NULL DEFAULT 'gunghap-rules-1.0.0',
    "calculated_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "gunghap_pair_result_invite_id_fkey" FOREIGN KEY ("invite_id") REFERENCES "gunghap_invite" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "gunghap_pair_result_joined_user_id_fkey" FOREIGN KEY ("joined_user_id") REFERENCES "users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "gunghap_unlock_record" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "result_id" INTEGER NOT NULL,
    "amount" INTEGER NOT NULL DEFAULT 100,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "gunghap_unlock_record_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "gunghap_unlock_record_result_id_fkey" FOREIGN KEY ("result_id") REFERENCES "gunghap_pair_result" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "gunghap_share_event" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "invite_id" INTEGER NOT NULL,
    "token" TEXT NOT NULL,
    "from_user_id" INTEGER NOT NULL,
    "opened_at" DATETIME,
    "joined_at" DATETIME,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "gunghap_share_event_invite_id_fkey" FOREIGN KEY ("invite_id") REFERENCES "gunghap_invite" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "gunghap_share_event_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "gunghap_invite_token_key" ON "gunghap_invite"("token");

-- CreateIndex
CREATE INDEX "gunghap_invite_owner_id_created_at_idx" ON "gunghap_invite"("owner_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "gunghap_pair_result_invite_id_key" ON "gunghap_pair_result"("invite_id");

-- CreateIndex
CREATE INDEX "gunghap_unlock_record_user_id_created_at_idx" ON "gunghap_unlock_record"("user_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "gunghap_unlock_record_user_id_result_id_key" ON "gunghap_unlock_record"("user_id", "result_id");

-- CreateIndex
CREATE INDEX "gunghap_share_event_token_idx" ON "gunghap_share_event"("token");

-- CreateIndex
CREATE INDEX "gunghap_share_event_invite_id_created_at_idx" ON "gunghap_share_event"("invite_id", "created_at");
