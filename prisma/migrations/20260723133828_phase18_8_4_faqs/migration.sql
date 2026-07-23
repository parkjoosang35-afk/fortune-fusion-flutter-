-- CreateTable
CREATE TABLE "faqs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "category" TEXT NOT NULL,
    "question" TEXT NOT NULL,
    "answer" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateIndex
CREATE INDEX "faqs_category_idx" ON "faqs"("category");
