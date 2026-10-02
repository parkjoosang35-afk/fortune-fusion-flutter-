-- 소원방 배경화면(W1~W5, docs/WALLPAPER.md) 지원 컬럼 추가.
--
-- [배경] A-5 — Flutter WrRepository의 wallpaperManifest()/wallpaperStatus()/setWallpaper()/
-- clearWallpaper()/wallpaperLevelNotice() 5개 메서드(wr_api.dart W1~W5)가 호출할 서버
-- 라우트가 전혀 없었다(전수감사 4대 결함 중 하나). 이 마이그레이션은 그 라우트들이 쓸
-- 저장 공간만 추가한다 — 기존 테이블은 전혀 건드리지 않는다(ADD COLUMN 전용).
--
-- wish_rooms.wp_version/wp_key: 방 1개당 "배경화면 렌더 결과가 바뀌었는지" 감지하는
-- 카운터·서명 스냅샷(app/api.js r.wpVersion/r.wpKey 포팅 — W1/W2에서 조회 시점에 갱신).
-- wish_room_user_states.wallpaper_*: 사용자 1명당 "지금 배경화면으로 설정해둔 방" 상태
-- (app/api.js db.me.wallpaper 포팅 — W2~W5에서 읽고 쓴다). roomId가 NULL이면 미설정.

ALTER TABLE "wish_rooms" ADD COLUMN "wp_version" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "wish_rooms" ADD COLUMN "wp_key" TEXT;

ALTER TABLE "wish_room_user_states" ADD COLUMN "wallpaper_room_id" INTEGER;
ALTER TABLE "wish_room_user_states" ADD COLUMN "wallpaper_platform" TEXT;
ALTER TABLE "wish_room_user_states" ADD COLUMN "wallpaper_target" TEXT;
ALTER TABLE "wish_room_user_states" ADD COLUMN "wallpaper_version" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "wish_room_user_states" ADD COLUMN "wallpaper_auto_synced" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "wish_room_user_states" ADD COLUMN "wallpaper_seen_level_notice" INTEGER NOT NULL DEFAULT 0;
