-- CreateTable
CREATE TABLE "giftcard_products" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "brand" TEXT NOT NULL,
    "required_point" INTEGER NOT NULL,
    "stock_count" INTEGER NOT NULL DEFAULT 0,
    "valid_days" INTEGER NOT NULL DEFAULT 365,
    "image_url" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- CreateIndex
CREATE INDEX "giftcard_products_brand_idx" ON "giftcard_products"("brand");

-- CreateIndex
CREATE INDEX "giftcard_products_is_active_idx" ON "giftcard_products"("is_active");
