-- CreateTable
CREATE TABLE "ad_platform_configs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "platform" TEXT NOT NULL,
    "is_enabled" BOOLEAN NOT NULL DEFAULT false,
    "publisher_id" TEXT,
    "show_placeholder_when_disabled" BOOLEAN NOT NULL DEFAULT true,
    "surface_config_json" TEXT,
    "format_config_json" TEXT,
    "note" TEXT,
    "updated_at" DATETIME NOT NULL,
    "updated_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateIndex
CREATE UNIQUE INDEX "ad_platform_configs_platform_key" ON "ad_platform_configs"("platform");
