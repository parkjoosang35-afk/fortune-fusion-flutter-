/// [인트로 전면 개편] admin_web `GET /api/public/intro-config` 응답을 그대로
/// 반영하는 도메인 모델. 자유 배치/좌표/애니메이션 수치는 관리자가 손댈 수 없고,
/// 아래 필드(on-off/문구/이미지/보상 수량)만 서버에서 내려온다.
///
/// [설계 원칙] 서버 조회가 실패하거나(오프라인) 아직 초기화되지 않은 경우를 대비해
/// [IntroConfigModel.fallback]에 사용자가 요청서에 명시한 정확한 카피를 하드코딩
/// 기본값으로 보관한다 — "관리자 미설정 상태에서도 인트로가 정상 동작"해야 한다.
library;

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
  });

  /// 서버 조회 실패 시(오프라인/초기화 전) 사용하는 기본값.
  /// 사용자 요청서에 정확히 지정된 카피와 100% 동일하게 유지한다.
  factory IntroConfigModel.fallback() => const IntroConfigModel(
    isEnabled: true,
    showOnlyFirstLaunch: true,
    showSkipButton: true,
    showGuestHint: true,
    splashTitle: '신통방통',
    splashSubtitle: null,
    card1Title: '광고 한 번으로, 1시간 동안 자유롭게',
    card1Description:
        '프리패스를 받으면 오늘의 운세, 타로 등 전체 운세 콘텐츠를 가볍게 볼 수 있어요.',
    card1ImageUrl: null,
    card2Title: '복주머니는 무료로 모으고, 자유롭게 써요',
    card2Description: '광고를 보거나 활동하면 복주머니가 쌓이고, 소원게시판과 소원성에서 사용할 수 있어요.',
    card2ImageUrl: null,
    ctaTitle: '이제 신통방통을 시작해보세요',
    ctaSubtitle: '먼저 둘러보고, 원할 때 가입해도 괜찮아요.',
    signupRewardText: '지금 가입하면 복주머니 100개 지급',
    signupRewardAmount: 100,
  );

  factory IntroConfigModel.fromJson(Map<String, dynamic> json) {
    final fallback = IntroConfigModel.fallback();
    return IntroConfigModel(
      isEnabled: json['isEnabled'] as bool? ?? fallback.isEnabled,
      showOnlyFirstLaunch:
          json['showOnlyFirstLaunch'] as bool? ?? fallback.showOnlyFirstLaunch,
      showSkipButton: json['showSkipButton'] as bool? ?? fallback.showSkipButton,
      showGuestHint: json['showGuestHint'] as bool? ?? fallback.showGuestHint,
      splashTitle: json['splashTitle'] as String? ?? fallback.splashTitle,
      splashSubtitle: json['splashSubtitle'] as String?,
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
