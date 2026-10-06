import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../data/models/topic_card.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import 'story_preview_screen.dart';
import 'error_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면⑧ 다른 사주
/// 이야기 후보 목록. `design_files/saju/screens-b.jsx`의 `ScreenOthers`를
/// 재현한다 — 카드형 레이아웃(장면 조명 그라데이션 + 글리프 + "시기"
/// 배지 + "열어 보기 →")만 다크 스타일로 재스킨하고, 데이터 선정 로직은
/// 전혀 바꾸지 않는다.
///
/// [Flutter 임의선정 절대 금지] 이 화면은 Topic Engine이 이미 내려준
/// `topicsState.data!.candidates`를 그대로 노출만 한다 — 후보를 다시
/// 정렬/필터링/임의 추천하지 않는다(지시서 §흐름 요구사항). JSX 원안의
/// `rotated`/`page` 클라이언트 측 후보 순환 로직은 포트하지 않는다 —
/// "새로운 이야기" 요청은 실제로 서버에 [SajuRenewalProvider.loadMoreTopics]를
/// 호출해 새 후보를 받아오는 기존 구조를 그대로 쓴다. "이미 본 이야기"
/// 재노출 방지도 서버(Exposure History)가 최종 판단하며, Flutter는
/// 지금까지 상세까지 완료한 topic_id만 `exclude_topic_ids`로 참고 전달한다.
///
/// [isTiming 필드 재사용] JSX는 `tp.evidence.type === 'luck'`로 "시기" 배지
/// 여부를 추론하지만, Flutter 쪽 `TopicCard`는 서버가 이미 내려주는
/// `isTiming` 필드를 직접 가지고 있으므로 그대로 사용한다(재추론 금지).
class MoreStoriesScreen extends StatefulWidget {
  const MoreStoriesScreen({super.key});

  @override
  State<MoreStoriesScreen> createState() => _MoreStoriesScreenState();
}

class _MoreStoriesScreenState extends State<MoreStoriesScreen> {
  bool _selecting = false;
  bool _loadingMore = false;

