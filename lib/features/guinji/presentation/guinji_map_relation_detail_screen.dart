import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/util/safe_share.dart';
import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../application/guinji_provider.dart';
import '../application/guinji_rewarded_ad_helper.dart';
import '../deep/guinji_reasons.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';
import 'guinji_deep_intro_screen.dart';
import 'guinji_deep_result_screen.dart';

/// 귀인지도(Guinji Map) — 관계 상세 화면 (`/guinji-map/*` 신규 디자인 톤).
///
/// [귀인지도 기능 정리 — 1] M(내 지도) 화면 노드 탭 → 바텀시트(N)의
/// "더 자세히 보기" 버튼이 지금까지 빈 콜백(`onSeeMore: () {}`)이라 눌러도
/// 아무 반응이 없던 문제를 해결한다. N(바텀시트)의 요약보다 더 깊은 정보
/// (오행 근거·좋은/조심할 순간·스페셜 해설 잠금해제)를 아이보리·로즈골드
/// 톤(`GmColors`, `/guinji-map/*` 8화면과 동일 팔레트)으로 새로 구현했다.
/// 기존 `guinji_relation_detail_screen.dart`(다크·라벤더 톤, `/guinji/*`
/// 구계열 전용)는 그대로 두고 건드리지 않는다 — 완전히 별개의 화면이다.
///
/// [스페셜 해설 잠금해제] "광고 보고 열기"/"복주머니 50P로 열기"는 실제
/// 서버 API(`POST /guinji/unlocks`, [GuinjiProvider.unlock])를 그대로
/// 호출한다 — 구계열 상세화면과 동일한 백엔드 연동, UI만 새 디자인으로.
class GuinjiMapRelationDetailScreen extends StatefulWidget {
  const GuinjiMapRelationDetailScreen({super.key, required this.person});

  final GuinjiPerson person;

  @override
  State<GuinjiMapRelationDetailScreen> createState() =>
      _GuinjiMapRelationDetailScreenState();
}

