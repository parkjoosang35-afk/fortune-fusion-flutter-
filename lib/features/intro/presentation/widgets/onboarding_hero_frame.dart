import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../intro_palette.dart';
import '../intro_text_styles.dart';
import 'onboarding_sigil.dart';

/// 공용 진행률 계산 — [SplashScreen]의 `_progress` 헬퍼와 동일한 패턴.
double _progress(double elapsed, double start, double duration) {
  if (duration <= 0) return elapsed >= start ? 1.0 : 0.0;
  return ((elapsed - start) / duration).clamp(0.0, 1.0);
}

/// [온보딩 v2 리디자인 2026-10-18] `온보딩 v2.html` `.hero`/`.arch-outer`
/// 블록 — 2겹 마법진(Sigil A/B) + 아치형 프레임(문살 눈금·keystone·
/// moonwash·緣 인장) 조합. README §4(Arch 프레임)/§3(마법진)/§5(인장) 수치를
/// 그대로 이식한다.
///
/// [v1→v2 레이아웃 변경] v1은 히어로 자체가 상대 비율(`aspect-ratio
/// 280/410`)로 늘어나는 카드형이었지만, v2는 390×844 레퍼런스 기준 **고정
/// 픽셀 수치**(Hero 컨테이너 h470, Arch outer 252×372)로 배치가 바뀌었다.
/// 작은 화면에서도 비율이 깨지지 않도록, 이 위젯은 390pt 기준 비율을
/// 유지한 채 [FittedBox]로 축소하는 방식을 쓴다(호출부가 전달하는 실제
/// 폭에 맞춰 전체 Hero 블록을 스케일).
///
/// 레이어 순서(바깥→안):
/// 1. sigil-wrap A — 420×420, top 4, 200s 시계방향, opacity .38
/// 2. sigil-wrap B — 280×280, top 74, 140s 반시계방향, opacity .16
/// 3. arch-outer — 문살 눈금(좌우 17개) + keystone(✦) + 안쪽 테두리
/// 4. arch(window) — 이미지(reveal) + 하단 비네팅 + moonwash
/// 5. seal — "緣/INYEON" 인주색 인장, outer 기준 right −14 top 206
///
/// 등장 애니메이션은 [elapsedSeconds](호출부의 진입 시퀀스 컨트롤러가
/// 흘려주는 경과 시간)로 제어한다. 앰비언트(Sigil 회전)는 이 위젯이 자체
/// 컨트롤러로 무한 반복한다.
class OnboardingHeroFrame extends StatelessWidget {
  const OnboardingHeroFrame({
    super.key,
    required this.heroAsset,
    required this.elapsedSeconds,
    this.reduceMotion = false,
  });

  /// 일러스트 에셋 경로(기존 앱 원본 — `hero-fullbody.png`, 683×1024로
  /// README 권장 고해상도 조건을 이미 충족한다).
  final String heroAsset;

  /// 진입 시퀀스 시작부터 경과한 시간(초).
  final double elapsedSeconds;

  final bool reduceMotion;

  /// 390×844 레퍼런스 기준 Hero 컨테이너 전체 높이(README 레이아웃 표).
  static const double _refHeroHeight = 470;
  static const double _refArchWidth = 252;
  static const double _refArchHeight = 372;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // 390pt 레퍼런스 대비 실제 폭 비율 — Hero 전체(마법진 포함)를
        // 동일 비율로 축소해 좌우 잘림 없이 390pt 디자인을 재현한다.
        const refDeviceWidth = 390.0;
        final scale = (availableWidth / refDeviceWidth).clamp(0.5, 1.2);
        final heroHeight = _refHeroHeight * scale;

