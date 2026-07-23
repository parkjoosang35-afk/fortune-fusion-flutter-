-- CreateTable
CREATE TABLE "compatibility_factor_weights" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "factor_type" TEXT NOT NULL,
    "weight" REAL NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateIndex
CREATE UNIQUE INDEX "compatibility_factor_weights_factor_type_key" ON "compatibility_factor_weights"("factor_type");
