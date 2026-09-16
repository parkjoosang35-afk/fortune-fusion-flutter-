/// ═══════════════════════════════════════════════════════════════
/// 방통선녀(Bangtong Seonyeo) · 신통방통 공식 마스코트 자산/위젯
/// ═══════════════════════════════════════════════════════════════
///
/// [신통도령 대체 - 2026-09] 사용자 지시로 기존 마스코트 "신통도령"을
/// 전면 삭제한 후, 신규 캐릭터 "방통선녀"(디자인팀 핸드오프 원문 표기는
/// "반통선녀"이나, 기존 앱 곳곳에 이미 "방통선녀"라는 이름으로 얼굴
/// 아바타 1장이 쓰이고 있어 명칭을 통일했다 — 두음 표기 차이일 뿐 동일
/// 캐릭터) 이미지 11장으로 대체 배치한다.
///
/// 캐릭터 이미지 경로/무드 enum을 한 곳에서 관리하고, 자주 쓰이는
/// 4가지 재사용 위젯(Hero/FaceAvatar/PoseFrame/Badge)을 제공한다.
/// 화면에서 하드코딩된 경로 대신 이 상수/위젯을 사용할 것.
library;

import 'package:flutter/material.dart';

class BangtongSeonyeoAssets {
  BangtongSeonyeoAssets._();

  static const String _base = 'assets/images/character';

  /// 대표 전신 · 3:4 — 온보딩, 히어로 배너, 히어로 카드
  static const String mainFullBody = '$_base/main-fullbody.png';

  /// 상반신 · 3:4 — 상세 화면 헤더, 모달 히어로, 카드 커버
  static const String mainHalfBody = '$_base/main-halfbody.png';

  /// 얼굴 아이콘 · 1:1 — 앱 아이콘, 프로필, 아바타, 채팅 헤드, 공유 카드
  static const String faceIcon = '$_base/face-icon.png';

  /// 표정 · 고요(눈 감음, 명상) — 명상 모드, 로딩 화면, 오늘의 조언
  static const String exprSerene = '$_base/expr-01-serene.png';

  /// 표정 · 미소(따뜻하고 안심) — 홈 인사, 기본 프로필, 축하 시작
  static const String exprSmile = '$_base/expr-02-smile.png';

  /// 표정 · 장난기(한쪽 입꼬리) — 오늘의 운세, 힌트 알림
  static const String exprPlayful = '$_base/expr-03-playful.png';

  /// 표정 · 염려(눈썹 사려깊게) — 위로 알림, 조심 관계, 에러 안내
  static const String exprConcerned = '$_base/expr-04-concerned.png';

  /// 표정 · 경이(놀람, 감탄) — 축하, 발견, 서프라이즈
  static const String exprWonder = '$_base/expr-05-wonder.png';

  /// 포즈 · 빌기(두 손 모아 기도) — 완료/축하 결말
  static const String posePraying = '$_base/pose-praying.png';

  /// 포즈 · 부적 쓰기(붓 + 한자 인장) — 사주/부적 발급
  static const String poseWritingTalisman = '$_base/pose-writing-talisman.png';

  /// 포즈 · 촛불 집기(제단 앞) — empty state, 안내, 축하
  static const String poseLightingCandle = '$_base/pose-lighting-candle.png';

  static const List<String> all = [
    mainFullBody, mainHalfBody, faceIcon,
    exprSerene, exprSmile, exprPlayful, exprConcerned, exprWonder,
    posePraying, poseWritingTalisman, poseLightingCandle,
  ];
}

/// 캐릭터 이미지의 시맨틱 종류.
enum BangtongMood {
  /// 기본 · 지그시 미소 · 홈, 프로필
  smile,

  /// 고요 · 눈 감음 · 명상, 로딩
  serene,

  /// 장난기 · 유머 · 오늘의 운세, 힌트
  playful,

  /// 염려 · 사려 깊음 · 위로, 조심
  concerned,

