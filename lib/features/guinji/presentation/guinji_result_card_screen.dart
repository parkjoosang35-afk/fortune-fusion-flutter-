import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../../wish_room/widgets/wish_room_sigil.dart';
import '../domain/guinji_person.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';

/// 귀인지도(Guinji Map) — 10. 결과 카드(Result Card) 화면.
///
/// [Phase G-8] `GUINJI_SCREENS.md` "10 · 결과 카드" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `ResultCardScreen`): 카톡·인스타에 공유할 세로
/// 3:4 스크린샷 카드. 랭킹(S7)의 "결과 카드로 공유하기" CTA에서 진입한다.
///
/// [비식별 원칙] 원본 스펙 그대로 카드에는 이름을 노출하지 않고 관계
/// 유형별 인원수(귀인/오른팔/호랑이 선생)만 표시한다.
///
/// [Phase G-8 범위 — 절대 원칙 준수] "이미지 저장"·"공유하기" 버튼은
/// 실제 스크린샷 캡처(RepaintBoundary→PNG)·네이티브 공유 시트 연동이
/// 필요한 영역이라, 이 Phase에서는 UI만 완성하고 토스트로 대체한다.
/// 어떤 재화 지급도 이 화면에서는 발생하지 않는다.
class GuinjiResultCardScreen extends StatelessWidget {
  const GuinjiResultCardScreen({super.key, this.people = guinjiSamplePeople});

  final List<GuinjiPerson> people;

  @override
  Widget build(BuildContext context) {
    final guin = people.where((p) => p.relation == 'guin').length;
    final oreunpal = people.where((p) => p.relation == 'oreunpal').length;
    final horang = people.where((p) => p.relation == 'horang').length;

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const _MonoLabel('RESULT · SHARE CARD'),
                      _IconButton(
                        icon: Icons.more_horiz,
                        onPressed: () =>
                            AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: _TheCard(
                        guin: guin,
                        oreunpal: oreunpal,
                        horang: horang,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _GhostButton(
                          label: '이미지 저장',
                          onPressed: () =>
                              AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PrimaryButton(
                          label: '공유하기',
                          onPressed: () =>
                              AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: GuinjiColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text, {this.color, this.fontSize = 10});

  final String text;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: fontSize,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
        color: color ?? GuinjiColors.textSecondary,
      ),
    );
  }
}

/// 카드 본체 — 240×320(3:4), 회전 마법진 배경 + 신통도령 + 통계 + 인용구.
class _TheCard extends StatelessWidget {
  const _TheCard({
    required this.guin,
    required this.oreunpal,
    required this.horang,
  });

  final int guin;
  final int oreunpal;
  final int horang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 320,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GuinjiColors.lavender.withValues(alpha: 0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 60,
            offset: Offset(0, 20),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(GuinjiColors.backgroundSoft, GuinjiColors.aqua, 0.1)!,
            GuinjiColors.backgroundDeep,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.0),
                  radius: 0.9,
                  colors: [
                    GuinjiColors.lavender.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),
          // 회전 마법진 — WishRoomSigilRing 재사용(opacity 0.5 근사).
          const Positioned(
            top: 78,
            left: 20,
            child: WishRoomSigilRing(
              size: 200,
              color: GuinjiColors.lavender,
              opacity: 0.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _MonoLabel(
                      'SINTONG · GUINJI',
                      color: GuinjiColors.lavender,
                      fontSize: 7,
                    ),
                    _MonoLabel('N°01', fontSize: 7),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Image.asset(
                    'assets/images/home/doryeong/celebrating.png',
                    width: 68,
                    height: 68,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '지민의 지도에는',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontSize: 10,
                    color: GuinjiColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '귀인 $guin명',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: -0.6,
                    color: GuinjiColors.lavender,
                    shadows: [
                      Shadow(color: GuinjiColors.glowShadow, blurRadius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '오른팔 $oreunpal · 호랑이 선생 $horang',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontSize: 10,
                    color: GuinjiColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: GuinjiColors.surfaceCardBorder),
                      bottom: BorderSide(color: GuinjiColors.surfaceCardBorder),
                    ),
                  ),
                  child: const Text(
                    '"간절히 원하면,\n온 우주가 도와준다"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontStyle: FontStyle.italic,
                      fontSize: 10,
                      height: 1.4,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: _MonoLabel('SINTONG BANGTONG · 신통방통', fontSize: 7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: GuinjiColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.lavender,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: GuinjiColors.glowShadow, blurRadius: 16),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: GuinjiColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
