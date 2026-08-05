-- CreateTable
CREATE TABLE "healing_quotes" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "content" TEXT NOT NULL,
    "author" TEXT,
    "category" TEXT NOT NULL DEFAULT 'healing',
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "start_at" DATETIME,
    "end_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateIndex
CREATE INDEX "healing_quotes_is_active_idx" ON "healing_quotes"("is_active");
