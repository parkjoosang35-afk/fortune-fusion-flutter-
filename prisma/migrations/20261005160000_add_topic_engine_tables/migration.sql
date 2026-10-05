-- STEP1-6 Topic Engine 테이블 신설 (운영 미배포분 소급 마이그레이션)
-- [배경] TopicCatalog/TopicCondition/TopicPromptTemplate/TopicExposureHistory/
-- TopicInterpretResult 5개 모델이 schema.prisma에는 STEP3(aa9a425)~STEP6(9977d53)
-- 커밋으로 이미 반영되어 있었으나, 로컬 dev.db에는 `prisma db push` 방식으로만
-- 직접 적용되고 정식 마이그레이션 파일(prisma/migrations/*)이 생성되지 않았다.
-- 이로 인해 `prisma migrate deploy`(운영 배포 표준 절차)로는 운영 서버에 이
-- 테이블들이 전혀 생성되지 않아, saju-renewal topics/select·interpret API가
-- 운영에서 전부 실패(테이블 없음)하는 상태였다. 이 마이그레이션은 로컬 dev.db에
-- 실제 존재하는 테이블 정의(sqlite3 .schema로 덤프)를 그대로 옮긴 것으로,
-- schema.prisma와 100% 일치한다(ADD ONLY, 기존 테이블/컬럼 변경 없음).

-- ── 주제 카탈로그(29종: 릴리즈1 활성 26 + 폴백1 LIFE_000 + 2차 예정 2) ──
CREATE TABLE IF NOT EXISTS "topic_catalog" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "topic_id" TEXT NOT NULL,
    "topic_name" TEXT NOT NULL,
    "category_group" TEXT NOT NULL,
    "is_timing" BOOLEAN NOT NULL DEFAULT false,
    "is_fallback" BOOLEAN NOT NULL DEFAULT false,
    "release_phase" INTEGER NOT NULL DEFAULT 1,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME
);
CREATE UNIQUE INDEX "topic_catalog_topic_id_key" ON "topic_catalog"("topic_id");

-- ── 주제별 노출 조건 ──
CREATE TABLE IF NOT EXISTS "topic_conditions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "topic_id" TEXT NOT NULL,
    "condition_type" TEXT NOT NULL,
    "condition_value" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "topic_conditions_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "topic_catalog" ("topic_id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "topic_conditions_topic_id_idx" ON "topic_conditions"("topic_id");

-- ── 주제별 LLM 프롬프트 템플릿(summary/detail 모드별) ──
CREATE TABLE IF NOT EXISTS "topic_prompt_templates" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "topic_id" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "system_prompt" TEXT NOT NULL,
    "fallback_json" TEXT NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "topic_prompt_templates_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "topic_catalog" ("topic_id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "topic_prompt_templates_topic_id_mode_version_key" ON "topic_prompt_templates"("topic_id", "mode", "version");

-- ── 사용자별 노출 이력 ──
CREATE TABLE IF NOT EXISTS "topic_exposure_history" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "topic_id" TEXT NOT NULL,
    "birth_key" TEXT NOT NULL,
    "viewed_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "topic_exposure_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "topic_exposure_history_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "topic_catalog" ("topic_id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "topic_exposure_history_user_id_birth_key_idx" ON "topic_exposure_history"("user_id", "birth_key");

-- ── [STEP 4] Interpret 결과 캐시 + 멱등성 ──
CREATE TABLE IF NOT EXISTS "topic_interpret_results" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "topic_id" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "birth_key" TEXT NOT NULL,
    "result_json" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "topic_interpret_results_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "topic_interpret_results_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "topic_catalog" ("topic_id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "topic_interpret_results_user_id_topic_id_mode_birth_key_key" ON "topic_interpret_results"("user_id", "topic_id", "mode", "birth_key");
