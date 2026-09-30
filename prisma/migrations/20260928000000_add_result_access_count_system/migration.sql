-- [결과보기 통합 권한 시스템 v1.0, 2026-09-28] Phase 1
-- 기존 컬럼/테이블은 삭제하지 않고, 신규 필드/테이블만 추가한다.

-- PassPolicy: 횟수제 전환 신규 필드
ALTER TABLE "pass_policies" ADD COLUMN "grant_count" INTEGER;
ALTER TABLE "pass_policies" ADD COLUMN "daily_claim_limit" INTEGER DEFAULT 1;
ALTER TABLE "pass_policies" ADD COLUMN "validity_days" INTEGER;

-- UserPass: 잔여횟수/출처 신규 필드
ALTER TABLE "user_passes" ADD COLUMN "granted_count" INTEGER;
ALTER TABLE "user_passes" ADD COLUMN "remaining_count" INTEGER;
ALTER TABLE "user_passes" ADD COLUMN "grant_source" TEXT;
ALTER TABLE "user_passes" ADD COLUMN "grant_reason" TEXT;

-- UserPass: remaining_count 조회용 인덱스
CREATE INDEX "user_passes_user_id_remaining_count_idx" ON "user_passes"("user_id", "remaining_count");

-- CoupangPassClaimLog: 쿠팡 프리패스 하루 1회 획득 제한 원자적 방지 테이블
CREATE TABLE "coupang_pass_claim_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "policy_id" INTEGER NOT NULL,
    "claim_date_key" TEXT NOT NULL,
    "user_pass_id" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "coupang_pass_claim_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "coupang_pass_claim_logs_policy_id_fkey" FOREIGN KEY ("policy_id") REFERENCES "pass_policies" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "coupang_pass_claim_logs_user_id_policy_id_claim_date_key_key" ON "coupang_pass_claim_logs"("user_id", "policy_id", "claim_date_key");
CREATE INDEX "coupang_pass_claim_logs_user_id_claim_date_key_idx" ON "coupang_pass_claim_logs"("user_id", "claim_date_key");

-- ResultAccessTransaction: §8 공통 ResultAccessService 단일 거래 원장
CREATE TABLE "result_access_transactions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "transaction_id" TEXT NOT NULL,
    "content_type" TEXT NOT NULL,
    "content_id" TEXT,
    "category_key" TEXT,
    "payment_method" TEXT NOT NULL,
    "amount" INTEGER NOT NULL DEFAULT 0,
    "user_pass_id" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "refunded_at" DATETIME,
    "fortune_request_id" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "result_access_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "result_access_transactions_user_pass_id_fkey" FOREIGN KEY ("user_pass_id") REFERENCES "user_passes" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "result_access_transactions_fortune_request_id_fkey" FOREIGN KEY ("fortune_request_id") REFERENCES "fortune_requests" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "result_access_transactions_transaction_id_key" ON "result_access_transactions"("transaction_id");
CREATE UNIQUE INDEX "result_access_transactions_fortune_request_id_key" ON "result_access_transactions"("fortune_request_id");
CREATE INDEX "result_access_transactions_user_id_created_at_idx" ON "result_access_transactions"("user_id", "created_at");
CREATE INDEX "result_access_transactions_status_idx" ON "result_access_transactions"("status");
