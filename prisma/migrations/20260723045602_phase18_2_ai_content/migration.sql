-- CreateTable
CREATE TABLE "ai_prompt_templates" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "fortune_type_or_domain" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "template_body" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateTable
CREATE TABLE "ai_request_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "domain" TEXT NOT NULL,
    "request_ref_id" INTEGER,
    "ai_model" TEXT NOT NULL,
    "latency_ms" INTEGER,
    "token_usage" INTEGER,
    "cost_estimate" REAL,
    "status" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "tarot_cards" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "image_url" TEXT,
    "upright_meaning" TEXT NOT NULL,
    "reversed_meaning" TEXT NOT NULL,
    "arcana_type" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateTable
CREATE TABLE "tarot_spreads" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "card_count" INTEGER NOT NULL,
    "is_premium" BOOLEAN NOT NULL DEFAULT false,
    "layout_meta" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateIndex
CREATE INDEX "ai_prompt_templates_fortune_type_or_domain_is_active_idx" ON "ai_prompt_templates"("fortune_type_or_domain", "is_active");

-- CreateIndex
CREATE INDEX "ai_request_logs_domain_created_at_idx" ON "ai_request_logs"("domain", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "tarot_cards_name_key" ON "tarot_cards"("name");

-- CreateIndex
CREATE INDEX "tarot_cards_arcana_type_idx" ON "tarot_cards"("arcana_type");

-- CreateIndex
CREATE UNIQUE INDEX "tarot_spreads_name_key" ON "tarot_spreads"("name");
