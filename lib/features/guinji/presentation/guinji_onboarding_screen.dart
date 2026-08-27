import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_provider.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import 'guinji_loading_screen.dart';

/// 귀인지도(Guinji Map) — 02. 온보딩 화면.
///
/// [Phase G-1: 귀인지도 라우트 스캐폴딩] `design_handoff_home_redesign
/// (3).zip` → `GUINJI_SCREENS.md` "02 · 온보딩" 스펙을 재구현한다(원본은
/// `guinji_prototype/GuinjiScreens.jsx`의 `OnboardingScreen`).
///
/// 목적: 처음 진입 시 신통도령 인사 + 기존 사주 프로필 확인 → "지도 만들기"
/// CTA. 이 Phase에서는 목데이터/뼈대만 구현하며, 실제 지도 생성 API 호출·
/// DB 저장(신규 테이블 5개, §5)은 하지 않는다 — CTA는 준비 중 안내만 띄운다
/// (홈 배너 `_handleTap`과 동일한 관례).
///
/// [절대 원칙] 이 화면은 결제·재화 지급을 전혀 다루지 않는다. 프로필 표시는
/// 기존 [AuthProvider.currentUser](UserModel)를 그대로 읽기만 하며 새 필드를
/// 추가하지 않는다.
class GuinjiOnboardingScreen extends StatelessWidget {
  const GuinjiOnboardingScreen({super.key});

  /// 표준 십이지시 매핑(자시 23:00~00:59 ~ 해시 21:00~22:59). 기존
  /// [ManseryeokPolicy]의 야자시/조자시 세분 정책과는 무관한, 이 화면
  /// "프로필 확인 카드"의 단순 표시용 보조 함수다(계산 엔진에 영향 없음).
  static const List<String> _jijiHanja = [
    '子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥', //
  ];

  String _hourToJijiLabel(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return '';
    final hour = int.tryParse(parts[0]);
    if (hour == null) return '';
    // 23:00~00:59 → 子(0), 01:00~02:59 → 丑(1), ...
    final index = ((hour + 1) ~/ 2) % 12;
    return _jijiHanja[index];
  }

  String _formatBirthTime(String? birthTime, bool unknown) {
    if (unknown || birthTime == null || birthTime.isEmpty) {
      return '시간 정보 없음';
    }
    final jiji = _hourToJijiLabel(birthTime);
    return jiji.isEmpty ? birthTime : '$birthTime ($jiji時)';
  }

  String _formatBirthDate(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return '정보 없음';
    final parts = birthDate.split('-');
    if (parts.length != 3) return birthDate;
    return '${parts[0]} · ${parts[1]} · ${parts[2]}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final nickname = user?.nickname ?? '손님';
    final calendarLabel = (user?.isLunar ?? false) ? '음력' : '양력';
    final birthDateLabel = _formatBirthDate(user?.birthDate);
    final birthTimeLabel = _formatBirthTime(
      user?.birthTime,
      user?.birthTimeUnknown ?? true,
    );

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          _DoryeongGreeting(nickname: nickname),
                          const SizedBox(height: 24),
                          _ProfileCard(
                            nickname: nickname,
                            calendarLabel: calendarLabel,
                            birthDateLabel: birthDateLabel,
                            birthTimeLabel: birthTimeLabel,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  _PrimaryCta(
                    onPressed: () async {
                      // [귀인지도 실구현] 사주 계산 + POST /guinji/maps 호출을
                      // 로딩 화면(S3)에서 수행한다. 여기서는 사용자 프로필이
                      // 없으면(생년월일 미입력) 즉시 안내만 하고, 있으면
                      // 로딩 화면으로 넘겨 실제 API 호출을 진행한다.
                      final currentUser = auth.currentUser;
                      if (currentUser == null || currentUser.birthDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('생년월일 정보가 없어 지도를 만들 수 없습니다. 프로필을 먼저 완성해 주세요.'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              GuinjiLoadingScreen(user: currentUser),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const _DisclaimerText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconButton(icon: Icons.arrow_back, onPressed: onBack),
        const SizedBox(width: 10),
        const _MonoLabel('ONBOARDING · 01'),
      ],
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
  const _MonoLabel(this.text, {this.fontSize = 10});

  final String text;
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
        color: GuinjiColors.textSecondary,
      ),
    );
  }
}

/// 신통도령 인사 일러스트 + 말풍선.
///
/// [Phase G-1 범위] 원본 스펙(`gentle-bob 3.2s` float 애니메이션)은 홈
/// 캐러셀에 이미 구현된 `b-doryeong-float` 패턴과 동일하므로, 이 Phase에서는
/// 정적 이미지로 우선 배치하고 애니메이션은 화면 확정 후 추가한다(과도한
/// 선행 구현으로 인한 재작업 방지 — README "한 Phase씩" 원칙).
class _DoryeongGreeting extends StatelessWidget {
  const _DoryeongGreeting({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/home/doryeong/greeting.png',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: GuinjiColors.surfaceCard,
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '안녕하세요, 소인 '),
                    const TextSpan(
                      text: '신통도령',
                      style: TextStyle(color: GuinjiColors.lavender),
                    ),
                    const TextSpan(text: '이라 하옵니다.'),
                  ],
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontSize: 13,
                    height: 1.5,
                    color: GuinjiColors.textPrimary,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              const Text(
                '당신의 사주로 귀인지도를 열어드릴게요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: GuinjiFonts.body,
                  fontSize: 12,
                  height: 1.5,
                  color: GuinjiColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.nickname,
    required this.calendarLabel,
    required this.birthDateLabel,
    required this.birthTimeLabel,
  });

  final String nickname;
  final String calendarLabel;
  final String birthDateLabel;
  final String birthTimeLabel;

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['이름', nickname],
      ['양/음력', calendarLabel],
      ['생년월일', birthDateLabel],
      ['태어난 시간', birthTimeLabel],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: _MonoLabel('MY PROFILE · 확인'),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GuinjiColors.surfaceCard,
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == rows.length - 1 ? 0 : 10,
                  ),
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: i == rows.length - 1 ? 0 : 8,
                    ),
                    decoration: i == rows.length - 1
                        ? null
                        : const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: GuinjiColors.surfaceCardBorder,
                                width: 1,
                              ),
                            ),
                          ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _MonoLabel(rows[i][0], fontSize: 9),
                        Text(
                          rows[i][1],
                          style: const TextStyle(
                            fontFamily: GuinjiFonts.body,
                            fontSize: 13,
                            color: GuinjiColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: GuinjiColors.surfaceCardBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      '기존 신통방통 프로필을 그대로 씁니다.\n수정하려면 여기를 톡톡.',
                      style: TextStyle(
                        fontFamily: GuinjiFonts.ui,
                        fontSize: 11,
                        height: 1.5,
                        color: GuinjiColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: GuinjiColors.lavender,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: GuinjiColors.glowShadow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '✧ ',
                  style: TextStyle(fontSize: 15, color: GuinjiColors.ink),
                ),
                Text(
                  '지도 만들기',
                  style: TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: GuinjiColors.ink,
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

class _DisclaimerText extends StatelessWidget {
  const _DisclaimerText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '"재미·참고용" 콘텐츠예요. 절대적 판단이 아닙니다.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: GuinjiFonts.ui,
        fontSize: 10,
        color: GuinjiColors.textSecondary,
      ),
    );
  }
}
