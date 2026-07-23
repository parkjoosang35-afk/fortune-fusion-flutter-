-- CreateTable
CREATE TABLE "statistics_snapshots" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "metric_code" TEXT NOT NULL,
    "period" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateIndex
CREATE UNIQUE INDEX "statistics_snapshots_metric_code_period_key" ON "statistics_snapshots"("metric_code", "period");
