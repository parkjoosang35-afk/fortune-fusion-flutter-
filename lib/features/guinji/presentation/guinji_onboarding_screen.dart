import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_navigator_key.dart';
import '../../auth/application/auth_provider.dart';
import '../domain/pending_guinji_join.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import 'guinji_loading_screen.dart';

/// [버그 수정 — 온보딩 비로그인/프로필 미완성 진입] 로그인 완료 후(또는
/// 프로필 완성 후) 저장된 "귀인지도 지도 만들기 재시도" 요청이 있으면,
/// 원래 열려던 온보딩 화면([GuinjiOnboardingScreen])으로 자동 복귀시킨다.
/// `guinji_join_screen.dart`의 [replayPendingGuinjiJoin]과 동일한 타이밍
/// 전략을 따르되, 지인 참여(토큰 필요)가 아닌 본인 온보딩(토큰 불필요)
/// 재진입이라는 점만 다르다.
void replayPendingGuinjiOnboarding() {
  final pending = PendingGuinjiOnboardingStore.consume();
  if (!pending) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navState = appNavigatorKey.currentState;
    if (navState == null) return;
    navState.push(
      MaterialPageRoute(builder: (_) => const GuinjiOnboardingScreen()),
    );
  });
}

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
///
/// [버그 수정 — 비로그인/프로필 미완성 진입] 원래 이 화면은 로그인 여부를
/// 전혀 확인하지 않고 항상 프로필 카드를 "손님"으로 보여주기만 했다(실사용자
/// 리포트: 로그인 안 된 상태에서 들어가도 그냥 진입되고, 생년월일이 없어
/// "지도 만들기"를 눌러도 스낵바 안내만 뜨고 끝 — 회원가입/로그인으로
/// 안내하지 않음). `guinji_join_screen.dart`(지인 참여 화면)에는 이미
/// `_needsLogin` 분기(로그인 유도 카드)가 있었는데 이 화면에만 빠져 있던
/// 불일치였다. 이제 StatefulWidget으로 전환해 같은 패턴을 적용한다:
/// 비로그인이면 로그인 유도 카드를, 로그인했지만 생년월일이 없으면 프로필
/// 완성 유도 카드를 보여주고, 두 경우 모두 완료 후 이 화면으로 자동 복귀한다.
class GuinjiOnboardingScreen extends StatefulWidget {
  const GuinjiOnboardingScreen({super.key});

  @override
  State<GuinjiOnboardingScreen> createState() =>
      _GuinjiOnboardingScreenState();
}

class _GuinjiOnboardingScreenState extends State<GuinjiOnboardingScreen> {
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

  /// [버그 수정] 로그인 화면으로 이동하기 전, 이 온보딩 화면으로 자동
  /// 복귀할 수 있도록 플래그를 저장한다(`guinji_join_screen.dart`의
  /// `_goToLogin()`과 동일한 전략).
  void _goToLogin() {
    PendingGuinjiOnboardingStore.save();
    Navigator.of(context).pushNamed('/login');
  }

  /// [버그 수정] 생년월일이 없는 로그인 사용자를 프로필 완성 화면으로
  /// 보낸다. 완성 후 이 온보딩 화면으로 자동 복귀한다.
  void _goToProfileCheck() {
    PendingGuinjiOnboardingStore.save();
    Navigator.of(context).pushNamed('/signup/profile-check');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    // [버그 수정 — 비로그인/프로필 미완성 진입] 원래 이 화면은 로그인 여부와
    // 무관하게 항상 "손님" 프로필 카드를 보여주기만 했다. 이제
    // guinji_join_screen.dart와 동일한 2단계 게이트를 적용한다:
    // 1) 비로그인 → 로그인 유도 카드 (로그인 후 이 화면으로 자동 복귀)
    // 2) 로그인했지만 생년월일 없음 → 프로필 완성 유도 카드 (완성 후 자동 복귀)
    final needsLogin = !auth.isLoggedIn;
    final needsProfile = !needsLogin && user?.birthDate == null;

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
                  if (needsLogin)
                    Expanded(
                      child: _GateCard(
                        title: '로그인하고\n귀인지도를 열어봐요',
                        message: '지도를 만들려면 로그인이 필요해요.\n로그인 후 이 화면으로 자동으로 돌아와요.',
                        ctaLabel: '로그인 / 회원가입',
                        onPressed: _goToLogin,
                      ),
                    )
                  else if (needsProfile)
                    Expanded(
                      child: _GateCard(
                        title: '생년월일을 알려주면\n귀인지도를 열어드려요',
                        message: '지도를 만들려면 생년월일이 필요해요.\n입력 후 이 화면으로 자동으로 돌아와요.',
                        ctaLabel: '프로필 완성하기',
                        onPressed: _goToProfileCheck,
                      ),
                    )
                  else
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
                  if (!needsLogin && !needsProfile) ...[
                    _PrimaryCta(
                      onPressed: () {
                        // [귀인지도 실구현] 이 시점에는 이미 로그인 + 생년월일
                        // 보유가 보장되므로(위 게이트에서 걸러짐), 실제 사주
                        // 계산 + POST /guinji/maps 호출을 로딩 화면(S3)에서
                        // 곧바로 진행한다.
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GuinjiLoadingScreen(user: user!),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const _DisclaimerText(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [버그 수정 — 비로그인/프로필 미완성 진입 공통 게이트 카드] 로그인 또는
/// 생년월일 프로필이 필요할 때 보여주는 안내 카드.
/// `guinji_join_screen.dart`의 `_LoginRequiredCard`와 동일한 톤·구조를
/// 그대로 재사용하되, 문구(title/message/ctaLabel)와 콜백만 매개변수로 받아
/// 두 가지 게이트(로그인 필요/프로필 필요) 모두에 재사용할 수 있게 한다.
class _GateCard extends StatelessWidget {
  const _GateCard({
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/home/doryeong/greeting.png',
              width: 96,
              height: 96,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: GuinjiColors.surfaceCard,
                border: Border.all(color: GuinjiColors.surfaceCardBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontSize: 12,
                      height: 1.5,
                      color: GuinjiColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryCta(label: ctaLabel, onPressed: onPressed),
                ],
              ),
            ),
          ],
        ),
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
  // [버그 수정 — 게이트 카드 재사용] 기존에는 "지도 만들기" 라벨이 하드코딩
  // 되어 있었으나, 이제 로그인/프로필 완성 유도 CTA에도 이 위젯을 재사용하기
  // 위해 라벨을 매개변수로 받는다. 기본값을 기존 문구로 유지해 호출부를
  // 바꾸지 않아도 되는 회귀 없는 확장이다.
  const _PrimaryCta({required this.onPressed, this.label = '지도 만들기'});

  final VoidCallback onPressed;
  final String label;

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '✧ ',
                  style: TextStyle(fontSize: 15, color: GuinjiColors.ink),
                ),
                Text(
                  label,
                  style: const TextStyle(
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
