-- CreateTable
CREATE TABLE "popups" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title" TEXT NOT NULL,
    "image_url" TEXT,
    "link_url" TEXT,
    "display_condition" TEXT,
    "start_at" DATETIME NOT NULL,
    "end_at" DATETIME NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateIndex
CREATE INDEX "popups_start_at_end_at_idx" ON "popups"("start_at", "end_at");
