-- 기존 기능 11개 테이블 운영 배포용 소급 마이그레이션.
-- [배경] 아래 11개 테이블은 schema.prisma에 이미 반영되어 있었으나(각 기능
-- 구현 당시 git 커밋도 완료됨), 로컬 dev.db에는 `prisma db push`로만 적용되고
-- 정식 마이그레이션 파일이 생성되지 않아 `prisma migrate deploy`(운영 배포
-- 표준 절차)로는 운영 서버에 전혀 생성되지 않는 상태였다.
-- 20261005160000_add_topic_engine_tables 배포 중 saju_facts_cache 테이블
-- 누락으로 500 에러가 발생해 전체 스키마 대조를 실시, 동일 패턴의 테이블
-- 11개를 추가로 발견했다. 전부 로컬 dev.db 실제 정의(sqlite3 .schema 덤프)를
-- 그대로 옮긴 것으로 schema.prisma와 100% 일치한다(ADD ONLY, 기존 테이블/
-- 컬럼 변경 없음). FK 의존성 순서(guinji_map → map_member → relationship/
-- share_event/unlock_record, shop_catalog_items → user_inventory_items)를
-- 지켜 생성한다.

-- ── 상담 후기(consultation_sessions 1:1) ──
CREATE TABLE IF NOT EXISTS "consultation_reviews" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "session_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "reward_granted" BOOLEAN NOT NULL DEFAULT false,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "consultation_reviews_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "consultation_sessions" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "consultation_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "consultation_reviews_session_id_key" ON "consultation_reviews"("session_id");
CREATE INDEX "consultation_reviews_user_id_created_at_idx" ON "consultation_reviews"("user_id", "created_at");

-- ── 상점 카탈로그(인장/촛불/부적 등) ──
CREATE TABLE IF NOT EXISTS "shop_catalog_items" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "item_type" TEXT NOT NULL,
    "item_code" TEXT NOT NULL,
    "name_ko" TEXT NOT NULL,
    "description_ko" TEXT NOT NULL,
    "price" INTEGER NOT NULL,
    "duration_days" INTEGER,
    "display_priority" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE UNIQUE INDEX "shop_catalog_items_item_code_key" ON "shop_catalog_items"("item_code");
CREATE INDEX "shop_catalog_items_item_type_is_active_idx" ON "shop_catalog_items"("item_type", "is_active");

-- ── 사용자 보유 아이템(shop_catalog_items 참조) ──
CREATE TABLE IF NOT EXISTS "user_inventory_items" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "catalog_item_id" INTEGER NOT NULL,
    "purchase_price" INTEGER NOT NULL,
    "expires_at" DATETIME,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "user_inventory_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "user_inventory_items_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "shop_catalog_items" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "user_inventory_items_user_id_created_at_idx" ON "user_inventory_items"("user_id", "created_at");

-- ── 감사 인장(소원방) ──
CREATE TABLE IF NOT EXISTS "gratitude_seals" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "sender_id" INTEGER NOT NULL,
    "recipient_id" INTEGER NOT NULL,
    "source_pouch_id" INTEGER NOT NULL,
    "wish_id" INTEGER NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "gratitude_seals_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "gratitude_seals_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "gratitude_seals_recipient_id_created_at_idx" ON "gratitude_seals"("recipient_id", "created_at");
CREATE UNIQUE INDEX "gratitude_seals_source_pouch_id_key" ON "gratitude_seals"("source_pouch_id");

-- ── 귀인지도(Guinji) 본체 ──
CREATE TABLE IF NOT EXISTS "guinji_map" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "owner_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "invite_status" TEXT NOT NULL DEFAULT 'active',
    "token_issued_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revoked_at" DATETIME,
    "owner_saju_parsed" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "guinji_map_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "guinji_map_token_key" ON "guinji_map"("token");
CREATE UNIQUE INDEX "guinji_map_owner_id_key" ON "guinji_map"("owner_id");

-- ── 귀인지도 구성원(guinji_map 참조) ──
CREATE TABLE IF NOT EXISTS "map_member" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "map_id" INTEGER NOT NULL,
    "joined_user_id" INTEGER,
    "name" TEXT NOT NULL,
    "solarLunar" TEXT NOT NULL DEFAULT 'solar',
    "birth_date" TEXT NOT NULL,
    "birth_time" TEXT,
    "birth_time_missing" BOOLEAN NOT NULL DEFAULT false,
    "saju_parsed" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "map_member_map_id_fkey" FOREIGN KEY ("map_id") REFERENCES "guinji_map" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "map_member_joined_user_id_fkey" FOREIGN KEY ("joined_user_id") REFERENCES "users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX "map_member_map_id_status_idx" ON "map_member"("map_id", "status");

