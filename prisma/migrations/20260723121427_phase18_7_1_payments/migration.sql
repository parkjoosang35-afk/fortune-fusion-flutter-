-- CreateTable
CREATE TABLE "payments" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "order_type" TEXT NOT NULL,
    "order_ref_id" INTEGER,
    "amount" INTEGER NOT NULL,
    "currency_code" TEXT NOT NULL DEFAULT 'KRW',
    "pg_provider" TEXT NOT NULL,
    "pg_tx_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'paid',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "payments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "payments_pg_tx_id_key" ON "payments"("pg_tx_id");

-- CreateIndex
CREATE INDEX "payments_user_id_created_at_idx" ON "payments"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "payments_order_type_idx" ON "payments"("order_type");
