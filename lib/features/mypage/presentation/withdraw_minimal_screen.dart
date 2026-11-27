import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../attendance/application/attendance_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../fortune/shared/data/reading_artifact_store.dart';
import '../../pass/application/pass_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../wishroom/application/wishroom_provider.dart';
import '../../wishroom/data/models.dart';
import 'theme/mypage_minimal_theme.dart';
import 'theme/mypage_toast.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S17] "회원탈퇴" 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S17 회원탈퇴" 스펙(히어로
/// 타이틀, 리드 문단, "잃게 되는 항목" dashed 구분선 표, 22px 체크박스로
/// 게이팅되는 CTA, D3 확인 다이얼로그)에 따른 전면 신규 화면이다. 기존
/// `SettingsMinimalScreen`의 "회원탈퇴" 행은 지금까지 `_confirmWithdraw()`를
/// 직접 호출해 D3 다이얼로그만 바로 띄웠으나(S17 전용 화면이 아직 없어
/// 임시로 그 자리에 뒀던 것), 이 화면으로 대체한다 —
/// S03/S05/S09/S11/S12/S13/S14/S15/S16과 동일한 "신규 파일 + 호출부만
/// 교체" 패턴이다.
///
/// [잃게 되는 항목 — 데이터 소스, 로직은 그대로 재사용]
/// - 보유 복주머니: [WalletProvider.balance] (서버 지갑 잔액 그대로).
/// - 밝히고 있는 소원: [WishRoomProvider.room]은 사용자당 1개의 nullable
///   필드다(목록/카운트 필드가 서버에 따로 없음). `vault_screen.dart`의
///   `'진행 중 (${cur != null ? 1 : 0})'` 칩과 동일한 관례를 따라, 봉인/
///   보관된 방이 아닌 진행 중인 방이 있으면 1, 없으면 0으로 센다.
/// - 저장한 풀이: [ReadingArtifactStore.list()] — README S06 "보관한 풀이"
///   타일(`saved`)이 쓰는 것과 동일한 로컬 저장소다(최대 12개,
///   SharedPreferences 기반).
/// - 연속 출석: [AttendanceProvider.streak].
/// 네 값 모두 새 서버 API를 만들지 않고 기존 Provider/Store를 그대로 읽는다
/// ("로직은 그대로, 스킨만 교체" 원칙). 화면 진입 시 `my_screen.dart`
/// initState()와 동일한 패턴으로 각 Provider의 `load()`/`loadMyRoom()`을
/// 호출해 최신값을 보장한다(이미 로드돼 있어도 재호출은 안전하다).
///
/// [D3 확인 다이얼로그 — 기존 코드 이전]
/// 기존 `SettingsMinimalScreen._showMyPageConfirmDialog()`/
/// `_confirmWithdraw()`(글리프 別, "정말 떠나시겠어요" 등)를 이 화면의
/// private 메서드로 그대로 옮겨왔다 — 각 S화면이 다이얼로그 코드를 공유
/// 위젯으로 묶지 않고 자기완결로 복제하는 기존 관례(S13의 동일 다이얼로그
/// 복제)를 따른다. `settings_minimal_screen.dart`의 원본은 이 화면으로
/// 옮겨온 뒤 삭제한다.
class WithdrawMinimalScreen extends StatefulWidget {
  const WithdrawMinimalScreen({super.key});

  @override
  State<WithdrawMinimalScreen> createState() => _WithdrawMinimalScreenState();
}

class _WithdrawMinimalScreenState extends State<WithdrawMinimalScreen> {
  bool _checked = false;
  bool _submitting = false;

