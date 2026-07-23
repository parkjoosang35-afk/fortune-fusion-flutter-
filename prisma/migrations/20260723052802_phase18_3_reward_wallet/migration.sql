-- CreateTable
CREATE TABLE "wallets" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "currency_type" TEXT NOT NULL DEFAULT 'POINT',
    "balance" INTEGER NOT NULL DEFAULT 0,
    "balance_synced_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "point_histories" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "wallet_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "amount" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "source_type" TEXT NOT NULL,
    "source_id" INTEGER,
    "balance_after" INTEGER NOT NULL,
    "expire_at" DATETIME,
    "memo" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "point_histories_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "point_histories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "point_policies" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "source_type" TEXT NOT NULL,
    "amount" INTEGER NOT NULL DEFAULT 0,
    "daily_limit" INTEGER,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateTable
CREATE TABLE "point_expiry_batches" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "target_date" DATETIME NOT NULL,
    "expired_amount_total" INTEGER NOT NULL DEFAULT 0,
    "processed_user_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateIndex
CREATE UNIQUE INDEX "wallets_user_id_currency_type_key" ON "wallets"("user_id", "currency_type");

-- CreateIndex
CREATE INDEX "point_histories_user_id_created_at_idx" ON "point_histories"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "point_histories_source_type_source_id_idx" ON "point_histories"("source_type", "source_id");

-- CreateIndex
CREATE UNIQUE INDEX "point_policies_source_type_key" ON "point_policies"("source_type");

-- CreateIndex
CREATE INDEX "point_expiry_batches_target_date_idx" ON "point_expiry_batches"("target_date");