  Future<void> _selectCandidate(TopicCard candidate) async {
    if (_selecting) return; // [중복클릭 방어]
    setState(() => _selecting = true);
    final provider = context.read<SajuRenewalProvider>();

    await provider.loadPreview(candidate);
    if (!mounted) return;
    setState(() => _selecting = false);

    if (provider.status == SajuRenewalFlowStatus.storyPreview) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const StoryPreviewScreen()));
    } else if (provider.status == SajuRenewalFlowStatus.error) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ErrorScreen()));
    }
  }

  Future<void> _loadMore() async {
    if (_selecting || _loadingMore) return;
    setState(() => _loadingMore = true);
    final provider = context.read<SajuRenewalProvider>();
    await provider.loadMoreTopics();
    if (!mounted) return;
    setState(() => _loadingMore = false);
    if (provider.status == SajuRenewalFlowStatus.error) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ErrorScreen()));
    }
  }

  SajuScene _tokenOf(SajuRenewalScene scene) {
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
    final provider = context.watch<SajuRenewalProvider>();
    final topicsState = provider.topicsState;

    return Scaffold(
      body: SajuDarkBase(
        child: SafeArea(
          child: Builder(
            builder: (context) {
              if (topicsState.isLoading || provider.isTopicsLoading) {
                return Column(
                  children: [
                    SajuTopBar(
                      left: SajuIconButton(
                        icon: '←',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      title: 'MORE · 08',
                    ),
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: SajuGold.g300),
                      ),
                    ),
                  ],
                );
              }
              if (topicsState.isError) {
                return Column(
                  children: [
                    SajuTopBar(
                      left: SajuIconButton(
                        icon: '←',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      title: 'MORE · 08',
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                topicsState.errorMessage ?? '이야기를 불러오지 못했습니다.',
                                style: SajuType.body14,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              SajuButton(
                                label: '다시 시도',
                                variant: SajuButtonVariant.secondary,
                                height: 48,
                                onTap: _loadMore,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              // [버그 수정 — C-08a(docs/08) 결함 발견] 기존에는
              // `topicsState.data.candidates`를 그대로 노출해 이미
              // 상세까지 본 주제가 다시 나타나고 4개 이상 표시될 수
              // 있었다. Provider의 [displayableCandidates](이미 본
              // 주제 제외 + 3장 cap, docs/13 Q-06)를 사용한다.
              final candidates = provider.displayableCandidates;

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SajuTopBar(
                      left: SajuIconButton(
                        icon: '←',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      title: 'MORE · 08',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '당신의 사주에서 발견한\n또 다른 이야기',
                            style: TextStyle(
                              fontFamily: SajuType.body,
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                              height: 1.4,
                              letterSpacing: -0.02 * 24,
                              color: SajuGold.g100,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('오늘은 어떤 이야기가 나올까요?', style: SajuType.body14),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: candidates.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '새로운 사주 이야기를 찾고 있어요.',
                                    style: SajuType.body14,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  SajuButton(
                                    label: '↻ 새로운 이야기',
                                    variant: SajuButtonVariant.ghost,
                                    height: 48,
                                    loading: _loadingMore,
                                    onTap: _loadMore,
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                for (int i = 0; i < candidates.length; i++) ...[
                                  _CandidateCard(
                                    candidate: candidates[i],
                                    scene: _tokenOf(candidates[i].scene),
                                    enabled: !_selecting,
                                    onTap: () =>
                                        _selectCandidate(candidates[i]),
                                  ),
                                  if (i != candidates.length - 1)
                                    const SizedBox(height: 12),
                                ],
                                const SizedBox(height: 24),
                                // [웹 AdSense — STEP E] 후보 카드 리스트와
                                // "새로운 이야기" 버튼 사이, 충분한 여백을
                                // 두고 배치한다. 카드와 디자인(테두리/배경)
                                // 을 공유하지 않아 후보 카드로 오인되지
                                // 않는다(지시서 §5 버튼/카드 비혼동 원칙).
                                const WebAdInPage(
                                  surface: WebAdSurface.sajuRenewal,
                                  adSlot: '',
                                ),
                                const SizedBox(height: 24),
                                SajuButton(
                                  label: '↻ 새로운 이야기',
                                  variant: SajuButtonVariant.ghost,
                                  height: 48,
                                  loading: _loadingMore,
                                  onTap: _selecting ? null : _loadMore,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// JSX `ScreenOthers` 후보 카드 — 장면 조명 그라데이션 + 글리프 + "시기"
/// 배지 + 타이틀 + "열어 보기 →".
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.scene,
    required this.enabled,
    required this.onTap,
  });

  final TopicCard candidate;
  final SajuScene scene;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SajuText.lineGold),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [SajuViolet.v800, SajuViolet.v900],
            ),
          ),
          child: Stack(
            children: [
              // 우상단 방사형 조명(radial glow).
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scene.tint.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65],
                    ),
                  ),
                ),
              ),
              // 장면 글리프(발광).
              Positioned(
                right: 18,
                top: 10,
                child: Text(
                  scene.glyph,
                  style: TextStyle(
                    fontSize: 34,
                    color: scene.tint.withValues(alpha: 0.85),
                    shadows: [Shadow(color: scene.tint, blurRadius: 18)],
                  ),
                ),
              ),
              // 좌상단 장면 이름 + "시기" 배지.
              Positioned(
                left: 18,
                top: 18,
                child: Row(
                  children: [
                    Text(
                      scene.nameKo,
                      style: TextStyle(
                        fontFamily: SajuType.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scene.tint,
                      ),
                    ),
                    if (candidate.isTiming) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: SajuText.lineGold),
                        ),
                        child: const Text(
                          '시기',
                          style: TextStyle(
                            fontFamily: SajuType.ui,
                            fontSize: 10,
                            color: SajuGold.g100,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 좌하단 타이틀.
              Positioned(
                left: 18,
                right: 70,
                bottom: 18,
                child: Text(
                  candidate.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: SajuType.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 18.5,
                    height: 1.35,
                    letterSpacing: -0.02 * 18.5,
                    color: SajuGold.g100,
                  ),
                ),
              ),
              // 우하단 "열어 보기 →".
              Positioned(
                right: 18,
                bottom: 18,
                child: Text(
                  '열어 보기 →',
                  style: TextStyle(
                    fontFamily: SajuType.ui,
                    fontSize: 12,
                    color: SajuGold.g300,
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
