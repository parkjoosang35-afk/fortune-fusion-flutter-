-- CreateTable
CREATE TABLE "user_amulets" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "amulet_item_id" INTEGER NOT NULL,
    "acquired_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" DATETIME,
    "source_type" TEXT NOT NULL,
    "external_asset_ref" TEXT,
    "status" TEXT NOT NULL DEFAULT 'held',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "user_amulets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "user_amulets_amulet_item_id_fkey" FOREIGN KEY ("amulet_item_id") REFERENCES "amulet_items" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "amulet_usage_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_amulet_id" INTEGER NOT NULL,
    "used_context_type" TEXT,
    "used_context_id" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "amulet_usage_logs_user_amulet_id_fkey" FOREIGN KEY ("user_amulet_id") REFERENCES "user_amulets" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "amulet_gifts" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "from_user_id" INTEGER NOT NULL,
    "to_user_id" INTEGER NOT NULL,
    "user_amulet_id" INTEGER NOT NULL,
    "message" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "amulet_gifts_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "amulet_gifts_to_user_id_fkey" FOREIGN KEY ("to_user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "amulet_gifts_user_amulet_id_fkey" FOREIGN KEY ("user_amulet_id") REFERENCES "user_amulets" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "amulet_collections" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "amulet_item_id" INTEGER NOT NULL,
    "first_acquired_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "total_count" INTEGER NOT NULL DEFAULT 1,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "amulet_collections_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "amulet_collections_amulet_item_id_fkey" FOREIGN KEY ("amulet_item_id") REFERENCES "amulet_items" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE INDEX "user_amulets_user_id_status_idx" ON "user_amulets"("user_id", "status");

-- CreateIndex
CREATE INDEX "amulet_usage_logs_user_amulet_id_idx" ON "amulet_usage_logs"("user_amulet_id");

-- CreateIndex
CREATE INDEX "amulet_gifts_from_user_id_idx" ON "amulet_gifts"("from_user_id");

-- CreateIndex
CREATE INDEX "amulet_gifts_to_user_id_idx" ON "amulet_gifts"("to_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "amulet_collections_user_id_amulet_item_id_key" ON "amulet_collections"("user_id", "amulet_item_id");
