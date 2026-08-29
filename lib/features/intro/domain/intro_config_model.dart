/// [인트로 전면 개편] admin_web `GET /api/public/intro-config` 응답을 그대로
/// 반영하는 도메인 모델. 자유 배치/좌표/애니메이션 수치는 관리자가 손댈 수 없고,
/// 아래 필드(on-off/문구/이미지/보상 수량)만 서버에서 내려온다.
///
/// [설계 원칙] 서버 조회가 실패하거나(오프라인) 아직 초기화되지 않은 경우를 대비해
/// [IntroConfigModel.fallback]에 사용자가 요청서에 명시한 정확한 카피를 하드코딩
/// 기본값으로 보관한다 — "관리자 미설정 상태에서도 인트로가 정상 동작"해야 한다.
///
/// [2026 디자인 핸드오프 콘텐츠 전면 반영] 이전까지 fallback에 들어 있던 카피
/// ("광고 한 번으로, 1시간 동안 자유롭게" 등)는 핸드오프 문서
/// (`design_handoff_onboarding_flow/README.md`, `screens/01_Intro.html`)의
/// 실제 4장 캐러셀 카피와 전혀 무관한 옛 문구였다. 이번 개정에서 fallback 전체를
/// 핸드오프 원문으로 교체하고, 핸드오프에만 있던 신규 요소
/// (스플래시 서브카피, 페이지3 피처리스트 3개)를 위한 필드를 추가한다.
/// admin_web(Prisma IntroConfig)에는 아직 피처리스트용 컬럼이 없으므로,
/// `featureItems`는 서버 응답에 없으면 항상 fallback 상수 3개를 사용한다
/// (추후 admin 스키마 확장 시 fromJson에서 파싱하도록 확장 가능).
library;

/// 페이지3(귀인지도) 피처 리스트 한 줄 — 한자 아이콘 + 제목 + 설명.
/// 핸드오프 `.feature` 블록(貴/緣/符) 3개를 그대로 반영한다.
class IntroFeatureItem {
  final String icon;
  final String title;
  final String description;