  int? _savedReadingsCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<WishRoomProvider>().loadMyRoom();
      _loadSavedReadingsCount();
    });
  }

  Future<void> _loadSavedReadingsCount() async {
    final items = await ReadingArtifactStore.list();
    if (!mounted) return;
    setState(() => _savedReadingsCount = items.length);
  }

  /// README "다이얼로그 공통 (D1–D3)" 시각 스펙(도장 44×44 rotate(-6°),
  /// 제목 19px/800, 버튼 2열)을 따르는 확인 다이얼로그. 원래
  /// `settings_minimal_screen.dart`에 있던 구현을 그대로 옮겨왔다(각
  /// S화면 자기완결 관례 — 공용 위젯으로 묶지 않는다).
  Future<bool> _showMyPageConfirmDialog(
    BuildContext context, {
    required String glyph,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MyPageColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MyPageRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -6 * 3.14159265 / 180,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MyPageColors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    glyph,
                    style: const TextStyle(
                      fontFamily: MyPageFonts.hanja,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  height: 1.3,
                  color: MyPageColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.5,
                  color: MyPageColors.ink2,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0x122A1F14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: MyPageColors.ink2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: MyPageColors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmWithdraw(BuildContext context) async {
    final confirmed = await _showMyPageConfirmDialog(
      context,
      glyph: '別',
      title: '정말 떠나시겠어요',
      message: '담아둔 소원과 복주머니가 모두 사라져요',
      confirmLabel: '탈퇴',
    );
    if (!confirmed || !context.mounted) return;

    setState(() => _submitting = true);

    // [6-6 QA Low#5 최소 수정과 동일한 순서] 인증 토큰이 아직 살아있는
    // 동안(AuthProvider.withdraw()가 토큰을 지우기 전) PassProvider.
    // resetOnLogout()을 먼저 호출해 서버측 프리패스를 만료시킨다.
    await context.read<PassProvider>().resetOnLogout();
    if (!context.mounted) return;

    final ok = await context.read<AuthProvider>().withdraw();
    if (!context.mounted) return;

    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      setState(() => _submitting = false);
      showMyPageToast(context, '탈퇴 처리에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final wishRoom = context.watch<WishRoomProvider>();

    final pouchCount = wallet.balance;
    final room = wishRoom.room;
    final hasActiveWish =
        room != null &&
        room.status != RoomStatus.SEALED &&
        room.status != RoomStatus.ARCHIVED;
    final wishCount = hasActiveWish ? 1 : 0;
    final savedReadingsCount = _savedReadingsCount ?? 0;
    final streakCount = attendance.streak;

    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // README "서브화면 공통 셸" 상단바.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 40,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: MyPageColors.ink,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            '회원탈퇴',
                            textAlign: TextAlign.center,
                            style: MyPageTextStyles.header,
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    MyPageSpacing.subX,
                    6,
                    MyPageSpacing.subX,
                    140,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text(
                        '떠나시기 전에\n한 번만 살펴봐 주세요',
                        style: MyPageTextStyles.display,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '탈퇴하면 아래 기록이 모두 사라지고\n다시 되돌릴 수 없어요',
                        style: MyPageTextStyles.body,
                      ),
                      // README ".lose" — 행 사이 dashed 구분선, 값은 빨강 900.
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          children: [
                            _LoseRow(
                              label: '보유 복주머니',
                              value: '$pouchCount개',
                              showDivider: true,
                            ),
                            _LoseRow(
                              label: '밝히고 있는 소원',
                              value: '$wishCount개',
                              showDivider: true,
                            ),
                            _LoseRow(
                              label: '저장한 풀이',
                              value: '$savedReadingsCount개',
                              showDivider: true,
                            ),
                            _LoseRow(
                              label: '연속 출석',
                              value: '$streakCount일',
                              showDivider: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: () => setState(() => _checked = !_checked),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CheckBox(checked: _checked),
                              const SizedBox(width: 10),
                              const Text(
                                '위 내용을 확인했어요',
                                style: TextStyle(
                                  fontFamily: MyPageFonts.ui,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: MyPageColors.ink2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            // README ".dock" — 하단 고정 CTA(투명→paper 그라디언트 배경).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00F7EEDC),
                      MyPageColors.paper,
                    ],
                    stops: [0.0, 0.5],
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_checked && !_submitting)
                        ? () => _confirmWithdraw(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyPageColors.red,
                      disabledBackgroundColor: MyPageColors.red.withValues(
                        alpha: 0.3,
                      ),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MyPageRadius.cta),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '탈퇴하기',
                            style: TextStyle(
                              fontFamily: MyPageFonts.ui,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
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

/// README ".lose div" — `display:flex;justify-content:space-between;
/// padding:14px 0;border-bottom:1px dashed var(--hair)`를 그대로 포팅한
/// 행. 전용 가로 점선 구분선 위젯이 기존 코드베이스에 없어
/// ([MyPageDashedBorderBox]는 RRect 전체 테두리용, `_DashedCharmPainter`는
/// 빈 상태 일러스트용) 이 화면에 맞는 작은 CustomPainter를 새로 그린다.
class _LoseRow extends StatelessWidget {
  const _LoseRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: MyPageFonts.ui,
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: MyPageColors.ink,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: MyPageFonts.hanja,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: MyPageColors.red,
            ),
          ),
        ],
      ),
    );
    if (!showDivider) return row;
    return CustomPaint(
      painter: _DashedBottomLinePainter(color: MyPageColors.hair),
      child: row,
    );
  }
}

/// 단일 가로 점선(해당 위젯 하단에만)을 그리는 경량 CustomPainter.
/// README ".lose div{border-bottom:1px dashed var(--hair)}" 스펙 전용.
class _DashedBottomLinePainter extends CustomPainter {
  const _DashedBottomLinePainter({required this.color});
  final Color color;

  static const double _dashWidth = 4;
  static const double _dashGap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double x = 0;
    final y = size.height - 0.5;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + _dashWidth, y), paint);
      x += _dashWidth + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBottomLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// README ".chk i" — 22px 체크박스(선택 시 빨강 배경+흰 체크). S13의
/// `_CheckBox`와 동일 스펙을 이 화면에도 복제한다(자기완결 관례).
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MyPageMotion.fade,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? MyPageColors.red : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? MyPageColors.red : const Color(0x4D2A1F14),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
