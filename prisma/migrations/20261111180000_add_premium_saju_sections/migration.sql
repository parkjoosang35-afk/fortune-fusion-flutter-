-- [관리자 2.0 전면 재설계 - Task 12b] 프리미엄사주 PDF 섹션 템플릿 관리
-- ADD-only 수동 마이그레이션 (20261111150000/160000/170000과 동일한 패턴).
-- 기존 테이블/컬럼에 대한 변경은 전혀 없음 — 신규 테이블 1개만 추가한다.

CREATE TABLE "premium_saju_sections" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "section_key" TEXT NOT NULL,
    "section_label" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "version" INTEGER NOT NULL,
    "template_body" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE INDEX "premium_saju_sections_section_key_is_active_idx" ON "premium_saju_sections"("section_key", "is_active");
