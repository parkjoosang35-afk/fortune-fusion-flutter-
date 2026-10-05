import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../data/saju_visual_adapter.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_story_widgets.dart';
import '../widgets/saju_visual_widgets.dart';
import 'error_screen.dart';
import 'story_preview_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면④ 분석 완료.
/// `design_files/saju/screens-a.jsx`의 `ScreenComplete`를 1:1로 재현한다.
///
/// [절대 금지] 내부 TopicID(예: MONEY_002)를 절대 노출하지 않는다 —
/// 이 화면은 디자인 핸드오프 원안대로 topic.title조차 아직 보여주지
/// 않는다("이야기는 아직 봉인되어 있다"는 서사). 실제 제목/요약은 다음
/// 화면(⑤ 이야기 미리보기)에서만 노출된다.
///
/// [실제 데이터 사용] 배경에 깔리는 흐릿한 원국(PillarGrid)·팔괘(Bagua)는
/// 가짜 데모 사주가 아니라 화면②에서 저장된 실제 사용자 생년월일로
/// [SajuVisualAdapter]가 계산한 값이다(02/03/04 공용 — 기존 설계 유지).
class AnalysisCompleteScreen extends StatefulWidget {
  const AnalysisCompleteScreen({super.key});

  @override
  State<AnalysisCompleteScreen> createState() =>
      _AnalysisCompleteScreenState();
}

class _AnalysisCompleteScreenState extends State<AnalysisCompleteScreen> {
  bool _navigated = false;
  bool _opening = false; // JSX: opening — 봉인 카드 열림 애니메이션 트리거.
  SajuVisualProfile? _profile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _profile = _buildProfile(user);
  }

  SajuVisualProfile? _buildProfile(UserModel? user) {
    if (user == null || user.birthDate == null) return null;
    final parts = user.birthDate!.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final timeUnknown = user.birthTimeUnknown || user.birthTime == null;
    int hour = 0;
    if (!timeUnknown && user.birthTime != null) {
      final t = user.birthTime!.split(':');
      hour = int.tryParse(t.isNotEmpty ? t[0] : '') ?? 0;
    }
    return SajuVisualAdapter.build(
      kst: DateTime(y, m, d, hour, 0),
      gender: user.gender ?? 'female',
      isLunar: user.isLunar,
      timeUnknown: timeUnknown,
      referenceDate: DateTime.now(),
      isLeapMonth: user.isLeapMonth,
    );
  }

  void _maybeNavigateOnError(SajuRenewalProvider provider) {
    if (_navigated || provider.status != SajuRenewalFlowStatus.error) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ErrorScreen()));
    });
  }

  /// JSX: `open = () => { setOpening(true); setTimeout(() => go('05'), 650); }`.
  Future<void> _open() async {
    if (_opening) return; // [중복클릭 방어]
    setState(() => _opening = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StoryPreviewScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    _maybeNavigateOnError(provider);
    final topic = provider.currentTopic;

    final pillars = _profile?.pillars ?? const [null, null, null, null];
    final relations = _profile?.relations ?? const [];

    return Scaffold(
      body: SajuDarkBase(
        child: SafeArea(
          child: Column(
            children: [
              SajuTopBar(
                left: SajuIconButton(
                  // JSX: go('01') — "다시보기/분석완료" 흐름을 닫고
                  // 화면① 메인으로 복귀한다(error_screen.dart의
                  // "처음으로 돌아가기"와 동일한 패턴 재사용).
                  icon: '✕',
                  onTap: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
                title: 'FOUND · 04',
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // 완성된 원국 — 배경 고정(흐릿하게).
                    Positioned(
                      top: 20,
                      child: Opacity(
                        opacity: 0.28,
                        child: SajuPillarGrid(
                          pillars: pillars,
                          cell: 60,
                          gap: 10,
                          showRelations: true,
                          relations: relations,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 42,
                      child: Opacity(
                        opacity: 0.18,
                        child: SajuBagua(size: 340, speedSeconds: 200),
                      ),
                    ),
                    // 봉인된 이야기 카드 — 열기 전까지 4초 주기로 떠다님.
                    Positioned(
                      top: 52,
                      child: _FloatingSealedCard(
                        opening: _opening,
                        child: SajuSealedCard(width: 210, opening: _opening),
                      ),
                    ),
                    // 카피(지시서 docs/06_카피덱.md — 한 글자도 바꾸지 않음).
                    Positioned(
                      top: 372,
                      left: 28,
                      right: 28,
                      child: Column(
                        children: [
                          const Text(
                            '당신의 사주에서 —\n특별한 이야기를 찾았습니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: SajuType.serif,
                              fontWeight: FontWeight.w700,
                              fontSize: 23,
                              height: 1.45,
                              color: SajuGold.g100,
                              letterSpacing: -0.02 * 23,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '당신만을 위한 첫 번째 사주 이야기를 준비했습니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: SajuType.body,
                              fontSize: 14.5,
                              height: 1.6,
                              color: SajuText.muted,
                            ),
                          ),
                          if (topic == null) ...[
                            const SizedBox(height: 22),
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: SajuGold.g300,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 46),
                child: SajuButton(
                  label: '이야기 열어 보기',
                  onTap: (_opening || topic == null) ? null : _open,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// JSX `animation: opening ? 'none' : 'sj-float 4s ease-in-out infinite'`.
/// 열림이 시작되면 둥둥 뜨는 효과를 멈추고 제자리로 고정한다.
class _FloatingSealedCard extends StatefulWidget {
  const _FloatingSealedCard({required this.opening, required this.child});

  final bool opening;
  final Widget child;

  @override
  State<_FloatingSealedCard> createState() => _FloatingSealedCardState();
}

class _FloatingSealedCardState extends State<_FloatingSealedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opening) {
      // 열림 중엔 둥둥 뜨는 효과를 멈추고 제자리로.
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dy = -10 * Curves.easeInOut.transform(_controller.value);
        return Transform.translate(offset: Offset(0, dy), child: widget.child);
      },
    );
  }
}
