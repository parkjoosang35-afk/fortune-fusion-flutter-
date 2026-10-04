-- 소원방 방문 기록 테이블 — 미션 04 "다른 소원방 3곳 둘러보기" 실제 행동 검증용.
-- [버그수정] /me/earn이 실제 행동 없이 무조건 지급하던 결함을 고치기 위해, 남의
-- 소원방 상세 조회(GET /wish-rooms/{id}) 시점에 방문 기록을 남기는 테이블을 신설한다.
CREATE TABLE "wish_room_visits" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "room_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "date_key" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_room_visits_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "wish_rooms" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "wish_room_visits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "wish_room_visits_room_id_user_id_date_key_key" ON "wish_room_visits"("room_id", "user_id", "date_key");

CREATE INDEX "wish_room_visits_user_id_date_key_idx" ON "wish_room_visits"("user_id", "date_key");
