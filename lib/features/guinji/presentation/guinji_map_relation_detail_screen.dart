import 'dart:async';

import 'package:flutter/material.dart';
import '../navigation/guinji_page_route.dart';
import 'package:provider/provider.dart';

import '../../../core/util/original_result_capture.dart';

import '../../share/application/share_service.dart';
import '../../share/domain/share_result_model.dart';
import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../../result_access/application/result_access_provider.dart';
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
/// [스페셜 해설 잠금해제 — 06 결제 시트 3택, 2026-12] 핸드오프 `PaySheet`의
/// "프리패스로 보기 / 복주머니로 보기 / 광고 보고 무료로 보기" 3택을 그대로
/// 구현한다. 셋 다 동일한 서버 API(`POST /guinji/unlocks`,
/// [GuinjiProvider.unlock], `method: 'freepass'|'point'|'ad'`)를 호출한다 —
/// 구계열 상세화면과 동일한 백엔드 연동, UI만 새 디자인으로. 프리패스
/// 잔여횟수 표시만 앱 전역 공용 "결과보기 통합 권한 시스템"
/// ([ResultAccessProvider.loadQuote], `contentType: 'guinji'`)을 재사용한다 —
/// 프리패스는 콘텐츠 종류와 무관한 전역 자산(UserPass)이라 별도 조회 API를
/// 새로 만들지 않는다. 복주머니는 귀인지도 전용 가격(서버
/// `PointPolicy('guinji_unlock_special')`이 단독으로 결정·차감)이라 공용
/// quote를 쓰지 않는다. [2026-12 사용자 지시] 가격 숫자를 화면에 노출하지
/// 않도록 "복주머니로 바로 열어요"로 문구를 단순화했다 — 정책/차감 로직은
/// 전혀 변경하지 않았다.
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

  @override
  void initState() {
    super.initState();
    // [프리패스 잔여횟수 조회] 06 결제 시트가 열리기 전에 미리 조회해 두면
    // "보유 N회" 표시가 버튼이 보이는 즉시 나타난다(§8.3 서버 재검증 —
    // 실제 차감은 unlock() 호출 시 서버가 다시 확정한다, 여기서는 표시용).
    if (!_specialUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ResultAccessProvider>().loadQuote(contentType: 'guinji');
      });
    }
  }

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
      // [프리패스 차감 반영] 방금 freepass로 해금했다면 전역 quote를
      // 다시 조회해 다른 화면(06 결제 시트 등)의 "보유 N회" 표시도
      // 즉시 최신 상태로 맞춘다.
      if (method == 'freepass' && mounted) {
        unawaited(
          context.read<ResultAccessProvider>().loadQuote(contentType: 'guinji'),
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.error ?? '해금에 실패했습니다.')));
    }
  }

  // [관계 결과 원본 캡처] 공유 링크가 재구성 화면이 아니라 이 화면 그대로
  // 열리도록 전체 본문을 캡처하는 경계. 상대 이름·생년 등 화면에 보이는
  // 정보가 이미지에 그대로 담기므로 공유 전 별도 공개 동의를 받는다.
  final _originalResultKey = GlobalKey();

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
    // [카카오 OG 결과페이지 공유 — 사용자 피드백] 텍스트만 보내면 카톡에
    // 링크 미리보기(OG)가 붙지 않는다. 서버 공유 시스템(/r/{shareId})에
    // 결과 페이지를 만들어 링크째 공유하고, 실패 시에만 텍스트 공유로 폴백.
    try {
      await ShareService.shareResult(
        context,
        resultType: ShareResultType.relationship,
        title: message,
        description: '${meta.label} · 신통방통 귀인지도',
        // [웹 결과페이지 빈 화면 버그 수정 — 2026-11] 과거에는 각 관계
        // 유형 키에 0/1 플래그만 담아 보냈는데, admin_web 웹 렌더러
        // (RelationshipView)는 사람이 읽을 요약 텍스트(summary)나
        // 하이라이트 문자열을 기대한다 — 플래그만으로는 "관계 분석 내용이
        // 준비되지 않았어요"만 뜬다. 유료 10장 풀이(guinji_deep_text.dart)
        // 전문은 무단 공개가 되므로 넣지 않고, 관계 유형 자체의 공개
        // 소개(meta.long/specialInsight/tips — 유형 설명이지 개인 풀이가
        // 아님)만 요약으로 전달한다.
        // [공유 콘텐츠 부실 버그 근본 수정 — "결과페이지 그대로 가라" 2027-02]
        // 기존에는 관계 유형(TYPE) 공통 설명만 보냈다 — 받는 사람이 보는
        // 화면이 실제 이 화면(아바타·이름·점수·오행·판정근거)과 전혀 다른
        // "공유된 결과"라는 텍스트 요약으로 뜨는 근본 원인이었다. 이제
        // person 인스턴스 데이터(이름/생년/점수/오행 키)까지 함께 보내
        // [SharedResultScreen]이 이 화면과 동일한 카드 레이아웃을 그대로
        // 재구성할 수 있게 한다. 원본 사진/연락처 등 민감정보는 포함하지
        // 않는다(이름·생년 표시 문자열 자체는 이 화면에서도 이미 공개로
        // 보여주는 정보).
        payload: {
          'kind': 'relationship',
          'relationType': meta.key,
          'relationLabel': meta.label,
          'summary': meta.long,
          'highlights': [meta.specialInsight, ...meta.tips],
          'personName': person.name,
          'personBirth': person.birth,
          'score': person.score,
          'ohaeng': person.ohaeng,
          'note': person.note,
        },
        subject: '신통방통 귀인지도',
        originalResultKey: _originalResultKey,
      );
    } catch (_) {
      // 링크 생성 실패 시에만 텍스트 공유로 폴백.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('결과 공유에 실패했어요. 다시 시도해주세요.')));
      }
    }
  }

  // [핸드오프 `CMain` `onDeep` 1:1 이식] 방금 해금했다면
  // [GuinjiDeepIntroScreen](풀이 준비 애니메이션)을 먼저 보여주고, 이미
  // 해금되어 있던 관계를 다시 볼 때는 인트로를 건너뛰고 곧바로
  // [GuinjiDeepResultScreen]으로 이동한다.
  void _openDeep() {
    final ownerName = context.read<GuinjiProvider>().mapName ?? '나';
    Navigator.of(context).push(
      guinjiPageRoute(
        _justUnlocked
            ? GuinjiDeepIntroScreen(
                person: widget.person,
                ownerName: ownerName,
                onShare: _handleShare,
              )
            : GuinjiDeepResultScreen(
                person: widget.person,
                ownerName: ownerName,
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
      body: OriginalResultBody(
        captureKey: _originalResultKey,
        background: GmColors.bg,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero — 아바타 + 이름 + 관계 라벨 + 점수.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 20,
                ),
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
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.7,
                        color: GmColors.fg,
                      ),
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
                          border: Border.all(
                            color: ohaeng.color.withValues(alpha: 0.5),
                          ),
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GmColors.muted,
                                ),
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

              // 스페셜 해설 잠금/해금 — 06 결제 시트 3택(프리패스/복주머니/광고).
              if (!_specialUnlocked)
                Consumer<ResultAccessProvider>(
                  builder: (context, resultAccess, _) {
                    final quote = resultAccess.quote;
                    return _SpecialLockedCard(
                      unlocking: _unlocking,
                      freePassRemaining: quote?.freePassRemaining ?? 0,
                      freePassHasLegacyUnlimited:
                          quote?.freePassHasLegacyUnlimited ?? false,
                      freePassAvailable: quote?.freePassAvailable ?? false,
                      onUnlockFreePass: () => _handleUnlock('freepass'),
                      onUnlockAd: () => _handleUnlock('ad'),
                      onUnlockPouch: () => _handleUnlock('point'),
                    );
                  },
                )
              else
                _SpecialUnlockedCard(
                  person: person,
                  meta: meta,
                  ohaeng: ohaeng,
                  color: color,
                ),

              // [핸드오프 CDetail 하단 버튼 1:1 이식] JSX는 "공유"(좌측
              // 104px, 테두리만)과 "더 자세한 관계 보기"/"자세한 관계 다시
              // 보기"(우측 flex:1, 채움)를 **항상 나란히** 배치한다(해금
              // 전후 모두 버튼은 1쌍만 존재, 레이블만 바뀐다). 해금 전에는
              // 위 [_SpecialLockedCard]가 핸드오프 `PaySheet`(모달)를
              // 인라인 카드로 이미 펼쳐 보여주므로, "더보기" 버튼은 해금
              // 후(`_openDeep`, 10장 풀이로 이동)에만 의미가 있다 —
              // 잠금 상태에서는 "공유" 버튼만 전체 폭으로 둔다.
              const SizedBox(height: 16),
              if (_specialUnlocked)
                Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: OutlinedButton(
                        onPressed: _handleShare,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GmColors.fg,
                          side: const BorderSide(color: GmColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                          ),
                        ),
                        child: const Text(
                          '공유',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GmRoseButton(
                        label: '자세한 관계 풀이 10장 전체 보기',
                        icon: Icons.menu_book_outlined,
                        onPressed: _openDeep,
                      ),
                    ),
                  ],
                )
              else
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
  const _MomentRow({
    required this.color,
    required this.label,
    required this.desc,
  });

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
              style: const TextStyle(
                fontSize: 12,
                height: 1.55,
                color: GmColors.muted,
              ),
              children: [
                TextSpan(
                  text: '$label · ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GmColors.fg,
                  ),
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

/// [핸드오프 `PaySheet`(06 결제 시트) 1:1 이식] "여는 방법을 골라 주세요"
/// 3택 — ① 通 프리패스로 보기 ② 福 복주머니로 보기 ③ ☾ 광고 보고 무료로
/// 보기. 핸드오프는 별도 바텀시트 화면(`PaySheet`)이지만, 이 화면에서는
/// 기존 인라인 잠금 카드 안에 그대로 3개 옵션 행으로 배치한다(동일한
/// 선택→해금 흐름, 모달을 한 겹 더 띄우지 않아 더 빠르게 열림).
class _SpecialLockedCard extends StatefulWidget {
  const _SpecialLockedCard({
    required this.onUnlockFreePass,
    required this.onUnlockAd,
    required this.onUnlockPouch,
    required this.freePassRemaining,
    required this.freePassHasLegacyUnlimited,
    required this.freePassAvailable,
    this.unlocking = false,
  });

  final VoidCallback onUnlockFreePass;
  final VoidCallback onUnlockAd;
  final VoidCallback onUnlockPouch;

  /// [ResultAccessProvider.quote] 공용 조회 결과 — 프리패스는 콘텐츠와
  /// 무관한 전역 자산이라 귀인지도 전용 조회 API를 새로 만들지 않는다.
  final int freePassRemaining;
  final bool freePassHasLegacyUnlimited;
  final bool freePassAvailable;
  final bool unlocking;

  @override
  State<_SpecialLockedCard> createState() => _SpecialLockedCardState();
}

/// 핸드오프 `PaySheet`의 `pick` 상태(기본 선택 'pass') — 선택한 항목만
/// 금색 테두리로 강조되고, 광고/프리패스 선택에 따라 하단 CTA 문구가
/// "프리패스 1회로 열기" / "광고 보고 열기"로 바뀐다. 복주머니는 핸드오프와
/// 동일하게 누르는 즉시 해금(별도 확정 버튼을 거치지 않음) — 기존
/// 귀인지도 해금 플로우(`_handleUnlock`)와 그대로 맞춘다.
enum _PayPick { freepass, ad }

class _SpecialLockedCardState extends State<_SpecialLockedCard> {
  _PayPick _pick = _PayPick.freepass;

  String get _freePassSubLabel {
    if (widget.freePassHasLegacyUnlimited && widget.freePassRemaining <= 0) {
      return '프리패스 1회 사용 · 무제한 이용중';
    }
    return '프리패스 1회 사용';
  }

  String get _freePassRightLabel {
    if (widget.freePassHasLegacyUnlimited && widget.freePassRemaining <= 0) {
      return '보유중';
    }
    return '보유 ${widget.freePassRemaining}회';
  }

  @override
  void didUpdateWidget(covariant _SpecialLockedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 프리패스를 쓸 수 없게 되면(조회 완료 후 0회) 기본 선택을 광고로
    // 옮겨 둔다 — 비활성 옵션이 선택된 채로 남아 있지 않도록.
    if (!widget.freePassAvailable && _pick == _PayPick.freepass) {
      _pick = _PayPick.ad;
    }
  }

  void _handlePrimaryCta() {
    if (_pick == _PayPick.freepass) {
      widget.onUnlockFreePass();
    } else {
      widget.onUnlockAd();
    }
  }

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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: GmColors.fg,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '사주 4기둥을 근거로 자세히 풀어드립니다.',
            style: TextStyle(fontSize: 12, height: 1.5, color: GmColors.muted),
          ),
          const SizedBox(height: 14),
          const Text(
            '여는 방법을 골라 주세요',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: GmColors.dim,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.unlocking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: GmColors.gold,
                  ),
                ),
              ),
            )
          else ...[
            // ① 通 프리패스로 보기.
            _PayOptionTile(
              icon: const _IcoPass(),
              title: '프리패스로 보기',
              sub: _freePassSubLabel,
              right: _freePassRightLabel,
              selected: _pick == _PayPick.freepass,
              disabled: !widget.freePassAvailable,
              onTap: () => setState(() => _pick = _PayPick.freepass),
            ),
            const SizedBox(height: 8),
            // ② 福 복주머니로 보기 — [2026-12 사용자 지시로 가격 숫자 UI
            // 삭제] 화면에 하드코딩된 "50개가 필요해요" 문구를 제거한다
            // (실제 차감 가격은 여전히 서버 `PointPolicy('guinji_unlock_
            // special')`이 단독으로 결정·검증하며, 이 UI 텍스트 변경은
            // 그 정책/금액 자체를 전혀 바꾸지 않는다 — 단지 가격을 화면에
            // 노출하지 않을 뿐). 핸드오프 s11 "복주머니 정책: 잔액 UI에
            // '+충전' 버튼 금지"는 그대로 지켜 충전 버튼은 달지 않는다.
            _PayOptionTile(
              icon: const _IcoPouch(),
              title: '복주머니로 보기',
              sub: '복주머니로 바로 열어요',
              right: '',
              selected: false,
              disabled: false,
              onTap: widget.onUnlockPouch,
            ),
            const SizedBox(height: 8),
            // ③ ☾ 광고 보고 무료로 보기.
            _PayOptionTile(
              icon: const _IcoAd(),
              title: '광고 보고 무료로 보기',
              sub: '짧은 광고 한 편이면 열려요',
              right: '무료',
              selected: _pick == _PayPick.ad,
              disabled: false,
              onTap: () => setState(() => _pick = _PayPick.ad),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [GmColors.goldTop, GmColors.gold],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextButton(
                  onPressed: _handlePrimaryCta,
                  style: TextButton.styleFrom(
                    foregroundColor: GmColors.onFg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    _pick == _PayPick.freepass ? '프리패스 1회로 열기' : '광고 보고 열기',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 핸드오프 `PayOption` 1:1 이식 — 아이콘 + 제목/부제 + 우측 보유정보,
/// 선택 시 금색 테두리+그라데이션 배경, 비활성 시 반투명 처리.
class _PayOptionTile extends StatelessWidget {
  const _PayOptionTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.right,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String sub;
  final String right;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? GmColors.gold.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: selected
                  ? GmColors.gold.withValues(alpha: 0.55)
                  : GmColors.hair,
            ),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GmColors.fg,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: GmColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (right.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    right,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? GmColors.fg : GmColors.dim,
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

/// 通 프리패스 아이콘 — 핸드오프 `IcoPass`(금색 그라데이션 정사각 배지).
class _IcoPass extends StatelessWidget {
  const _IcoPass();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3D48A), Color(0xFFC9973E)],
        ),
      ),
      child: const Text(
        '通',
        style: TextStyle(
          fontFamily: GmText.display,
          fontSize: 19,
          fontWeight: FontWeight.w900,
          color: Color(0xFF3A2508),
        ),
      ),
    );
  }
}

