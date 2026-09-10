-- [신통방통 타로 65종 주제 연동] tarot_cards 확장(name_kr/basic_meaning/suit)
-- + tarot_topics/tarot_positions 신설(5개 파일럿 주제부터 시작).
ALTER TABLE "tarot_cards" ADD COLUMN "name_kr" TEXT NOT NULL DEFAULT '';
ALTER TABLE "tarot_cards" ADD COLUMN "basic_meaning" TEXT NOT NULL DEFAULT '';
ALTER TABLE "tarot_cards" ADD COLUMN "suit" TEXT;

CREATE TABLE "tarot_topics" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "topic_key" TEXT NOT NULL,
    "category_group" TEXT NOT NULL,
    "topic_name" TEXT NOT NULL,
    "description" TEXT,
    "question_type" TEXT NOT NULL DEFAULT 'open',
    "allowed_spreads" TEXT NOT NULL,
    "yes_no_enabled" BOOLEAN NOT NULL DEFAULT false,
    "is_choice_ab" BOOLEAN NOT NULL DEFAULT false,
    "prompt_domain" TEXT NOT NULL DEFAULT 'tarot',
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE UNIQUE INDEX "tarot_topics_topic_key_key" ON "tarot_topics"("topic_key");

CREATE TABLE "tarot_positions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "topic_id" INTEGER NOT NULL,
    "spread_type" TEXT NOT NULL,
    "position_index" INTEGER NOT NULL,
    "position_name" TEXT NOT NULL,
    "position_purpose" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "tarot_positions_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "tarot_topics" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "tarot_positions_topic_id_spread_type_position_index_key" ON "tarot_positions"("topic_id", "spread_type", "position_index");
CREATE INDEX "tarot_positions_topic_id_spread_type_idx" ON "tarot_positions"("topic_id", "spread_type");