  const IntroFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class IntroConfigModel {
  final bool isEnabled;
  final bool showOnlyFirstLaunch;
  final bool showSkipButton;
  final bool showGuestHint;

  final String splashTitle;
  final String? splashSubtitle;

  final String card1Title;
  final String card1Description;
  final String? card1ImageUrl;

  final String card2Title;
  final String card2Description;
  final String? card2ImageUrl;

  final String ctaTitle;
  final String ctaSubtitle;
  final String signupRewardText;
  final int signupRewardAmount;

  /// [핸드오프 반영 - 신규] 페이지3(귀인지도) 피처리스트 3개.
  /// admin 서버 스키마에 아직 대응 컬럼이 없어 항상 fallback 상수를 사용한다.
  final List<IntroFeatureItem> featureItems;

  const IntroConfigModel({
    required this.isEnabled,
    required this.showOnlyFirstLaunch,
    required this.showSkipButton,
    required this.showGuestHint,
    required this.splashTitle,
    this.splashSubtitle,
    required this.card1Title,
    required this.card1Description,
    this.card1ImageUrl,
    required this.card2Title,
    required this.card2Description,
    this.card2ImageUrl,
    required this.ctaTitle,
    required this.ctaSubtitle,
    required this.signupRewardText,
    required this.signupRewardAmount,
    this.featureItems = const [],
  });

  /// 서버 조회 실패 시(오프라인/초기화 전) 사용하는 기본값.
  ///
  /// [2026 핸드오프 반영] 아래 카피는 `design_handoff_onboarding_flow`의
  /// `screens/01_Intro.html` 및 `README.md` §페이지별 스펙 표에서 그대로
  /// 옮긴 원문이다(줄바꿈 위치까지 핸드오프의 `<br/>` 지점과 동일하게 `\n` 유지).
  factory IntroConfigModel.fallback() => const IntroConfigModel(
    isEnabled: true,
    showOnlyFirstLaunch: true,
    showSkipButton: true,
    showGuestHint: true,
    // 페이지1(스플래시) · eyebrow: 神通萬通 · SINTONG
    splashTitle: '신통방통',
    splashSubtitle: '하늘의 답을\n신통도령이 전해드립니다',
    // 페이지2(오늘의 결이 무슨 빛인지) · eyebrow: CHAPTER · N°01
    card1Title: '오늘의 결이\n무슨 빛인지',
    card1Description: '별자리와 사주가 만나\n하루의 결을 그려드립니다.',
    card1ImageUrl: null,
    // 페이지3(내 곁의 귀인은 몇 명일까) · eyebrow: CHAPTER · N°02
    card2Title: '내 곁의\n귀인은 몇 명일까',
    card2Description: '생일만 있으면 돼요.\n지인을 초대해 지도를 채워보세요.',
    card2ImageUrl: null,
    // 페이지4(CTA) · eyebrow: READY · TO · BEGIN
    ctaTitle: '이제\n신통방통과 함께',
    ctaSubtitle: '생년월일 한번만 입력하면\n신통도령이 매일 봐드립니다.',
    // [기존 결정사항 유지] 가입 보상 배지 문구 — 핸드오프에는 없는 요소이지만
    // "가입 시 복주머니 100개 지급" 결정 자체는 이전 세션에서 확정된 사항이라
    // 문구만 유지한다(§CTA 섹션 참고).
    signupRewardText: '지금 가입하면 복주머니 100개 지급',
    signupRewardAmount: 100,
    featureItems: [
      IntroFeatureItem(
        icon: '貴',
        title: '귀인 · 오른팔 · 인연',
        description: '다섯 유형의 관계로 결을 풀어봐요',
      ),
      IntroFeatureItem(
        icon: '緣',
        title: '붉은 실 · 궁합',
        description: '두 사람의 결을 나란히 봐드립니다',
      ),
      IntroFeatureItem(
        icon: '符',
        title: '복주머니 · 매일의 부적',
        description: '출석하고 나눌수록 밝아지는 방',
      ),
    ],
  );

  factory IntroConfigModel.fromJson(Map<String, dynamic> json) {
    final fallback = IntroConfigModel.fallback();
    return IntroConfigModel(
      isEnabled: json['isEnabled'] as bool? ?? fallback.isEnabled,
      showOnlyFirstLaunch:
          json['showOnlyFirstLaunch'] as bool? ?? fallback.showOnlyFirstLaunch,
      showSkipButton:
          json['showSkipButton'] as bool? ?? fallback.showSkipButton,
      showGuestHint: json['showGuestHint'] as bool? ?? fallback.showGuestHint,
      splashTitle: json['splashTitle'] as String? ?? fallback.splashTitle,
      splashSubtitle:
          json['splashSubtitle'] as String? ?? fallback.splashSubtitle,
      card1Title: json['card1Title'] as String? ?? fallback.card1Title,
      card1Description:
          json['card1Description'] as String? ?? fallback.card1Description,
      card1ImageUrl: json['card1ImageUrl'] as String?,
      card2Title: json['card2Title'] as String? ?? fallback.card2Title,
      card2Description:
          json['card2Description'] as String? ?? fallback.card2Description,
      card2ImageUrl: json['card2ImageUrl'] as String?,
      ctaTitle: json['ctaTitle'] as String? ?? fallback.ctaTitle,
      ctaSubtitle: json['ctaSubtitle'] as String? ?? fallback.ctaSubtitle,
      signupRewardText:
          json['signupRewardText'] as String? ?? fallback.signupRewardText,
      signupRewardAmount:
          json['signupRewardAmount'] as int? ?? fallback.signupRewardAmount,
      // [admin 스키마 미확장] 서버는 아직 피처리스트를 내려주지 않으므로
      // 항상 fallback 상수 3개를 사용한다.
      featureItems: fallback.featureItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'showOnlyFirstLaunch': showOnlyFirstLaunch,
    'showSkipButton': showSkipButton,
    'showGuestHint': showGuestHint,
    'splashTitle': splashTitle,
    'splashSubtitle': splashSubtitle,
    'card1Title': card1Title,
    'card1Description': card1Description,
    'card1ImageUrl': card1ImageUrl,
    'card2Title': card2Title,
    'card2Description': card2Description,
    'card2ImageUrl': card2ImageUrl,
    'ctaTitle': ctaTitle,
    'ctaSubtitle': ctaSubtitle,
    'signupRewardText': signupRewardText,
    'signupRewardAmount': signupRewardAmount,
  };
}
