-- CreateTable
CREATE TABLE "compatibility_requests" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "requester_user_id" INTEGER NOT NULL,
    "target_user_id" INTEGER,
    "target_input" TEXT,
    "type" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "compatibility_requests_requester_user_id_fkey" FOREIGN KEY ("requester_user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "compatibility_requests_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "compatibility_results" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "request_id" INTEGER NOT NULL,
    "score" INTEGER NOT NULL,
    "detail" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "compatibility_results_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "compatibility_requests" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE INDEX "compatibility_requests_requester_user_id_created_at_idx" ON "compatibility_requests"("requester_user_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "compatibility_results_request_id_key" ON "compatibility_results"("request_id");