class _GuinjiMapRelationDetailScreenState
    extends State<GuinjiMapRelationDetailScreen> {
  // [해금 상태 영속화 — 2026-09 버그수정] 서버가 이미 해금된 것으로
  // 응답한 멤버(`person.unlocked`)라면 화면 진입 즉시 해금 상태로 시작한다.
  // 기존에는 항상 false로 시작해 앱을 나갔다 들어오면 다시 잠긴 것처럼
  // 보이는 문제("한번 열어본거 계속 열려야됨")가 있었다.
  late bool _specialUnlocked = widget.person.unlocked;
  bool _unlocking = false;

  // [핸드오프 `CMain` `unlocked` 상태 이식] 이번 화면 방문 중에 "방금"
  // 해금한 경우에만 [GuinjiDeepIntroScreen]을 1회 보여주고, 이미 해금되어
  // 있던 관계를 "다시 보기"할 때는(`widget.person.unlocked == true`로
  // 시작한 경우) 곧바로 [GuinjiDeepResultScreen]으로 간다 — 핸드오프
  // `unlocked.includes(selM.id) ? 'result' : 'pay'` 분기와 동일한 의도.
  bool _justUnlocked = false;

  static String _goodMoment(String category) {
    switch (category) {
      case 'boost':
        return '큰 결정을 앞두고 있을 때, 감정이 흔들릴 때';
      case 'path':
        return '함께 계획하고 실행할 때, 여행이나 도전';
      case 'warm':
        return '일이 벅찰 때 잠깐 만나 대화를 나눌 때';
      case 'care':
        return '무대 위, 새로운 자극이 필요할 때';
    }
    return '평범한 일상 속 짧은 만남';
  }

  static String _carefulMoment(String category) {
    switch (category) {
      case 'boost':
        return '서로 지쳐 있는 저녁 시간대의 다툼';
      case 'path':
        return '속도가 안 맞을 때 서로 답답해질 수 있어요';
      case 'warm':
        return '너무 자주 만나면 서로 무뎌질 수 있어요';
      case 'care':
        return '가까이 붙어 있을 때 감정 소모가 커요';
    }
    return '무리한 부탁이나 갑작스러운 변화';
  }

  // [광고 해금 버그수정 — 2026-09] method가 'ad'면 서버 API를 곧바로
  // 호출하지 않고, 먼저 실제 AdMob 리워드 광고를 로드/재생한다. 광고를
  // 끝까지 시청했을 때만 [_callUnlockApi]로 서버 해금을 요청한다
  // ("광고연결 안됨" 리포트 대응 — 이전에는 광고 자체가 전혀 뜨지 않았다).
  Future<void> _handleUnlock(String method) async {
    if (_unlocking) return;
    if (method == 'ad') {
      setState(() => _unlocking = true);
      await GuinjiRewardedAdHelper.loadAndShow(
        onResult: (rewarded, errorMessage) {
          if (!mounted) return;
          if (rewarded) {
            _callUnlockApi(method);
          } else {
            setState(() => _unlocking = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage ?? '광고 시청이 완료되지 않았어요.')),
            );
          }
        },
      );
      return;
    }
    setState(() => _unlocking = true);
    await _callUnlockApi(method);
  }

  Future<void> _callUnlockApi(String method) async {
    final provider = context.read<GuinjiProvider>();
    final ok = await provider.unlock(
      memberId: widget.person.id,
      method: method,
    );
    if (!mounted) return;
    setState(() => _unlocking = false);
    if (ok) {
      setState(() {
        _specialUnlocked = true;
        _justUnlocked = true;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.error ?? '해금에 실패했습니다.')));
    }
  }

  // [공유하기 버튼 버그수정 — 2026-09, 근본 수정 2026-12] 기존에는
  // Share.share()를 결과를 기다리지 않고 fire-and-forget으로 호출해, 웹에서
  // navigator.share 미지원/실패 시(또는 Android에서 공유 대상 앱이 없을 때)
  // 아무 반응도 없이 조용히 실패하는 문제가 있었다("이관계공유하기 안됨"
  // 리포트). 2026-12 재조사 결과 `share_plus_web.dart`가 canShare()
  // 미지원 브라우저에서 `mailto:` 스킴을 자체적으로 새 탭에 열려고 시도해
  // net::ERR_UNKNOWN_URL_SCHEME 에러 화면을 유발하는 것을 확인했다(공통
  // 헬퍼 문서 참고: core/util/safe_share.dart). 이제 그 공통 헬퍼를
  // 사용해 웹에서는 Share.share() 자체를 시도하지 않는다.
  Future<void> _handleShare() async {
    final person = widget.person;
    final meta = guinjiRelationMetaOf(person.relation);
    final message = '${person.name}님과의 관계는 "${meta.label}"예요 · 신통방통 귀인지도';
    if (!mounted) return;
    await safeShareText(context, message, subject: '신통방통 귀인지도');
  }

  // [핸드오프 `CMain` `onDeep` 1:1 이식] 방금 해금했다면
  // [GuinjiDeepIntroScreen](풀이 준비 애니메이션)을 먼저 보여주고, 이미
  // 해금되어 있던 관계를 다시 볼 때는 인트로를 건너뛰고 곧바로
  // [GuinjiDeepResultScreen]으로 이동한다.
  void _openDeep() {
    final ownerName = context.read<GuinjiProvider>().mapName ?? '나';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _justUnlocked
            ? GuinjiDeepIntroScreen(
                person: widget.person,
                ownerName: ownerName,
                onShare: _handleShare,
              )
            : GuinjiDeepResultScreen(
                person: widget.person,
                ownerName: ownerName,
                onShare: _handleShare,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final meta = guinjiRelationMetaOf(person.relation);
    final ohaeng = guinjiOhaengTypes[person.ohaeng];
    final color = meta.color;
    final initial = person.name.isNotEmpty ? person.name.substring(0, 1) : '?';
    final category = meta.category;

    return Scaffold(
      backgroundColor: GmColors.bg,
      appBar: GmTopBar(back: true, title: '${person.name}님과의 관계'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero — 아바타 + 이름 + 관계 라벨 + 점수.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: GmColors.card,
                  border: Border.all(color: GmColors.line),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.85)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: GmText.display,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GmChip(
                      label: '${meta.hanja} ${meta.label}',
                      background: color.withValues(alpha: 0.12),
                      foreground: color,
                      borderColor: color.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontFamily: GmText.display,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GmColors.fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.birth,
                      style: const TextStyle(fontSize: 11, color: GmColors.dim),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${person.score}',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/ 100',
                          style: TextStyle(fontSize: 13, color: GmColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '관계 케미 점수',
                      style: TextStyle(fontSize: 10.5, color: GmColors.dim),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 관계의 결.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: GmColors.card,
                  border: Border.all(color: GmColors.line),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GmLabelMini('관계의 결'),
                    const SizedBox(height: 10),
                    Text(
                      meta.long,
                      style: const TextStyle(fontSize: 13.5, height: 1.7, color: GmColors.fg),
                    ),
                    const SizedBox(height: 14),
                    _MomentRow(
                      color: color,
                      label: '함께 있으면 좋은 순간',
                      desc: _goodMoment(category),
                    ),
                    const SizedBox(height: 8),
                    _MomentRow(
                      color: GmColors.danger,
                      label: '조심할 순간',
                      desc: _carefulMoment(category),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // [핸드오프 CDetail "이렇게 판정했어요" 이식] S1~S5 룰트레이스를
              // 사람이 읽을 수 있는 문장으로 보여준다(`guinjiReasons`, 관계
              // 유형별 고정 3줄). 지금까지 `guinji_reasons.dart`가 작성만
              // 되어 있고 실제 화면 어디에서도 쓰이지 않던 누락을 해소한다.
              _ReasonsCard(relationKey: person.relation),
              const SizedBox(height: 12),

              // 오행 근거.
              if (ohaeng != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GmColors.card,
                    border: Border.all(color: GmColors.line),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ohaeng.color.withValues(alpha: 0.16),
                          border: Border.all(color: ohaeng.color.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          ohaeng.label,
                          style: TextStyle(
                            fontFamily: GmText.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: ohaeng.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ohaeng.name}(${ohaeng.label}) 기운의 사람',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: GmColors.fg,
                              ),
                            ),
                            if (person.note.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                person.note,
                                style: const TextStyle(fontSize: 11, color: GmColors.muted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // [웹 일반 AdSense 전체 확장 — 귀인지도] "관계의 결"/"오행
              // 근거"(콘텐츠) 다음, 스페셜 해설 잠금 카드(광고 보고 열기
              // CTA 포함) 앞에 배치한다 — 해금 버튼과 직접 인접하지 않도록
              // 위 SizedBox(12) 간격을 그대로 유지한 채 추가로 삽입한다.
              const WebAdInPage(surface: WebAdSurface.guinji, adSlot: ''),
              const SizedBox(height: 12),

              // 스페셜 해설 잠금/해금.
              if (!_specialUnlocked)
                _SpecialLockedCard(
                  unlocking: _unlocking,
                  onUnlockAd: () => _handleUnlock('ad'),
                  onUnlockPouch: () => _handleUnlock('point'),
                )
              else
                _SpecialUnlockedCard(person: person, meta: meta, ohaeng: ohaeng, color: color),

              // [핸드오프 CDetail "자세한 관계 다시 보기" → DeepIntro/
              // DeepResult 이식] 해금 후에만 10장 장문 풀이 전체를 볼 수
              // 있게 한다. 해금 전에는 위 [_SpecialLockedCard]의 광고/포인트
              // CTA가 먼저 나온다 — 핸드오프의 PaySheet(프리패스/복주머니/
              // 광고 3선택)는 이 화면의 2선택(광고/포인트) 해금 플로우로
              // 이미 대체되어 있으므로 중복 결제 단계를 추가하지 않는다.
              // 방금 해금했다면 [GuinjiDeepIntroScreen]을 먼저 거친다
              // ([_openDeep] 참고).
              if (_specialUnlocked) ...[
                const SizedBox(height: 12),
                GmRoseButton(
                  label: '자세한 관계 풀이 10장 전체 보기',
                  icon: Icons.menu_book_outlined,
                  onPressed: _openDeep,
                ),
              ],

              const SizedBox(height: 16),
              GmRoseButton(
                label: '이 관계 공유하기',
                icon: Icons.ios_share,
                onPressed: _handleShare,
              ),
              const SizedBox(height: 12),
              const Text(
                '"재미·참고용" 콘텐츠. 절대적 판단이 아니에요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: GmColors.dim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [핸드오프 CDetail "이렇게 판정했어요" 1:1 이식] `guinjiReasons`(S1~S5
/// 룰트레이스를 미리 풀어쓴 문장, 유형별 고정 3줄)를 S코드 배지 + 문장으로
/// 나열한다. 알 수 없는 키가 와도 빈 리스트 폴백으로 크래시하지 않는다.
class _ReasonsCard extends StatelessWidget {
  const _ReasonsCard({required this.relationKey});

  final String relationKey;

  @override
  Widget build(BuildContext context) {
    final rows = guinjiReasons[relationKey] ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GmColors.card,
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GmLabelMini('이렇게 판정했어요'),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      row[0],
                      style: const TextStyle(
                        fontFamily: GmText.mono,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: GmColors.dim,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      row[1],
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: GmColors.fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.color, required this.label, required this.desc});

  final Color color;
  final String label;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, height: 1.55, color: GmColors.muted),
              children: [
                TextSpan(
                  text: '$label · ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: GmColors.fg),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpecialLockedCard extends StatelessWidget {
  const _SpecialLockedCard({
    required this.onUnlockAd,
    required this.onUnlockPouch,
    this.unlocking = false,
  });

  final VoidCallback onUnlockAd;
  final VoidCallback onUnlockPouch;
  final bool unlocking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GmColors.gold.withValues(alpha: 0.4)),
        gradient: RadialGradient(
          center: const Alignment(0.8, -0.6),
          radius: 1.0,
          colors: [
            GmColors.gold.withValues(alpha: 0.14),
            GmColors.card.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GmLabelMini('SPECIAL · 스페셜 해설', color: GmColors.gold),
          const SizedBox(height: 6),
          const Text(
            '이 관계, 어떻게 대해야 할까',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GmColors.fg),
          ),
          const SizedBox(height: 4),
          const Text(
            '사주 4기둥을 근거로 자세히 풀어드립니다.',
            style: TextStyle(fontSize: 12, height: 1.5, color: GmColors.muted),
          ),
          const SizedBox(height: 12),
          if (unlocking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: GmColors.gold),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onUnlockPouch,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: GmColors.line),
                      foregroundColor: GmColors.fg,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      '복주머니\n50P로 열기',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, height: 1.3, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [GmColors.goldTop, GmColors.gold],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: onUnlockAd,
                        style: TextButton.styleFrom(
                          foregroundColor: GmColors.onFg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '광고 보고\n지금 열기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SpecialUnlockedCard extends StatelessWidget {
  const _SpecialUnlockedCard({
    required this.person,
    required this.meta,
    required this.ohaeng,
    required this.color,
  });

  final GuinjiPerson person;
  final GuinjiRelationMeta meta;
  final GuinjiOhaengMeta? ohaeng;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = meta.label;
    final ohaengText = ohaeng != null ? '${ohaeng!.name}(${ohaeng!.label})' : '오행';
    // [스페셜 해설 콘텐츠 풍부화 — 2026-09] 관계 유형(V2 6종)별 실제 심층
    // 해설/팁을 사용한다("내용이 빈약하다" 리포트 대응). guinjiRelationMetaOf()가
    // 항상 유효한 meta를 반환하므로 null 폴백은 더 이상 필요하지 않다.
    final insight = meta.specialInsight;
    final tips = meta.tips;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GmColors.card,
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GmLabelMini('SPECIAL · 해금됨', color: color),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, height: 1.65, color: GmColors.fg),
              children: [
                const TextSpan(text: '두 분은 '),
                TextSpan(text: label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                const TextSpan(text: '의 결이에요. '),
                TextSpan(text: '${person.name}님이 지닌 '),
                TextSpan(text: ohaengText, style: const TextStyle(color: GmColors.gold)),
                const TextSpan(text: '의 기운을 함께 지녔어요.\n\n'),
                TextSpan(text: insight),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GmColors.gold.withValues(alpha: 0.06),
                  border: Border.all(color: GmColors.gold.withValues(alpha: 0.18)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 11, height: 1.5, color: GmColors.muted),
                    children: [
                      const TextSpan(text: 'Tip. ', style: TextStyle(color: GmColors.gold)),
                      TextSpan(text: tip),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
