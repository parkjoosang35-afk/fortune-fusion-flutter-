import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';

/// [소원방 Riverpod 실험판] 이 모듈 전용 디자인 토큰.
///
/// 앱 전역 AppColors/AppSpacing(lib/core/theme/)과 값 체계가 다르므로
/// (전역은 라이트 테마 골드/바이올렛 톤, 이 모듈은 판타지 신전 감성 다크 톤)
/// 이름 충돌과 혼선을 피하기 위해 WishRoom 접두사를 붙여 모듈 내부에
/// 독립적으로 둔다. 실제 프로젝트에 정식 반영할 때는 이 값들을
/// UnifiedColors/UnifiedTokens 체계로 흡수 통합하는 것을 권장한다.
///
/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 사용자가 업로드한
/// `design_handoff_wish_room.zip`의 3가지 변형(V1 심야의 신전 / V2 달빛
/// 크리스탈 / V3 새벽 한지) 중 **V2 "마법진이 소환되는 신전"**
/// (`palette: 'crystal'`, `animClass: 'anim-dramatic'`)을 사용자가 명시적으로
/// 선택했다("마버진이 소환돼는 신전으로 하면 될것 같아"). 이에 따라 기존
/// 밤하늘/골드 팔레트를 README `Palette V2 — 달빛 크리스탈` 색상표의 값으로
/// 전면 교체한다. 기존 멤버 이름(gold/backgroundDeep 등)은 그대로 두되 값만
/// crystal 팔레트로 바꿔 하위 호환을 유지하고, `crystal`/`accent`/`sigil`/
/// `glowShadow` 등 새 토큰을 추가한다.
class WishRoomColors {
  WishRoomColors._();

  // ── 배경 그라디언트(--bg-1 / --bg-2) ──
  // README: --bg-1 #3d3568 (밝은 쪽, 화면 상단) / --bg-2 #1e1a3a (어두운 쪽,
  // 화면 하단). 기존 backgroundDeep/Mid/Soft 3단 그라디언트 이름을 유지하며
  // 값만 crystal 톤으로 교체한다.
  static const backgroundDeep = Color(0xFF1E1A3A); // --bg-2
  static const backgroundMid = Color(0xFF2C2650); // 중간 보간값
  static const backgroundSoft = Color(0xFF3D3568); // --bg-1

  // ── 촛불/마법진 발광색(--glow) ──
  // 기존 gold/goldSoft 이름은 유지하되, crystal 팔레트의 라벤더 글로우
  // (#e8c8f5)로 교체한다. 화면 안에서는 "촛불빛" 역할을 그대로 수행한다.
  static const gold = Color(0xFFE8C8F5); // --glow
  static const goldSoft = Color(0xFFF5E4FB); // --glow보다 더 밝은 하이라이트

  // ── 신규: crystal 팔레트 전용 토큰(README 색상표 그대로) ──
  static const glow = gold; // 별칭 — 새 코드에서는 의미가 더 분명한 이 이름 권장
  static const glowSoft = goldSoft;
  static const glowShadow = Color(0x59E8C8F5); // rgba(232,200,245,0.35)
  static const crystal = Color(0xFFA8D5E3); // --crystal (아쿠아)
  static const accent = Color(0xFF7FB8D4); // --accent (미스티 골드/아쿠아 블루)
  static const sigil = Color(0xFFE8C8F5); // --sigil (마법진 라인 색)

  // ── 본문 텍스트(--fg / --muted) ──
  static const textPrimary = Color(0xFFF0EAFF); // --fg
  static const textSecondary = Color(0xA6DCD2F5); // --muted (rgba 65%)
  static const textTertiary = Color(0x66DCD2F5); // --muted보다 더 옅은 3차 텍스트

  // ── 카드/테두리(--card / --line) ──
  static const surfaceCard = Color(0x14C8B4FF); // rgba(200,180,255,0.08)
  static const surfaceCardBorder = Color(0x26DCC8FF); // rgba(220,200,255,0.15)

  // 상태 색상(기존 유지 — crystal 팔레트와 어긋나지 않는 범위에서 톤만 보정)
  static const success = Color(0xFF8CD9B3);
  static const error = Color(0xFFE58A8A);

