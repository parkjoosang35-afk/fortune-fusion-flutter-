-- CreateTable
CREATE TABLE "fortune_requests" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "fortune_type" TEXT NOT NULL,
    "input_payload" TEXT NOT NULL,
    "source_type" TEXT NOT NULL DEFAULT 'ai_generated',
    "point_spent" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "fortune_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "fortune_results" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "request_id" INTEGER NOT NULL,
    "result_text" TEXT NOT NULL,
    "result_meta" TEXT,
    "ai_model" TEXT NOT NULL,
    "prompt_template_id" INTEGER NOT NULL,
    "prompt_version" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "fortune_results_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "fortune_requests" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "fortune_results_prompt_template_id_fkey" FOREIGN KEY ("prompt_template_id") REFERENCES "ai_prompt_templates" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE INDEX "fortune_requests_user_id_fortune_type_created_at_idx" ON "fortune_requests"("user_id", "fortune_type", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "fortune_results_request_id_key" ON "fortune_results"("request_id");
