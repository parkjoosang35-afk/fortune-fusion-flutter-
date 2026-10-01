-- 신통방통 소원방(WishRoom) v2.6 테이블 신설 — design_handoff_sintong_wishroom_flutter
--
-- [배경] 51dba39~6941df6 커밋들에서 schema.prisma에 WishRoom* 모델 14종을
-- 추가하고 로컬 개발 DB(dev.db)에는 `prisma db push`로 즉시 반영했으나,
-- 정식 `prisma migrate dev`를 거치지 않아 migrations/ 디렉터리에 해당
-- 변경사항을 기록하는 마이그레이션 파일이 누락되어 있었다. 그 결과 운영
-- 서버(sintong.kr)는 `prisma migrate deploy`로는 이 테이블들을 전혀
-- 생성하지 못했고, 소원방 v2.6 API 44개 라우트가 전부 404/런타임 오류를
-- 일으켰다(2026-10-01 발견). 이 마이그레이션은 로컬 dev.db에 실제
-- 적용되어 있는 CREATE TABLE/INDEX DDL을 그대로 캡처하여 운영에도 동일한
-- 스키마가 적용되도록 한다 — 기존 테이블은 전혀 건드리지 않고(ADD ONLY
-- 원칙) wish_room 접두사 신규 테이블 14개만 추가한다.
--
-- [생성 순서] 외래키 의존성에 따라 wish_rooms(본체) → 이를 참조하는 자식
-- 테이블들 → wish_room_reviews를 참조하는 wish_room_review_congrats
-- 순서로 배치한다.

-- ── 소원방 본체 ──
CREATE TABLE IF NOT EXISTS "wish_rooms" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "char_code" TEXT NOT NULL DEFAULT 'F00',
    "text" TEXT NOT NULL,
    "theme" TEXT NOT NULL DEFAULT 'free',
    "outfit" TEXT,
    "wish_color" TEXT NOT NULL DEFAULT 'hope',
    "paper" TEXT NOT NULL DEFAULT 'hanji',
    "visibility" TEXT NOT NULL DEFAULT 'PUBLIC',
    "region" TEXT NOT NULL DEFAULT '',
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "report_count" INTEGER NOT NULL DEFAULT 0,
    "points" REAL NOT NULL DEFAULT 0,
    "level" INTEGER NOT NULL DEFAULT 1,
    "devotion_count" INTEGER NOT NULL DEFAULT 0,
    "support_count" INTEGER NOT NULL DEFAULT 0,
    "pouch_received" INTEGER NOT NULL DEFAULT 0,
    "comment_count" INTEGER NOT NULL DEFAULT 0,
    "bonus_pts" REAL NOT NULL DEFAULT 0,
    "devotions_today" INTEGER NOT NULL DEFAULT 0,
    "devotions_reset_date" TEXT,
    "last_devotion_at" DATETIME,
    "last_active_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "equip_json" TEXT NOT NULL DEFAULT '{}',
    "layout_json" TEXT NOT NULL DEFAULT '{}',
    "completed_at" DATETIME,
    "cancel_until" DATETIME,
    "seal_until" TEXT,
    "capsule" TEXT DEFAULT 'LOCKED',
    "outcome" TEXT,
    "wish_status" TEXT DEFAULT 'IN_PROGRESS',
    "unseal_notified" BOOLEAN NOT NULL DEFAULT false,
    "decay_notified" BOOLEAN NOT NULL DEFAULT false,
    "review_reward_granted" BOOLEAN NOT NULL DEFAULT false,
    "share_token" TEXT,
    "snapshot" TEXT,
    "sealed_at_final" DATETIME,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "wish_rooms_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "wish_rooms_share_token_key" ON "wish_rooms"("share_token");
CREATE INDEX "wish_rooms_user_id_status_idx" ON "wish_rooms"("user_id", "status");
CREATE INDEX "wish_rooms_visibility_status_created_at_idx" ON "wish_rooms"("visibility", "status", "created_at");
CREATE INDEX "wish_rooms_status_seal_until_idx" ON "wish_rooms"("status", "seal_until");

-- ── 응원 ──
CREATE TABLE IF NOT EXISTS "wish_room_supports" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "room_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "date_key" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_supports_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "wish_rooms" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "wish_room_supports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_room_supports_room_id_created_at_idx" ON "wish_room_supports"("room_id", "created_at");
CREATE UNIQUE INDEX "wish_room_supports_room_id_user_id_date_key_key" ON "wish_room_supports"("room_id", "user_id", "date_key");

-- ── 댓글 ──
CREATE TABLE IF NOT EXISTS "wish_room_comments" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "room_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "text" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "report_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "wish_room_comments_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "wish_rooms" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "wish_room_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_room_comments_room_id_created_at_idx" ON "wish_room_comments"("room_id", "created_at");

