-- CreateTable
CREATE TABLE "giftcard_issues" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "point_spent" INTEGER NOT NULL,
    "issued_code" TEXT,
    "issued_at" DATETIME,
    "expires_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'requested',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "giftcard_issues_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "giftcard_issues_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "giftcard_products" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "giftcard_usages" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "issue_id" INTEGER NOT NULL,
    "used_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "used_location_meta" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "giftcard_usages_issue_id_fkey" FOREIGN KEY ("issue_id") REFERENCES "giftcard_issues" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "giftcard_cancels" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "issue_id" INTEGER NOT NULL,
    "reason" TEXT,
    "cancelled_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "refunded_point" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "giftcard_cancels_issue_id_fkey" FOREIGN KEY ("issue_id") REFERENCES "giftcard_issues" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "giftcard_refunds" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "cancel_id" INTEGER NOT NULL,
    "refund_point_history_id" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "giftcard_refunds_cancel_id_fkey" FOREIGN KEY ("cancel_id") REFERENCES "giftcard_cancels" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "giftcard_refunds_refund_point_history_id_fkey" FOREIGN KEY ("refund_point_history_id") REFERENCES "point_histories" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "giftcard_reissues" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "original_issue_id" INTEGER NOT NULL,
    "new_issue_id" INTEGER NOT NULL,
    "reason" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "giftcard_reissues_original_issue_id_fkey" FOREIGN KEY ("original_issue_id") REFERENCES "giftcard_issues" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "giftcard_reissues_new_issue_id_fkey" FOREIGN KEY ("new_issue_id") REFERENCES "giftcard_issues" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "giftcard_expiry_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "issue_id" INTEGER NOT NULL,
    "expired_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "giftcard_expiry_logs_issue_id_fkey" FOREIGN KEY ("issue_id") REFERENCES "giftcard_issues" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE INDEX "giftcard_issues_user_id_created_at_idx" ON "giftcard_issues"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "giftcard_issues_expires_at_idx" ON "giftcard_issues"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "giftcard_usages_issue_id_key" ON "giftcard_usages"("issue_id");

-- CreateIndex
CREATE INDEX "giftcard_cancels_issue_id_idx" ON "giftcard_cancels"("issue_id");

-- CreateIndex
CREATE INDEX "giftcard_refunds_cancel_id_idx" ON "giftcard_refunds"("cancel_id");

-- CreateIndex
CREATE INDEX "giftcard_reissues_original_issue_id_idx" ON "giftcard_reissues"("original_issue_id");

-- CreateIndex
CREATE INDEX "giftcard_expiry_logs_issue_id_idx" ON "giftcard_expiry_logs"("issue_id");

-- CreateIndex
CREATE INDEX "giftcard_expiry_logs_expired_at_idx" ON "giftcard_expiry_logs"("expired_at");
