-- CreateTable
CREATE TABLE "intro_configs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT DEFAULT 1,
    "is_enabled" BOOLEAN NOT NULL DEFAULT true,
    "show_only_first_launch" BOOLEAN NOT NULL DEFAULT true,
    "show_skip_button" BOOLEAN NOT NULL DEFAULT true,
    "show_guest_hint" BOOLEAN NOT NULL DEFAULT true,
    "splash_title" TEXT NOT NULL DEFAULT '신통방통',
    "splash_subtitle" TEXT,
    "card1_title" TEXT NOT NULL DEFAULT '광고 한 번으로, 1시간 동안 자유롭게',
    "card1_description" TEXT NOT NULL DEFAULT '프리패스를 받으면 오늘의 운세, 타로 등 전체 운세 콘텐츠를 가볍게 볼 수 있어요.',
    "card1_image_url" TEXT,
    "card2_title" TEXT NOT NULL DEFAULT '복주머니는 무료로 모으고, 자유롭게 써요',
    "card2_description" TEXT NOT NULL DEFAULT '광고를 보거나 활동하면 복주머니가 쌓이고, 소원게시판과 소원성에서 사용할 수 있어요.',
    "card2_image_url" TEXT,
    "cta_title" TEXT NOT NULL DEFAULT '이제 신통방통을 시작해보세요',
    "cta_subtitle" TEXT NOT NULL DEFAULT '먼저 둘러보고, 원할 때 가입해도 괜찮아요.',
    "signup_reward_text" TEXT NOT NULL DEFAULT '지금 가입하면 복주머니 100개 지급',
    "signup_reward_amount" INTEGER NOT NULL DEFAULT 100,
    "updated_at" DATETIME NOT NULL,
    "updated_by" TEXT
);