-- ── 선물(복주머니 보내기) ──
CREATE TABLE IF NOT EXISTS "wish_room_gifts" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "room_id" INTEGER NOT NULL,
    "sender_id" INTEGER NOT NULL,
    "amount" INTEGER NOT NULL,
    "date_key" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_gifts_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "wish_rooms" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "wish_room_gifts_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_room_gifts_sender_id_date_key_idx" ON "wish_room_gifts"("sender_id", "date_key");
CREATE INDEX "wish_room_gifts_room_id_created_at_idx" ON "wish_room_gifts"("room_id", "created_at");

-- ── 응원 보상 수령 ──
CREATE TABLE IF NOT EXISTS "wish_room_support_reward_claims" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "room_id" INTEGER NOT NULL,
    "at" INTEGER NOT NULL,
    "item_code" TEXT,
    "claimed_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_support_reward_claims_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "wish_rooms" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "wish_room_support_reward_claims_room_id_at_key" ON "wish_room_support_reward_claims"("room_id", "at");

-- ── 성취 후기 ──
CREATE TABLE IF NOT EXISTS "wish_room_reviews" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "room_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "text" TEXT NOT NULL,
    "photo_url" TEXT,
    "visibility" TEXT NOT NULL DEFAULT 'PUBLIC',
    "congrats_count" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'visible',
    "flags_json" TEXT NOT NULL DEFAULT '[]',
    "report_count" INTEGER NOT NULL DEFAULT 0,
    "reward_granted" BOOLEAN NOT NULL DEFAULT false,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "wish_room_reviews_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "wish_rooms" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "wish_room_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_room_reviews_room_id_idx" ON "wish_room_reviews"("room_id");
CREATE INDEX "wish_room_reviews_status_created_at_idx" ON "wish_room_reviews"("status", "created_at");

-- ── 후기 축하 ──
CREATE TABLE IF NOT EXISTS "wish_room_review_congrats" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "review_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_review_congrats_review_id_fkey" FOREIGN KEY ("review_id") REFERENCES "wish_room_reviews" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "wish_room_review_congrats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "wish_room_review_congrats_review_id_user_id_key" ON "wish_room_review_congrats"("review_id", "user_id");

-- ── 보유 캐릭터 ──
CREATE TABLE IF NOT EXISTS "wish_room_characters_owned" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "char_code" TEXT NOT NULL,
    "purchase_price" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_characters_owned_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "wish_room_characters_owned_user_id_char_code_key" ON "wish_room_characters_owned"("user_id", "char_code");

-- ── 보유 아이템(꾸미기) ──
CREATE TABLE IF NOT EXISTS "wish_room_items_owned" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "item_id" TEXT NOT NULL,
    "purchase_price" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_items_owned_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "wish_room_items_owned_user_id_item_id_key" ON "wish_room_items_owned"("user_id", "item_id");

-- ── 보유 의상 ──
CREATE TABLE IF NOT EXISTS "wish_room_outfits_owned" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "char_code" TEXT NOT NULL,
    "theme" TEXT NOT NULL,
    "purchase_price" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_outfits_owned_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "wish_room_outfits_owned_user_id_char_code_theme_key" ON "wish_room_outfits_owned"("user_id", "char_code", "theme");

-- ── 사용자별 소원방 상태(온보딩/대표캐릭터 등) ──
CREATE TABLE IF NOT EXISTS "wish_room_user_states" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "rep_char_code" TEXT NOT NULL DEFAULT 'F00',
    "skip_intro" BOOLEAN NOT NULL DEFAULT false,
    "first_room_intro_done" BOOLEAN NOT NULL DEFAULT false,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "last_enter_date" TEXT,
    CONSTRAINT "wish_room_user_states_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "wish_room_user_states_user_id_key" ON "wish_room_user_states"("user_id");

-- ── 복주머니 적립 로그(일일 한도 판정용) ──
CREATE TABLE IF NOT EXISTS "wish_room_earn_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "source" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "date_key" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_earn_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_room_earn_logs_user_id_source_date_key_idx" ON "wish_room_earn_logs"("user_id", "source", "date_key");

-- ── 차단 ──
CREATE TABLE IF NOT EXISTS "wish_room_blocks" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "blocker_id" INTEGER NOT NULL,
    "blocked_id" INTEGER NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_blocks_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "wish_room_blocks_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_room_blocks_blocker_id_idx" ON "wish_room_blocks"("blocker_id");
CREATE UNIQUE INDEX "wish_room_blocks_blocker_id_blocked_id_key" ON "wish_room_blocks"("blocker_id", "blocked_id");

-- ── 행동 로그(레이트리밋 등) ──
CREATE TABLE IF NOT EXISTS "wish_room_action_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "action" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_action_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_room_action_logs_user_id_action_created_at_idx" ON "wish_room_action_logs"("user_id", "action", "created_at");
