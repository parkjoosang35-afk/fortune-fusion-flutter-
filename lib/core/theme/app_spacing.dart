/// 03단계 §2 디자인 시스템 토큰 - Spacing(4px 기준 배수 스케일) / Radius
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();

  static const double card = 16;
  static const double cardSmall = 12;
  static const double button = 12;
  static const double buttonSmall = 8;
  static const double full = 999;

  // [운세 앱 개발 프롬프트-메인 UI 리뉴얼] 현대카드 앱 스타일 - 더 크고 둥근 라운드
  static const double hcCardLarge = 28; // 메인 카드(오늘의 우주 이야기, 부적&소원게시판 등)
  static const double hcCardMenu = 24; // 운세 메뉴 그리드 카드 / 소원방 배너
  static const double hcCardItem = 16; // 소원게시판 내부 아이템 카드
  static const double hcButtonPill = 30; // CTA 버튼(완전 pill)
}
