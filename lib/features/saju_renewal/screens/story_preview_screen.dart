import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../result_access/presentation/result_access_gate_sheet.dart';
import '../data/models/topic_card.dart';
import '../data/saju_visual_adapter.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_story_widgets.dart';
import 'story_detail_screen.dart';
import 'error_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면⑤/⑨ 사주
/// 이야기 미리보기. `design_files/saju/screens-b.jsx`의 `ScreenPreview`를
/// 재현한다 — "다른 사주 이야기" 선택 후 두 번째 이후 이야기(화면⑨)도
/// 조명(SceneBg)만 바뀔 뿐 동일 화면을 재사용한다(지시서 §범위).
///
/// [Access Gate — 절대 신규 위젯 금지] "자세히보기"를 누르면 기존
/// [showResultAccessGateSheet]를 그대로 재사용한다(Wallet/복주머니/
/// AdMob/FreePass/ResultAccessGate 전부 재사용, 신규 생성 금지 —
/// 지시서 §Access Gate 요구사항). JSX 원안은 이 화면 하단에 "광고로
/// 보기"/"복주머니로 보기" 두 버튼을 직접 노출하지만, 실제 결제수단
/// 선택(프리패스/복주머니/광고/쿠팡)은 이미 [ResultAccessGateSheet] 내부
/// 바텀시트가 전담하므로 — 그 책임을 중복 구현하지 않고 기존 설계
/// 그대로 "자세히 보기" 단일 버튼만 다크 스타일로 재스킨한다.
class StoryPreviewScreen extends StatefulWidget {
  const StoryPreviewScreen({super.key});

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  bool _gateOpening = false;
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

  Future<void> _openAccessGate() async {
    if (_gateOpening) return; // [중복클릭 방어]
    setState(() => _gateOpening = true);
    final provider = context.read<SajuRenewalProvider>();
    final topic = provider.currentTopic;

    final beginResult = await showResultAccessGateSheet(
      context,
      contentType: 'saju_renewal',
      categoryKey: 'saju_renewal',
      contentId: topic?.topicId,
      contentTitle: topic?.title ?? '사주 이야기',
      returnRoute: '/saju-renewal',
    );

    if (!mounted) return;
    setState(() => _gateOpening = false);
    if (beginResult == null) return; // 사용자가 취소함

    provider.requestAccess();
    await provider.onAccessGranted();
    if (!mounted) return;

    if (provider.status == SajuRenewalFlowStatus.storyDetail) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const StoryDetailScreen()));
    } else if (provider.status == SajuRenewalFlowStatus.error) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ErrorScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    final previewState = provider.previewState;
    final topic = provider.currentTopic;
    // JSX `app.ordinal` — 지금까지 상세까지 완료한 이야기 수 + 1(지금
    // 보고 있는 이야기 차수). 1이면 첫 이야기(화면⑤ "PREVIEW · 05"),
    // 2 이상이면 재방문 이야기(화면⑨ "STORY · 09").
    final ordinal = provider.viewedStoryCount + 1;
    final scene = topic?.scene;

    return Scaffold(
      body: Container(
        color: SajuInk.i900,
        child: Stack(
          children: [
            if (scene != null)
              Positioned.fill(child: SajuSceneBg(scene: scene)),
            SafeArea(
              child: Column(
                children: [
                  SajuTopBar(
                    left: SajuIconButton(
                      icon: '←',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    title: ordinal > 1 ? 'STORY · 09' : 'PREVIEW · 05',
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (previewState.isLoading || previewState.isInitial) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: SajuGold.g300,
                            ),
                          );
                        }
                        if (previewState.isError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    previewState.errorMessage ?? '이야기를 불러오지 못했습니다.',
                                    style: SajuType.body14,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  SajuButton(
                                    label: '다시 시도',
                                    variant: SajuButtonVariant.secondary,
                                    height: 48,
                                    onTap: () {
                                      if (topic != null) {
                                        provider.loadPreview(topic);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final summary = previewState.data!;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (scene != null)
                                _SceneTag(scene: scene, ordinal: ordinal),
                              const SizedBox(height: 14),
                              Text(summary.title, style: SajuType.h1),
                              const SizedBox(height: 18),
                              Text(summary.summary, style: SajuType.body16),
                              const SizedBox(height: 26),
                              if (_profile != null)
                                SajuEvidenceCard(
                                  evidence: summary.evidence,
                                  profile: _profile!,
                                ),
                              const SizedBox(height: 24),
                              const Text(
                                '더 자세한 이유와 시기를 확인해보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: SajuType.body,
                                  fontSize: 14.5,
                                  height: 1.6,
                                  color: SajuText.muted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 하단 고정 CTA — 스크롤 콘텐츠 위로 그라데이션 페이드.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: previewState.data == null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, SajuInk.i900],
                      stops: [0.0, 0.5],
                    ),
                  ),
                  child: SajuButton(
                    label: '자세히 보기',
                    loading: _gateOpening,
                    onTap: (previewState.data == null || _gateOpening)
                        ? null
                        : _openAccessGate,
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

/// JSX `SceneTag` — 장면 아이콘·이름 + "STORY · N°0X" 모노 라벨.
class _SceneTag extends StatelessWidget {
  const _SceneTag({required this.scene, required this.ordinal});

  final SajuRenewalScene scene;
  final int ordinal;

  SajuScene get _token {
    switch (scene) {
      case SajuRenewalScene.money:
        return SajuScene.money;
      case SajuRenewalScene.talent:
        return SajuScene.talent;
      case SajuRenewalScene.love:
        return SajuScene.love;
      case SajuRenewalScene.life:
        return SajuScene.life;
      case SajuRenewalScene.guin:
        return SajuScene.guin;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _token;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.glyph, style: TextStyle(color: t.tint, fontSize: 12)),
        const SizedBox(width: 8),
        Text(
          t.nameKo,
          style: TextStyle(
            fontFamily: SajuType.ui,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.tint,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 10, color: SajuText.line),
        const SizedBox(width: 8),
        Text(
          'STORY · N°${ordinal.toString().padLeft(2, '0')}',
          style: SajuType.mono9,
        ),
      ],
    );
  }
}
