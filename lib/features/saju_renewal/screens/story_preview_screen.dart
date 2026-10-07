import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_banner.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../data/models/topic_card.dart';
import '../data/saju_term_dictionary.dart';
import '../data/saju_visual_adapter.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_story_widgets.dart';
import '../widgets/saju_result_access_gate_sheet.dart';
import 'story_detail_screen.dart';
import 'error_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면⑤/⑨ 사주
/// 이야기 미리보기. `design_files/saju/screens-b.jsx`의 `ScreenPreview`를
/// 재현한다 — "다른 사주 이야기" 선택 후 두 번째 이후 이야기(화면⑨)도
/// 조명(SceneBg)만 바뀔 뿐 동일 화면을 재사용한다(지시서 §범위).
///
/// [Access Gate — docs/10 §2 "로직 재사용, 외형은 C-12로 교체 필수"]
/// "자세히보기"를 누르면 [showSajuResultAccessGateSheet]를 띄운다. 이
/// 시트는 기존 [ResultAccessProvider](quote/begin/광고/쿠팡 로직)를
/// 100% 그대로 호출하되, 외형만 C-12/화면06 사양(다크 바텀시트·인용
/// 마스킹 카드·GateOption 3행·금빛 프리패스 인장)으로 새로 그린
/// 것이다 — 기존 라이트 테마 [ResultAccessGateSheet]를 그대로 띄우면
/// 디자인 검수 반려 사유이므로(docs/12 확인②) 더는 사용하지 않는다.
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

  /// `[[termKey|쉬운 표현]]` 마크업을 제거하고 마지막 문장만 뽑아 인용
  /// 카드(C-06-8)에 쓴다 — E-25 "마크업 깨짐" 처리 원칙과 동일하게 원문
  /// 그대로 노출하지 않는다.
  String? _extractLastSentence(String? summary) {
    if (summary == null || summary.isEmpty) return null;
    final plain = summary.replaceAllMapped(
      RegExp(r'\[\[([^|\]]+)\|([^\]]+)\]\]'),
      (m) => m.group(2) ?? '',
    );
    final sentences = plain
        .split(RegExp(r'(?<=[.!?。？])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sentences.isEmpty) return plain.trim();
    return sentences.last.trim();
  }

  Future<void> _openAccessGate() async {
    if (_gateOpening) return; // [중복클릭 방어]
    setState(() => _gateOpening = true);
    final provider = context.read<SajuRenewalProvider>();
    final topic = provider.currentTopic;
    final previewData = provider.previewState.data;

    final beginResult = await showSajuResultAccessGateSheet(
      context,
      contentId: topic?.topicId,
      contentTitle: topic?.title ?? '사주 이야기',
      quoteText: _extractLastSentence(previewData?.summary),
      returnRoute: '/saju-renewal',
    );

    if (!mounted) return;
    setState(() => _gateOpening = false);
    if (beginResult == null) return; // 사용자가 취소함

    provider.requestAccess();
    // [버그 수정 — 결과보기 결제 게이트 우회 방어] Access Gate.begin()이
    // 발급한 transactionId를 서버 재검증용으로 그대로 전달한다. 이게
    // 없으면 서버가 TRANSACTION_ID_REQUIRED로 거부한다.
    await provider.onAccessGranted(transactionId: beginResult.transactionId);
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

  /// [버그 수정 — C-05c(docs/08) 현더케이스에 전혀 없었던 분기 발견]
  /// docs/03_화면명세.md §05 "해제됨(05-C) | Primary [자세히 보기]
  /// → 07 직행(게이트 없음)" 및 원본 `screens-b.jsx` `ScreenPreview`의
  /// `unlocked ? go('07') : go('06')` 분기를 그대로 재현한다. 이미
  /// [onAccessGranted]로 상세까지 완료한 topic(=
  /// [SajuRenewalProvider.isTopicUnlocked])이면 게이트를 다시 띄우지
  /// 않고 서버 멑등 캐시(saju_renewal_api.dart "userId+topicId+mode
  /// 조합 멑등 캐시")로 즉시 반환되는 interpretDetail을 재호출해
  /// 바로 07로 보낸다.
  Future<void> _openUnlockedDetail() async {
    if (_gateOpening) return; // [중복클릭 방어]
    setState(() => _gateOpening = true);
    final provider = context.read<SajuRenewalProvider>();
    await provider.onAccessGranted();
    if (!mounted) return;
    setState(() => _gateOpening = false);

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
    // [버그 수정 — C-09a] JSX `app.ordinal` — "이번 세션에서 몇 번째로
    // 미리보기하는 주제인가"(상세보기 완료 여부와 무관, 05↔07 전환
    // 중에도 불변). 1이면 첫 이야기(화면⑤ "PREVIEW · 05"), 2 이상이면
    // 재방문 이야기(화면⑨ "STORY · 09"). 과거에는
    // `viewedStoryCount + 1`(상세보기 완료 횟수)을 썼는데, 그러면 05에서
    // 보여준 순번이 07에서 1 증가해 보이는 불일치가 있었다(재현 테스트로
    // 확인).
    final ordinal = topic != null ? provider.ordinalOf(topic.topicId) : 1;
    final scene = topic?.scene;
    // C-05c/docs/03 §05 "해제됨" 분기 — 원본 jsx `unlocked`에 대응.
    final unlocked = topic != null && provider.isTopicUnlocked(topic.topicId);

    return Scaffold(
      body: SajuTermScope(
        onOpenTerm: (termKey) {
          final term = sajuTermLookup(termKey);
          if (term == null) return;
          showSajuTermSheet(
            context,
            termLabel: term.sheetTitle,
            definition: term.note,
          );
        },
        child: Container(
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
                          if (previewState.isLoading ||
                              previewState.isInitial) {
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
                                      previewState.errorMessage ??
                                          '이야기를 불러오지 못했습니다.',
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
                                SajuTermText(
                                  text: summary.summary,
                                  style: SajuType.body16,
                                ),
                                const SizedBox(height: 26),
                                if (_profile != null)
                                  SajuEvidenceCard(
                                    evidence: summary.evidence,
                                    profile: _profile!,
                                  ),
                                const SizedBox(height: 28),
                                // [웹 AdSense — STEP E] 사주 이야기 본문과
                                // 하단 고정 "자세히 보기" CTA 사이, 충분한
                                // 여백을 두고 배치한다. CTA 버튼은 화면
                                // 최하단에 별도 고정되어 있어 이 배너와
                                // 겹치거나 혼동될 위치가 아니다.
                                const WebAdBanner(
                                  surface: WebAdSurface.sajuRenewal,
                                  adSlot: '',
                                ),
                                const SizedBox(height: 28),
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
                    child: unlocked
                        // C-05c "해제됨(05-C)" — Primary [자세히 보기] →
                        // 게이트 없이 07 직행(docs/06 C-05-6).
                        ? SajuButton(
                            label: '자세히 보기',
                            loading: _gateOpening,
                            onTap: (previewState.data == null || _gateOpening)
                                ? null
                                : _openUnlockedDetail,
                          )
                        // C-05c "미해제(05-A)" — Primary [자세한 이야기
                        // 열어 보기](C-05-4) + 안내(C-05-5).
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SajuButton(
                                label: '자세한 이야기 열어 보기',
                                loading: _gateOpening,
                                onTap:
                                    (previewState.data == null || _gateOpening)
                                    ? null
                                    : _openAccessGate,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                '프리패스 · 복주머니 · 광고 중 하나로 열 수 있어요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: SajuType.ui,
                                  fontSize: 11.5,
                                  color: SajuText.faint,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
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