-- ── 귀인지도 관계 판정 결과(guinji_map, map_member 참조) ──
CREATE TABLE IF NOT EXISTS "relationship" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "map_id" INTEGER NOT NULL,
    "owner_id" INTEGER NOT NULL,
    "member_id" INTEGER NOT NULL,
    "relation_type" TEXT NOT NULL,
    "chemistry_score" INTEGER NOT NULL,
    "ohaeng_evidence" TEXT NOT NULL,
    "calculated_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "relationship_map_id_fkey" FOREIGN KEY ("map_id") REFERENCES "guinji_map" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "relationship_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "relationship_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "map_member" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "relationship_member_id_key" ON "relationship"("member_id");
CREATE INDEX "relationship_map_id_relation_type_idx" ON "relationship"("map_id", "relation_type");

-- ── 귀인지도 공유 이벤트(guinji_map 참조) ──
CREATE TABLE IF NOT EXISTS "share_event" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "map_id" INTEGER NOT NULL,
    "token" TEXT NOT NULL,
    "from_user_id" INTEGER NOT NULL,
    "opened_at" DATETIME,
    "joined_at" DATETIME,
    "re_shared_from" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "share_event_map_id_fkey" FOREIGN KEY ("map_id") REFERENCES "guinji_map" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "share_event_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "share_event_token_idx" ON "share_event"("token");
CREATE INDEX "share_event_map_id_created_at_idx" ON "share_event"("map_id", "created_at");

-- ── 귀인지도 잠금해제 기록(map_member 참조) ──
CREATE TABLE IF NOT EXISTS "unlock_record" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "member_id" INTEGER NOT NULL,
    "date_key" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "unlock_record_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "unlock_record_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "map_member" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "unlock_record_user_id_date_key_idx" ON "unlock_record"("user_id", "date_key");
CREATE UNIQUE INDEX "unlock_record_user_id_member_id_key" ON "unlock_record"("user_id", "member_id");

-- ── 행운상자(복주머니 확장) 광고시청 개봉 로그 ──
CREATE TABLE IF NOT EXISTS "pouch_box_open_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "session_id" TEXT NOT NULL,
    "started_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" DATETIME,
    "watch_seconds" INTEGER,
    "reward_amount" INTEGER NOT NULL DEFAULT 0,
    "reward_tier" TEXT,
    "reward_status" TEXT NOT NULL DEFAULT 'PENDING',
    "idempotency_key" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pouch_box_open_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "pouch_box_open_logs_idempotency_key_key" ON "pouch_box_open_logs"("idempotency_key");
CREATE INDEX "pouch_box_open_logs_user_id_created_at_idx" ON "pouch_box_open_logs"("user_id", "created_at");
CREATE INDEX "pouch_box_open_logs_user_id_reward_status_created_at_idx" ON "pouch_box_open_logs"("user_id", "reward_status", "created_at");

-- ── [정통사주 리뉴얼] 사주 계산 결과 캐시(saju_engine /saju/v3/facts 응답 캐시) ──
-- 이 테이블이 바로 "주제를 불러오는 중 오류가 발생했습니다"(topics/select 500)의
-- 직접 원인이었다 — saju-engine-client.ts가 캐시 조회 시 참조하는 테이블.
CREATE TABLE IF NOT EXISTS "saju_facts_cache" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER,
    "birth_key" TEXT NOT NULL,
    "birth_date" TEXT NOT NULL,
    "birth_time" TEXT,
    "is_lunar" BOOLEAN NOT NULL DEFAULT false,
    "gender" TEXT,
    "zihour_policy" TEXT NOT NULL DEFAULT 'traditional',
    "facts_json" TEXT NOT NULL,
    "engine_version" TEXT NOT NULL DEFAULT 'v3.3',
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "saju_facts_cache_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "saju_facts_cache_birth_key_key" ON "saju_facts_cache"("birth_key");
CREATE INDEX "saju_facts_cache_user_id_idx" ON "saju_facts_cache"("user_id");
