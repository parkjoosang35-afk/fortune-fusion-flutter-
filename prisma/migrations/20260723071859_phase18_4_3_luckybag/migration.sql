-- CreateTable
CREATE TABLE "luckybag_grades" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateTable
CREATE TABLE "luckybag_seasons" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "start_at" DATETIME NOT NULL,
    "end_at" DATETIME NOT NULL,
    "event_id" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateTable
CREATE TABLE "luckybag_products" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "price_point" INTEGER NOT NULL DEFAULT 0,
    "image_url" TEXT,
    "season_id" INTEGER,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "luckybag_products_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "luckybag_seasons" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "luckybag_reward_pools" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "luckybag_product_id" INTEGER NOT NULL,
    "grade_id" INTEGER NOT NULL,
    "reward_type" TEXT NOT NULL,
    "reward_ref_id" INTEGER,
    "reward_amount" INTEGER,
    "probability" REAL NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "luckybag_reward_pools_luckybag_product_id_fkey" FOREIGN KEY ("luckybag_product_id") REFERENCES "luckybag_products" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "luckybag_reward_pools_grade_id_fkey" FOREIGN KEY ("grade_id") REFERENCES "luckybag_grades" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "luckybag_open_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "luckybag_product_id" INTEGER NOT NULL,
    "reward_pool_id" INTEGER NOT NULL,
    "reward_result" TEXT NOT NULL,
    "external_asset_ref" TEXT,
    "status" TEXT NOT NULL DEFAULT 'completed',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "luckybag_open_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "luckybag_open_logs_luckybag_product_id_fkey" FOREIGN KEY ("luckybag_product_id") REFERENCES "luckybag_products" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "luckybag_open_logs_reward_pool_id_fkey" FOREIGN KEY ("reward_pool_id") REFERENCES "luckybag_reward_pools" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "luckybag_grades_code_key" ON "luckybag_grades"("code");

-- CreateIndex
CREATE INDEX "luckybag_seasons_start_at_end_at_idx" ON "luckybag_seasons"("start_at", "end_at");

-- CreateIndex
CREATE INDEX "luckybag_products_season_id_idx" ON "luckybag_products"("season_id");

-- CreateIndex
CREATE INDEX "luckybag_reward_pools_luckybag_product_id_idx" ON "luckybag_reward_pools"("luckybag_product_id");

-- CreateIndex
CREATE INDEX "luckybag_open_logs_user_id_created_at_idx" ON "luckybag_open_logs"("user_id", "created_at");