  /// README `stageBg`: crystal 팔레트의 배경은 단순 선형 그라디언트가 아니라
  /// 라벤더/아쿠아 방사형 글로우 2개 + 선형 베이스로 구성된다. 실제 방사형
  /// 글로우는 [WishRoomBackground]가 CustomPainter로 그리므로, 여기서는
  /// 그 밑에 깔리는 선형 베이스만 정의한다(README: linear-gradient(180deg,
  /// #26204a 0%, #1a1533 100%) 근사).
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundSoft, backgroundMid, backgroundDeep],
  );

  static const objectGlowGradient = RadialGradient(
    colors: [goldSoft, gold, Colors.transparent],
    stops: [0.0, 0.4, 1.0],
  );

  /// [소원 성장 시스템] 대표 소원의 [WishGrowthStage]에 대응하는 오브제 톤.
  /// crystal 팔레트에서는 붉은 불씨 대신 차가운 아쿠아 → 라벤더 글로우 →
  /// 눈부신 화이트 순으로 색온도가 올라가도록 재해석했다(정책표 ⑥ "성장
  /// 단계 정책"의 단계 구조는 그대로 유지, 색상만 crystal 톤으로 교체).
  static Color forGrowthStage(WishGrowthStage stage) {
    switch (stage) {
      case WishGrowthStage.ember:
        return const Color(0xFF7FA8D4); // 옅은 아쿠아 블루
      case WishGrowthStage.smallCandle:
        return const Color(0xFF9BBEE0); // 아쿠아 → 라벤더 전이
      case WishGrowthStage.steadyCandle:
        return const Color(0xFFE8C8F5); // = glow
      case WishGrowthStage.brightCandle:
        return const Color(0xFFEFD8FA);
      case WishGrowthStage.goldenFlame:
        return const Color(0xFFFAF0FF); // 거의 화이트에 가까운 크리스탈 광채
    }
  }

  /// 성장 단계별 오브제 그라디언트(단계가 오를수록 중심부가 더 밝고
  /// 넓게 퍼진다).
  static RadialGradient objectGradientForStage(WishGrowthStage stage) {
    final tone = forGrowthStage(stage);
    return RadialGradient(
      colors: [Colors.white, tone, Colors.transparent],
      stops: stage == WishGrowthStage.goldenFlame
          ? const [0.0, 0.55, 1.0]
          : const [0.0, 0.4, 1.0],
    );
  }
}

/// [디자인 핸드오프 적용] 판타지 신전 테마 타이포그래피.
///
/// README Typography 표에 따라 3개 폰트 패밀리를 역할별로 매핑한다:
/// - `NotoSerifKRWish`(900/700): 히어로/화면 타이틀, 한자 글리프(Seal/成)
/// - `GowunBatangWish`(700/400): 소원 본문, 버튼, 두루마리 텍스트
/// - `IBMPlexMonoWish`(400/500): eyebrow/meta 라벨(letter-spacing 큼)
/// - 나머지 일반 본문은 앱 전역 Pretendard를 그대로 상속(fontFamily 미지정).
///
/// 기존 titleXl/titleLg/bodyMd/bodySm/caption/dailyMessage/ctaLabel 이름과
/// 시맨틱은 그대로 유지하고 폰트/색만 교체해, 이 스타일들을 참조하는 기존
/// 위젯 코드를 전혀 건드리지 않고도 새 디자인이 적용되게 한다.
class WishRoomTextStyles {
  WishRoomTextStyles._();

  static const _serif = 'NotoSerifKRWish';
  static const _batang = 'GowunBatangWish';
  static const _mono = 'IBMPlexMonoWish';

  static const titleXl = TextStyle(
    fontFamily: _serif,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: WishRoomColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const titleLg = TextStyle(
    fontFamily: _serif,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
  );

  static const bodyMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
    height: 1.5,
  );

  static const bodySm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textTertiary,
  );

  static const dailyMessage = TextStyle(
    fontFamily: _batang,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: WishRoomColors.goldSoft,
    fontStyle: FontStyle.italic,
    height: 1.4,
  );

  static const ctaLabel = TextStyle(
    fontFamily: _batang,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.backgroundDeep,
  );

  // ── [디자인 핸드오프 신규 추가] README Typography 표 매핑 ──

  /// 히어로 타이틀(온보딩 등): Noto Serif KR 900 34px, letter-spacing -0.02em
  static const heroTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    color: WishRoomColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.15,
  );

  /// 화면 타이틀(Compose/Detail/Celebration 등): Noto Serif KR 900 24-26px
  static const screenTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: WishRoomColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// 섹션 타이틀(Home 등): Noto Serif KR 700 22px
  static const sectionTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.2,
  );

  /// 소원 본문(리스트 행): Gowun Batang 700 14px
  static const wishBodyList = TextStyle(
    fontFamily: _batang,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
    height: 1.4,
  );

  /// 소원 본문(상세): Noto Serif KR 700 20px
  static const wishBodyDetail = TextStyle(
    fontFamily: _serif,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: WishRoomColors.textPrimary,
    height: 1.5,
  );

  /// 소원 본문(두루마리/Compose 텍스트영역): Gowun Batang 400 17px
  static const wishBodyPaper = TextStyle(
    fontFamily: _batang,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: Color(0xFF3A2515),
    height: 1.8,
  );

  /// 버튼 라벨: Gowun Batang 700 15px
  static const buttonLabel = TextStyle(
    fontFamily: _batang,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );

  /// 필/태그 라벨: Gowun Batang 400 11px
  static const pillLabel = TextStyle(
    fontFamily: _batang,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.0,
  );

  /// eyebrow/meta 라벨: IBM Plex Mono 400-500 10-11px, letter-spacing 0.15~0.4em
  static const eyebrow = TextStyle(
    fontFamily: _mono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: WishRoomColors.textSecondary,
    letterSpacing: 2.0, // 0.2em @ 10px
  );

  static const eyebrowWide = TextStyle(
    fontFamily: _mono,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
    letterSpacing: 4.0, // 0.4em @ 10px
  );

  static const metaMono = TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: WishRoomColors.textSecondary,
    letterSpacing: 1.5,
  );
}

class WishRoomSpacing {
  WishRoomSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class WishRoomRadius {
  WishRoomRadius._();

  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const pill = 999.0;
}
