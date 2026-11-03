-- [궁합지도 통합 최종 개발 지시서 Phase 2 — Option A 승인분]
-- gunghap_pair_result.invite_id를 nullable로 변경하고, result_type(DIRECT/
-- INVITE 구분) + owner_user_id(DIRECT 결과 소유자) 컬럼을 신규 추가한다.
--
-- [원칙 준수]
--  1) 기존 invite 기반 데이터 손실 없음 — 전체 컬럼이 SELECT/INSERT로
--     1:1 그대로 이관되며, result_type은 전부 'INVITE'로 백필된다.
--  2) 초대 없이 생성되는 DIRECT 결과는 invite_id=NULL, result_type='DIRECT',
--     owner_user_id=<로그인 사용자 id>로 저장한다(Phase 3에서 구현 예정인
--     생성 API가 사용).
--  3) invite_id UNIQUE 인덱스는 유지된다 — SQLite의 UNIQUE 인덱스는 NULL을
--     "서로 다른 값"으로 취급해 복수 행의 NULL을 허용하면서도, 동일한
--     non-null invite_id의 중복 삽입은 여전히 차단한다(스크래치 DB 테스트로
--     실증 완료 — 본 PR 설명 참조). 따라서 기존 "1초대-1결과" 제약과
--     Phase 2의 "DIRECT 결과는 다건 가능" 요구사항이 동시에 충족된다.
--  4) SQLite는 컬럼의 NOT NULL 제약을 ALTER COLUMN으로 직접 풀 수 없으므로
--     Prisma가 표준적으로 사용하는 "테이블 재생성(rename-copy-drop)" 패턴을
--     사용한다 — 신규 추가 컬럼(DROP 없음), 기존 컬럼 삭제 없음.
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_gunghap_pair_result" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "invite_id" INTEGER,
    "result_type" TEXT NOT NULL DEFAULT 'INVITE',
    "owner_user_id" INTEGER,
    "joined_user_id" INTEGER,
    "guest_name" TEXT NOT NULL,
    "guest_gender" TEXT NOT NULL,
    "guest_solar_lunar" TEXT NOT NULL DEFAULT 'solar',
    "guest_birth_date" TEXT NOT NULL,
    "guest_birth_time" TEXT,
    "guest_birth_time_missing" BOOLEAN NOT NULL DEFAULT false,
    "guest_is_leap_month" BOOLEAN NOT NULL DEFAULT false,
    "guest_saju_parsed" TEXT NOT NULL,
    "fact_trace" TEXT NOT NULL,
    "category_results" TEXT NOT NULL,
    "engine_version" TEXT NOT NULL DEFAULT 'gunghap-1.0.0',
    "rule_version" TEXT NOT NULL DEFAULT 'gunghap-rules-1.0.0',
    "calculated_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "gunghap_pair_result_invite_id_fkey" FOREIGN KEY ("invite_id") REFERENCES "gunghap_invite" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "gunghap_pair_result_joined_user_id_fkey" FOREIGN KEY ("joined_user_id") REFERENCES "users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
INSERT INTO "new_gunghap_pair_result" ("calculated_at", "category_results", "created_at", "deleted_at", "engine_version", "fact_trace", "guest_birth_date", "guest_birth_time", "guest_birth_time_missing", "guest_gender", "guest_is_leap_month", "guest_name", "guest_saju_parsed", "guest_solar_lunar", "id", "invite_id", "joined_user_id", "rule_version", "updated_at") SELECT "calculated_at", "category_results", "created_at", "deleted_at", "engine_version", "fact_trace", "guest_birth_date", "guest_birth_time", "guest_birth_time_missing", "guest_gender", "guest_is_leap_month", "guest_name", "guest_saju_parsed", "guest_solar_lunar", "id", "invite_id", "joined_user_id", "rule_version", "updated_at" FROM "gunghap_pair_result";
DROP TABLE "gunghap_pair_result";
ALTER TABLE "new_gunghap_pair_result" RENAME TO "gunghap_pair_result";
CREATE UNIQUE INDEX "gunghap_pair_result_invite_id_key" ON "gunghap_pair_result"("invite_id");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
