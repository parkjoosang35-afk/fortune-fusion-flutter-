-- CreateTable: economy_config (복주머니 경제 핀조절 레버)
CREATE TABLE "economy_config" (
    "key" TEXT NOT NULL PRIMARY KEY,
    "value" REAL NOT NULL,
    "description" TEXT,
    "updated_at" DATETIME NOT NULL,
    "updated_by" TEXT
);

-- Append-only 보호: point_histories는 수정/삭제를 허용하지 않는다.
-- (Fortune Fusion 마스터 개발 프롬프트 2부 "bok_ledger append-only" 철학 이식.
--  잔고는 wallets.balance 캐시값이지만, 그 캐시를 신뢰할 근거는 point_histories가
--  절대 조작되지 않는다는 보장에서 나온다. 이 트리거가 그 보장을 DB 레벨에서 강제한다.)
CREATE TRIGGER "prevent_point_history_update"
BEFORE UPDATE ON "point_histories"
BEGIN
  SELECT RAISE(ABORT, 'point_histories is append-only: UPDATE is not allowed');
END;

CREATE TRIGGER "prevent_point_history_delete"
BEFORE DELETE ON "point_histories"
BEGIN
  SELECT RAISE(ABORT, 'point_histories is append-only: DELETE is not allowed');
END;