/// 福 복주머니 아이콘 — 핸드오프 `IcoPouch`(붉은 복주머니 + 한자 인장).
class _IcoPouch extends StatelessWidget {
  const _IcoPouch();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30,
            height: 28,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFC0332B),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          Positioned(
            top: 2,
            child: Container(
              width: 14,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE9C46A),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            bottom: 7,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE9C46A), width: 1.1),
              ),
              child: const Text(
                '福',
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE9C46A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ☾ 광고 아이콘 — 핸드오프 `IcoAd`(테두리 원 + 달 기호).
class _IcoAd extends StatelessWidget {
  const _IcoAd();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: GmColors.line),
      ),
      child: const Text(
        '☾',
        style: TextStyle(fontSize: 17, color: GmColors.muted),
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
    final ohaengText = ohaeng != null
        ? '${ohaeng!.name}(${ohaeng!.label})'
        : '오행';
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
              style: const TextStyle(
                fontSize: 13,
                height: 1.65,
                color: GmColors.fg,
              ),
              children: [
                const TextSpan(text: '두 분은 '),
                TextSpan(
                  text: label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '의 결이에요. '),
                TextSpan(text: '${person.name}님이 지닌 '),
                TextSpan(
                  text: ohaengText,
                  style: const TextStyle(color: GmColors.gold),
                ),
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
                  border: Border.all(
                    color: GmColors.gold.withValues(alpha: 0.18),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: GmColors.muted,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Tip. ',
                        style: TextStyle(color: GmColors.gold),
                      ),
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
