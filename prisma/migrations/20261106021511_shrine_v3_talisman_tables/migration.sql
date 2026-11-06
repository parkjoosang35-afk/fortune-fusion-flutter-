-- [신당(THE SHRINE) v3 전면 재구축 — 2026-11-06] 67종 부적 카탈로그 +
-- 주문/부적함/향 올리기 API(커밋 d38aca9)에서 schema.prisma만 변경되고
-- 마이그레이션 파일이 누락되어 있던 것(local dev.db에 prisma db push로만
-- 반영됨)을 배포 전 점검 과정에서 발견, 수동으로 생성함.
--
-- [범위 제한 — 중요] 이 마이그레이션은 d38aca9 커밋의 ADD-only 변경사항만
-- 담는다 (talisman_items / shrine_orders / shrine_incense_logs 3개 신규
-- 테이블 생성). `prisma migrate dev`의 자동 diff 생성을 사용하지 않은 이유:
-- 자동 diff(`prisma migrate diff --from-migrations --to-schema`)는 이 변경과
-- 무관한 과거 drift를 함께 포함시켜 위험한 스크립트를 생성했다. 구체적으로:
--   1) `ALTER TABLE users ADD COLUMN google_id/kakao_id` — 운영 DB
--      PRAGMA table_info(users) 직접 확인 결과 이미 존재하는 컬럼이다
--      (2026-11-03 궁합지도 마이그레이션 작성 시점에도 동일하게 발견/배제된
--      바 있는 기존 drift). 포함 시 "duplicate column name" 에러로 배포
--      자체가 실패한다.
--   2) `wishes`/`pass_category_usages` 테이블 재작성(PRAGMA 기반 RedefineTable)
--      — 운영 DB PRAGMA table_info(wishes) 직접 확인 결과 wish_state/
--      sealed_at/unlock_at/fulfilled_at/opened_box_at/seal_item_code/
--      candle_item_code/talisman_item_code 8개 컬럼이 이미 모두 존재한다
--      (2026-08-25 커밋 c56af947에서 prisma db push로 반영, 운영 wishes
--      40건 중 wish_state 등 값 보유 40건 확인). diff가 생성한 INSERT...SELECT
--      문의 컬럼 목록이 이 8개 컬럼을 누락하고 있어, 그대로 적용하면 운영
--      데이터에서 이 컬럼들을 통째로 DROP·데이터 유실시키는 치명적 결함이
--      있었다 — 적용하지 않는다.
--   3) `DROP TABLE shrine_issue_ledgers`(구버전 U12 원장, 운영 30행 보유) —
--      신규 ShrineOrder 체계로 대체되어 schema.prisma에서는 이미 제거되었으나,
--      이 30행은 실사용자 발급 이력(테스트 데이터 아님)이므로 즉시 삭제하지
--      않는다. 2026-11-06 /home/user/backups/shrine_issue_ledgers_backup_
--      20261106.csv로 전체 백업 완료. 테이블 자체는 이번 마이그레이션에서는
--      보존하고(DROP 미실행), 운영 안정화 확인 후 별도 승인을 받아 후속
--      마이그레이션으로 정리한다(OPERATIONS_POLICY §10 — 공식 런칭 전
--      일괄 정리 원칙 준용).
--
-- 아래 CREATE TABLE/INDEX DDL은 로컬 dev.db에 실제 적용되어 있는 구조를
-- sqlite3 PRAGMA table_info / sqlite_master로 직접 확인 후 그대로 캡처했다
-- (schema.prisma의 TalismanItem/ShrineOrder/ShrineIncenseLog 모델과 1:1 일치,
-- FK 참조 대상인 users/result_access_transactions 테이블은 기존에 이미 존재).

-- CreateTable
CREATE TABLE "talisman_items" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "slug" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "hanja" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "aim" TEXT NOT NULL,
    "sub" TEXT,
    "meaning" TEXT NOT NULL,
    "effects" JSONB NOT NULL,
    "recommend_for" JSONB NOT NULL,
    "validity_term" TEXT NOT NULL,
    "usage" JSONB NOT NULL,
    "goes_with" JSONB NOT NULL,
    "image_path" TEXT NOT NULL,
    "thumb_path" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "shrine_orders" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "talisman_item_id" INTEGER NOT NULL,
    "serial" TEXT NOT NULL,
    "owner_name" TEXT NOT NULL,
    "saju_pillars" TEXT NOT NULL,
    "wish" TEXT NOT NULL,
    "result_access_transaction_id" INTEGER,
    "issued_date_key" TEXT NOT NULL,
    "expires_date_key" TEXT NOT NULL,
    "days_remaining" INTEGER NOT NULL DEFAULT 49,
    "last_incense_date_key" TEXT,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "shrine_orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "shrine_orders_talisman_item_id_fkey" FOREIGN KEY ("talisman_item_id") REFERENCES "talisman_items" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "shrine_orders_result_access_transaction_id_fkey" FOREIGN KEY ("result_access_transaction_id") REFERENCES "result_access_transactions" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "shrine_incense_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "shrine_order_id" INTEGER NOT NULL,
    "date_key" TEXT NOT NULL,
    "days_before" INTEGER NOT NULL,
    "days_after" INTEGER NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "shrine_incense_logs_shrine_order_id_fkey" FOREIGN KEY ("shrine_order_id") REFERENCES "shrine_orders" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "talisman_items_slug_key" ON "talisman_items"("slug");

-- CreateIndex
CREATE INDEX "talisman_items_category_sort_order_idx" ON "talisman_items"("category", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "shrine_orders_serial_key" ON "shrine_orders"("serial");

-- CreateIndex
CREATE UNIQUE INDEX "shrine_orders_result_access_transaction_id_key" ON "shrine_orders"("result_access_transaction_id");

-- CreateIndex
CREATE INDEX "shrine_orders_user_id_status_idx" ON "shrine_orders"("user_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "shrine_incense_logs_shrine_order_id_date_key_key" ON "shrine_incense_logs"("shrine_order_id", "date_key");