  /// 경이 · 감탄 · 축하, 발견
  wonder,
}

extension BangtongMoodAsset on BangtongMood {
  String get asset {
    switch (this) {
      case BangtongMood.smile:
        return BangtongSeonyeoAssets.exprSmile;
      case BangtongMood.serene:
        return BangtongSeonyeoAssets.exprSerene;
      case BangtongMood.playful:
        return BangtongSeonyeoAssets.exprPlayful;
      case BangtongMood.concerned:
        return BangtongSeonyeoAssets.exprConcerned;
      case BangtongMood.wonder:
        return BangtongSeonyeoAssets.exprWonder;
    }
  }
}

/// 히어로 위젯 · 큰 이미지 + 선택적 하단 페이드아웃.
///
/// 사용 예:
/// ```dart
/// BangtongHero(asset: BangtongSeonyeoAssets.mainFullBody, height: 200)
/// ```
class BangtongHero extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color fadeColor;
  final bool bottomFade;

  const BangtongHero({
    super.key,
    this.asset = BangtongSeonyeoAssets.mainFullBody,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fadeColor = Colors.transparent,
    this.bottomFade = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: fit),
          if (bottomFade)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: (height ?? 200) * 0.3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, fadeColor],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 원형 얼굴 아바타.
///
/// 사용 예:
/// ```dart
/// BangtongFaceAvatar(size: 48)
/// BangtongFaceAvatar(size: 96, glow: true)
/// BangtongFaceAvatar(size: 64, mood: BangtongMood.playful)
/// ```
class BangtongFaceAvatar extends StatelessWidget {
  final double size;
  final BangtongMood? mood;
  final bool glow;
  final Color glowColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const BangtongFaceAvatar({
    super.key,
    this.size = 48,
    this.mood,
    this.glow = false,
    this.glowColor = const Color(0xFFE8B4A5),
    this.borderColor = const Color(0xFFF0D8C8),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = mood != null ? mood!.asset : BangtongSeonyeoAssets.faceIcon;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: '방통선녀',
        child: Image.asset(image, fit: BoxFit.cover),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: avatar,
      );
    }
    return avatar;
  }
}

/// [배치 수정 - 인트로 히어로] 화면 상단을 가득 채우는 큰 배너형 캐릭터
/// 이미지. 기존에 작은 원형 얼굴(76~96px)만 텍스트 위에 얹었던 것을
/// "증명사진처럼 작다"는 피드백에 따라, 여백이 넉넉한 인트로 화면에는
/// 전신/반신/포즈 원본 이미지(896x1200)를 화면 폭 전체로 크게 보여주고
/// 하단을 배경색으로 자연스럽게 페이드아웃시켜 텍스트와 이어붙인다.
class BangtongIntroHero extends StatelessWidget {
  final String asset;
  final double height;
  final Color fadeColor;
  final Alignment alignment;
  final BorderRadius borderRadius;

  const BangtongIntroHero({
    super.key,
    required this.asset,
    required this.height,
    required this.fadeColor,
    this.alignment = Alignment.topCenter,
    this.borderRadius = const BorderRadius.only(
      bottomLeft: Radius.circular(32),
      bottomRight: Radius.circular(32),
    ),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: '방통선녀',
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: alignment,
              ),
            ),
            // 이미지 하단을 화면 배경색으로 부드럽게 녹여, 사진을 잘라 붙인
            // 듯한 경계선 없이 텍스트 영역과 자연스럽게 이어지도록 한다.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      fadeColor.withValues(alpha: 0),
                      fadeColor.withValues(alpha: 0.55),
                      fadeColor,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 포즈 프레임 · 세로 카드 안 포즈 이미지(사주·부적·기도 문맥).
class BangtongPoseFrame extends StatelessWidget {
  final String asset;
  final double? width;
  final double aspectRatio;
  final BorderRadius borderRadius;

  const BangtongPoseFrame({
    super.key,
    required this.asset,
    this.width,
    this.aspectRatio = 3 / 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