        return SizedBox(
          width: availableWidth,
          height: heroHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // 1~2. Sigil A/B — fade(메타행과 동일 타이밍, 0~2.4s).
              _buildSigilLayer(scale),
              // 3~5. Arch outer(눈금+keystone) + window(이미지) + 인장.
              Positioned(
                top: 12 * scale,
                child: _ArchOuter(
                  asset: heroAsset,
                  width: _refArchWidth * scale,
                  height: _refArchHeight * scale,
                  scale: scale,
                  elapsedSeconds: elapsedSeconds,
                  reduceMotion: reduceMotion,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSigilLayer(double scale) {
    // README §1 "Meta, Sigil 2겹 | fade 0→1 | 2.4s ease-out, 0s".
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 2400),
      curve: Curves.easeOut,
      child: SizedBox(
        width: 420 * scale,
        height: 420 * scale,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Sigil A — top 4, 420×420, 200s 시계방향, opacity .38.
            Positioned(
              top: 4 * scale,
              child: SizedBox(
                width: 420 * scale,
                height: 420 * scale,
                child: OnboardingSigil(
                  color: IntroPalette.primary,
                  opacity: 0.38,
                  periodSeconds: 200,
                  reduceMotion: reduceMotion,
                ),
              ),
            ),
            // Sigil B — top 74, 280×280, 140s 반시계방향, opacity .16.
            Positioned(
              top: 74 * scale,
              child: SizedBox(
                width: 280 * scale,
                height: 280 * scale,
                child: OnboardingSigil(
                  color: IntroPalette.textPrimary,
                  opacity: 0.16,
                  periodSeconds: 140,
                  reverse: true,
                  reduceMotion: reduceMotion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arch outer — 문살 눈금(좌우) + keystone(✦) + 2중 테두리 + 내부 window.
class _ArchOuter extends StatefulWidget {
  const _ArchOuter({
    required this.asset,
    required this.width,
    required this.height,
    required this.scale,
    required this.elapsedSeconds,
    required this.reduceMotion,
  });

  final String asset;
  final double width;
  final double height;
  final double scale;
  final double elapsedSeconds;
  final bool reduceMotion;

  @override
  State<_ArchOuter> createState() => _ArchOuterState();
}

class _ArchOuterState extends State<_ArchOuter> {
  // README "Outer: 252×372, border-radius 126 126 6 6".
  BorderRadius _radius(double factor) => BorderRadius.only(
    topLeft: Radius.circular(126 * factor),
    topRight: Radius.circular(126 * factor),
    bottomLeft: Radius.circular(6 * factor),
    bottomRight: Radius.circular(6 * factor),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    // "Arch frame | blur 8px→0, scale .97→1, opacity 0→1 | 1.8s
    // cubic-bezier(.22,1,.36,1), 0s" — README 등장 모션 표.
    final archP = _progress(widget.elapsedSeconds, 0.0, 1.8);
    final archEased = Curves.easeOutCubic.transform(archP);

    Widget outer = Container(
      width: widget.width,
      height: widget.height,
      padding: EdgeInsets.all(9 * s),
      decoration: BoxDecoration(
        borderRadius: _radius(s),
        border: Border.all(color: IntroPalette.cardBorder, width: 1),
      ),
      child: DecoratedBox(
        // Inner line — outer 안쪽 4px inset, border rgba(232,200,245,.28).
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(122 * s),
            topRight: Radius.circular(122 * s),
            bottomLeft: Radius.circular(4 * s),
            bottomRight: Radius.circular(4 * s),
          ),
          border: Border.all(
            color: IntroPalette.primary.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: _ArchWindow(
          asset: widget.asset,
          scale: s,
          elapsedSeconds: widget.elapsedSeconds,
          reduceMotion: widget.reduceMotion,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: widget.reduceMotion ? 1.0 : archEased,
          child: Transform.scale(
            scale: widget.reduceMotion ? 1.0 : 0.97 + 0.03 * archEased,
            child: outer,
          ),
        ),
        // Keystone — 아치 꼭대기 중앙(top −7), 12×12, bg #2c2449, ✦ 11px.
        Positioned(
          top: -7 * s,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 12 * s,
              height: 12 * s,
              alignment: Alignment.center,
              color: IntroPalette.backgroundMid,
              child: Text(
                '✦',
                style: TextStyle(
                  fontSize: 11 * s,
                  color: IntroPalette.primary,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        // 문살 눈금 — 좌우 바깥 18px, top140~bottom16, 17개.
        Positioned(
          left: -18 * s,
          top: 140 * s,
          bottom: 16 * s,
          child: _TickColumn(count: 17, scale: s, alignEnd: false),
        ),
        Positioned(
          right: -18 * s,
          top: 140 * s,
          bottom: 16 * s,
          child: _TickColumn(count: 17, scale: s, alignEnd: true),
        ),
        // 緣 인장 — outer 기준 right −14, top 206.
        Positioned(
          right: -14 * s,
          top: 206 * s,
          child: _Seal(
            scale: s,
            progress: _progress(widget.elapsedSeconds, 1.6, 1.4),
          ),
        ),
      ],
    );
  }
}

/// 문살 눈금 17개 세로 배치 — 4번째마다(1,5,9,13,17번째) 굵게/밝게.
class _TickColumn extends StatelessWidget {
  const _TickColumn({
    required this.count,
    required this.scale,
    required this.alignEnd,
  });

  final int count;
  final double scale;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: List.generate(count, (i) {
        final isBold = i % 4 == 0; // 1,5,9,13,17번째(0-index 0,4,8,12,16).
        return Container(
          height: 1,
          width: (isBold ? 10 : 6) * scale,
          color: isBold
              ? IntroPalette.primary.withValues(alpha: 0.4)
              : IntroPalette.cardBorder,
        );
      }),
    );
  }
}

/// Arch window — 캐릭터 이미지(reveal 등장) + 하단 비네팅 + moonwash.
class _ArchWindow extends StatelessWidget {
  const _ArchWindow({
    required this.asset,
    required this.scale,
    required this.elapsedSeconds,
    required this.reduceMotion,
  });

  final String asset;
  final double scale;
  final double elapsedSeconds;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    // README "캐릭터 이미지 | scale 1.06→1, opacity 0→1 | 2.4s ease-out, 0.5s".
    final p = _progress(elapsedSeconds, 0.5, 2.4);
    final eased = Curves.easeOut.transform(p);

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(117 * scale),
        topRight: Radius.circular(117 * scale),
        bottomLeft: Radius.circular(2 * scale),
        bottomRight: Radius.circular(2 * scale),
      ),
      child: Container(
        color: IntroPalette.archWindowBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: reduceMotion ? 1.0 : eased,
              child: Transform.scale(
                scale: reduceMotion ? 1.0 : 1.06 - 0.06 * eased,
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(
                    0,
                    -0.64,
                  ), // object-position 50% 18%.
                ),
              ),
            ),
            // 하단 비네팅 — 32% 높이, transparent→archWindowBg.
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.32,
                widthFactor: 1.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        IntroPalette.archWindowBg.withValues(alpha: 0),
                        IntroPalette.archWindowBg,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // moonwash — 달빛 상단 하이라이트(screen blend 근사: 옅은 흰빛
            // radial을 얹어 밝아지는 느낌만 재현. Flutter에는 screen
            // blend-mode용 간단 API가 없어 저알파 덧칠로 근사한다).
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.0),
                    radius: 1.1,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
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

/// 緣 인장(INYEON) — 인주색(seal red) 세로형 배지. README §5.
/// A2 등장: "緣 인장, Actions | translateY 14→0 + fade | 1.4s, 1.6s".
class _Seal extends StatelessWidget {
  const _Seal({required this.scale, required this.progress});

  final double scale;

  /// 0~1. 0=아직 등장 전(투명), 1=등장 완료.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(p);

    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - eased)),
        child: Transform.rotate(
          angle: 4 * 3.1415926535 / 180,
          child: Container(
            width: 30 * scale,
            padding: EdgeInsets.fromLTRB(0, 8 * scale, 0, 7 * scale),
            decoration: BoxDecoration(
              color: IntroPalette.sealRed,
              borderRadius: BorderRadius.circular(6 * scale),
              boxShadow: [
                BoxShadow(
                  color: IntroPalette.sealRed.withValues(alpha: 0.5),
                  blurRadius: 12 * scale,
                  offset: Offset(0, 2 * scale),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '緣',
                  style: GoogleFonts.nanumMyeongjo(
                    fontWeight: FontWeight.w800, // 핸드오프 900 근사.
                    fontSize: 17 * scale,
                    color: IntroPalette.sealInk,
                    height: 1,
                  ),
                ),
                SizedBox(height: 5 * scale),
                Opacity(
                  opacity: 0.85,
                  child: RotatedBox(
                    quarterTurns: 1, // writing-mode: vertical-rl 근사.
                    child: Text(
                      'INYEON',
                      style: IntroTextStyles.eyebrow(
                        color: IntroPalette.sealInk,
                      ).copyWith(fontSize: 6.5 * scale, letterSpacing: 1.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
