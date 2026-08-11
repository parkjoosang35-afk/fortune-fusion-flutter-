-- AlterTable
ALTER TABLE "pass_policies" ADD COLUMN "category_max_usage" INTEGER DEFAULT 2;

-- CreateTable
CREATE TABLE "pass_category_usages" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_pass_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "category_key" TEXT NOT NULL,
    "usage_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "pass_category_usages_user_pass_id_fkey" FOREIGN KEY ("user_pass_id") REFERENCES "user_passes" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "pass_category_usages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE INDEX "pass_category_usages_user_id_category_key_idx" ON "pass_category_usages"("user_id", "category_key");

-- CreateIndex
CREATE UNIQUE INDEX "pass_category_usages_user_pass_id_category_key_key" ON "pass_category_usages"("user_pass_id", "category_key");
