-- CreateTable
CREATE TABLE "amulet_grades" (
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
CREATE TABLE "amulet_items" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "grade_id" INTEGER NOT NULL,
    "effect_description" TEXT NOT NULL,
    "image_url" TEXT,
    "is_ai_generated" BOOLEAN NOT NULL DEFAULT false,
    "price_point" INTEGER NOT NULL DEFAULT 0,
    "is_limited" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "amulet_items_grade_id_fkey" FOREIGN KEY ("grade_id") REFERENCES "amulet_grades" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "amulet_grades_code_key" ON "amulet_grades"("code");

-- CreateIndex
CREATE INDEX "amulet_items_grade_id_idx" ON "amulet_items"("grade_id");
