// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_result_screen.dart
// [신통방통 궁합지도 개발 지시서 §2④/§3] 궁합 결과 화면(초대자 본인 전용).
//
// 도달 경로: `GunghapInviteScreen._checkStatus()`에서 상대방이 이미
// 참여한 것이 확인되면 push된다. `resultId`만 전달받고, 이 화면이
// 직접 `GunghapProvider.fetchResult(resultId)`를 호출해 데이터를
// 가져온다(인증 필수·소유자 전용 API — AuthTokenStore.authHeader()가
// 자동으로 포함됨, GunghapRepository.fetchResult 참고).
//
// [과금 원칙 — 절대 준수] 상세 보고서 비용은 100 복주머니 고정이며,
// 서버(`/unlock`)가 멱등이다. 이 화면은 `result['unlocked'] == true`
// 여부만 보고 잠금해제 CTA 노출 여부를 결정한다 — 이미 해금된 경우
// 버튼 자체를 숨기므로 재열람 시 중복 호출/중복 차감 경로가 UI
// 레벨에서도 존재하지 않는다.
//
// [궁합지도 Phase 4 §5 — 결과 이미지 갤러리 저장] 귀인지도
// (`guinji_result_card_screen.dart`)와 동일한 검증된 패턴을 그대로
// 재사용한다: `RepaintBoundary` + `captureOriginalResult`/
// `saveOriginalResult`(core/util/original_result_capture.dart) +
// `buildSaveFileName('gunghap', resultId)`. [GHScreen]은 이미 `child`를
// `SingleChildScrollView`로 감싸므로(gh_screen.dart 참고), 그 안에서
// `RepaintBoundary`를 직접 쓰면 뷰포트 높이가 아니라 콘텐츠의 "실제
// 전체 높이"로 렌더링된 레이어를 그대로 캡처한다 — 8개 분야 등급 +
// (해금 시) 8개 상세 리포트까지 아무리 길어져도 잘리지 않는다.
//
// [v4 S17 UI 재작성 — 2026-?? 핸드오프 반영] 00_DEV_MAPPING.md §5 S17
// 명세(구조표 15, 13개 항목) + S17_result_owner.png 디자인에 맞춰 화면
// 레이아웃을 전면 재작성한다. 아래 과금/저장/환불/분기 로직은
// **절대 변경하지 않는다**(파일 전역에 각 블록마다 주석으로 재확인):
//   · `_unlock()` — ResultGateController 기반 결제 게이트
//   · `_saveImage()`/`captureOriginalResult` — 이미지 저장
//   · `_RefundNoticeBanner` — 환불 안내
//   · majorId/subName 기반 섹션 타이틀 분기
// UI만 교체한다: 히어로 이미지(kenBurns) + GHScoreRing136 걸침 +
// 분야칩/타이틀 + PersonPair + 점선 지도 버튼 + 핵심요약카드(glow) +
// 프리미엄 티저카드 + Footer(공유+구매) 신규 추가.
//
// [S17 "공유" 버튼 처리 방침 — 이번 턴 결정] S24(공유 카드 전용 화면)가
// 아직 구현되지 않았으므로, 신규 서버 API나 화면을 추가하지 않고 이미
// 이 화면이 쓰고 있는 `captureOriginalResult`(동일 RepaintBoundary 재사용)
// + 기존 공용 `ShareService.shareImageDirectly`(features/share, 5개
// 결과 화면이 이미 쓰는 검증된 패턴 — 웹에서는 "웹에서는 결과페이지
// 링크로 공유해주세요" 안내로 자동 분기, 앱에서는 OS 공유 시트)를 그대로
// 재사용한다. 기존 "결과 이미지로 저장하기" 버튼은 Footer가 스펙대로
// 「공유 · 구매」 2분할로 바뀌면서 자리를 잃으므로, 스펙 1번
// "AppBar ← (홈) · 「{세부명} 결과」 · 우 ↗(S24)" 슬롯에 임시로
// 배치한다(S24가 구현되면 그때 원래 의도대로 공유 화면으로 이동 예정 —
// 저장 로직 자체는 1바이트도 바뀌지 않았다).
// ═══════════════════════════════════════════════════════════════
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/util/original_result_capture.dart';
import '../../../core/util/save_filename.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/result_text_scale_overlay.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';
import '../../share/application/share_service.dart';
import '../application/gunghap_provider.dart';
import '../domain/gunghap_data.dart';
import '../gate/result_gate.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/cat_icon.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_score_ring.dart';
import '../widgets/gh_screen.dart';
import '../widgets/person_pair.dart';
import '../widgets/star_map.dart';
import 'gunghap_home_screen.dart';

class GunghapResultScreen extends StatefulWidget {
  const GunghapResultScreen({super.key, required this.resultId});
  final String resultId;

  @override
  State<GunghapResultScreen> createState() => _GunghapResultScreenState();
}

class _GunghapResultScreenState extends State<GunghapResultScreen> {
  bool _loading = true;
  // [궁합지도 Phase 4 §4 — 결과 재열람] 궁합스토리에서 과거 기록을 다시
  // 열람할 때, 그 사이 결과가 삭제됐을 수 있다(DELETE
  // /api/public/gunghap/results/{resultId} 이미 Phase 3에서 구현/배포됨).
  // 서버는 이 경우 404 + code:'NOT_FOUND'를 반환하므로(fetchResult가
  // decoded['code']를 그대로 전달), "다시 시도" 버튼이 의미 없는
  // 전용 안내 문구 + 목록으로 돌아가기 동작을 구분해서 보여준다.
  bool _deletedNotFound = false;
  // [Phase 4 §5 — 결과 이미지 갤러리 저장] 결과 콘텐츠 전체를 감싸는
  // RepaintBoundary 캡처 키. `_ResultBody` 전체(히어로/요약/8개 분야
  // 등급/상세 리포트까지)를 하나의 레이어로 캡처한다. [S17 공유 버튼]도
  // 동일한 키를 재사용한다(별도 캡처 레이어를 새로 만들지 않음).
  final _originalResultKey = GlobalKey();
  bool _savingImage = false;
  bool _sharing = false;
  // [S17 신규 — "✦ 상세 보고서 다시 보기"] 해금 후 Footer 버튼이 눌리면
  // 이미 화면에 그려진 DETAIL REPORT 섹션으로 스크롤만 이동한다(이
  // 프로젝트는 상세 보고서를 별도 화면으로 분리하지 않고 같은 화면에
  // 이어서 렌더링하는 구조이므로, "다시 보기"는 곧 "그 위치로 스크롤"을
  // 의미한다).
  final _detailSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _deletedNotFound = false;
      });
    }
    final provider = context.read<GunghapProvider>();
    final ok = await provider.fetchResult(widget.resultId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      final code = provider.errorCode;
      if (code == 'UNAUTHORIZED') {
        AppToast.show(context, '로그인이 필요합니다.', isError: true);
        Navigator.of(context).pushNamed('/login');
      } else if (code == 'FORBIDDEN') {
        AppToast.show(context, '이 결과를 열람할 권한이 없습니다.', isError: true);
      } else if (code == 'NOT_FOUND') {
        // [삭제된 결과 접근 시 안내] 궁합스토리에서 삭제된 기록을
        // 다시 눌렀거나, 다른 기기에서 이미 삭제된 경우.
        setState(() => _deletedNotFound = true);
        AppToast.show(context, '이미 삭제된 궁합 결과예요.', isError: true);
      } else if (code == 'NETWORK_ERROR') {
        // [긴급 검수 지시 §4] 연결 실패는 전용 메시지 + 재시도 버튼으로
        // 안내한다. 화면 본문에도 _ErrorState(다시 시도 버튼)가 이미
        // 뜨므로 토스트는 보조 안내 역할을 한다.
        AppToast.show(
          context,
          provider.error ?? '서비스 연결이 원활하지 않습니다.',
          isError: true,
          onRetry: _load,
        );
      } else {
        AppToast.show(
          context,
          provider.error ?? '결과를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
          isError: true,
          onRetry: _load,
        );
      }
    }
  }

  // [궁합지도 핸드오프 v4 §5 S19~S20/S33~S41 — 결제 게이트] 기존에는
  // 버튼을 누르면 확인 절차 없이 바로 차감+생성이 동시에 일어났다. v4
  // 디자인은 "결제 전 확인(S19)" 시트를 먼저 보여주고, 실제 차감/생성은
  // [ResultGateController.pay]가 수행한다 — 로직(100 복주머니 고정,
  // `GunghapProvider.unlock()` 단일 호출, 서버 멱등)은 전혀 바꾸지
  // 않고 그 앞뒤에 확인/진행 UI만 덧붙인다([result_gate.dart] 상단
  // 주석의 아키텍처 차이 설명 참고 — 서버에 job/stage 스트리밍이 없어
  // v4 참고코드를 그대로 쓰지 않고 이 프로젝트의 실제 API에 맞게
  // 재설계했다). [S17 UI 재작성 — 절대 변경 금지] 이 함수는 한 글자도
  // 바뀌지 않았다.
  Future<void> _unlock() async {
    final provider = context.read<GunghapProvider>();
    final pouch = context.read<LuckPouchProvider>();
    final result = provider.result;
    if (result == null) return;

    final unlockCost = (result['unlockCost'] as num?)?.toInt() ?? 100;
    final ownerName = result['ownerName'] as String? ?? '나';
    final guestName = result['guestName'] as String? ?? '상대방';
    final subName =
        result['subName'] as String? ??
        (result['majorId'] != null ? ghMajorById(result['majorId'] as String).shortName : '궁합');

    final gate = ResultGateController(
      provider: provider,
      resultId: widget.resultId,
      balance: pouch.balance,
      price: unlockCost,
      openReport: () {
        // [v4 설계] 이미 이 화면(GunghapResultScreen)이 provider.result를
        // watch하고 있으므로, pay() 성공 시 provider가 _result를
        // unlocked:true로 갱신하는 즉시 이 화면이 자동으로 재빌드돼
        // 상세 보고서 섹션을 보여준다 — 별도 네비게이션이 필요 없다.
      },
      openPouch: () {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false, arguments: 2);
      },
    );

    if (!gate.start()) return;
    await showGHGateSheet(context, gate, me: ownerName, partner: guestName, sub: subName);
    if (!mounted) return;

    // [재화 단일화 원칙] 서버 원장을 다시 조회해 앱 전역 잔액 표시를
    // 동기화한다(GunghapProvider는 결제를 직접 다루지 않음 — 파일 상단
    // 주석/GunghapProvider.unlock() 문서 참고). gate가 실제로 결제를
    // 수행했을 때만 의미가 있지만, 매번 호출해도 변동이 없으면 그대로
    // 유지되므로 안전하다.
    await pouch.load();
    gate.dispose();
  }

  // [Phase 4 §5 — 결과 이미지 갤러리 저장] 귀인지도
  // (`guinji_result_card_screen.dart._saveImage`)와 완전히 동일한
  // 구조: captureOriginalResult/saveOriginalResult 공용 유틸을 그대로
  // 재사용하고, 성공/실패 토스트도 그 유틸이 전담한다(이 화면에서
  // 별도 토스트 문구를 만들지 않음 — REQ-05/REQ-09 표준 유지).
  // 파일명은 공통 규칙(`sintong_gunghap_{resultId}_{yyyyMMdd_HHmmss}`)을
  // 그대로 따른다. [S17 UI 재작성] 호출 위치만 Footer → AppBar 아이콘으로
  // 옮겼을 뿐, 이 함수 내부는 한 글자도 바뀌지 않았다.
  Future<void> _saveImage() async {
    if (_savingImage) return;
    setState(() => _savingImage = true);
    try {
      await saveOriginalResult(
        context,
        _originalResultKey,
        name: buildSaveFileName('gunghap', widget.resultId),
      );
    } finally {
      if (mounted) setState(() => _savingImage = false);
    }
  }

  // [S17 신규 — Footer "공유" 버튼] 00_DEV_MAPPING.md §5 S17 항목 12
  // "Footer: Secondary 92 「공유」". S24(공유 카드 전용 화면)가 아직
  // 구현되지 않아, 이미 검증된 공용 `ShareService.shareImageDirectly`
  // (5개 결과 화면이 쓰는 패턴 — 웹은 자동으로 "결과페이지 링크로
  // 공유해주세요" 안내, 앱은 OS 공유 시트로 PNG 전달)를 그대로 호출한다.
  // 캡처는 저장 버튼과 동일한 `_originalResultKey` 레이어를 재사용하므로
  // 새 RepaintBoundary를 추가하지 않는다.
  Future<void> _shareResult() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final result = context.read<GunghapProvider>().result;
      final ownerName = result?['ownerName'] as String? ?? '나';
      final guestName = result?['guestName'] as String? ?? '상대방';
      final subName =
          result?['subName'] as String? ??
          (result?['majorId'] != null
              ? ghMajorById(result?['majorId'] as String?).name
              : '궁합');
      final bytes = await captureOriginalResult(_originalResultKey);
      if (!mounted) return;
      await ShareService.shareImageDirectly(
        context,
        '$ownerName님과 $guestName님의 $subName 결과',
        bytes,
      );
    } catch (_) {
      if (mounted) {
        AppToast.show(context, '결과 이미지를 준비하지 못했어요. 다시 시도해주세요.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _openMapHighlight() {
    // [S17 §5 항목 7 — "지도에서 보기 › → S01(해당 노드 강조)"] 특정
    // 노드를 강조해서 여는 기능은 S01(궁합지도 홈) 쪽에 아직 구현돼 있지
    // 않으므로(이번 턴 범위 밖), 우선 S01로 이동만 시킨다 — 신규 화면/
    // API 없이 기존 홈 진입 동선만 재사용한다.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GunghapHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();
    final result = provider.result;
    final showResult = !_loading && result != null;
    final unlocked = result?['unlocked'] == true;
    final unlockCost = (result?['unlockCost'] as num?)?.toInt() ?? 100;
    final majorId = result?['majorId'] as String?;
    final subName = result?['subName'] as String?;
    final titleText = subName ?? (majorId != null ? ghMajorById(majorId).name : '궁합');

    return ResultTextScaleOverlay(
      child: GHScreen(
        bottomNav: const MainBottomNavBar(currentIndex: 0),
        appBar: GHAppBar(
          title: showResult ? '$titleText 결과' : '궁합 결과',
          onBack: () => Navigator.of(context).pop(),
          actions: [
            if (showResult)
              GHIconButton(
                glyph: _savingImage ? '…' : '↓',
                onTap: _savingImage ? () {} : _saveImage,
                label: '결과 이미지로 저장하기',
              ),
          ],
        ),
        // [S17 §5 항목 12 — Footer 2분할] Secondary 「공유」 + Primary
        // 「❖ 상세 궁합 보고서 확인하기」(해금 전) / 「✦ 상세 보고서 다시
        // 보기」(해금 후, 상세 섹션으로 스크롤). 결과가 아직 없으면(로딩/
        // 에러) 저장/공유할 것이 없으므로 footer를 아예 숨긴다.
        footer: showResult
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 92,
                    child: GHButton(
                      label: _sharing ? '…' : '공유',
                      variant: GHButtonVariant.secondary,
                      onPressed: _sharing ? null : _shareResult,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: unlocked
                        ? GHButton(
                            label: '✦ 상세 보고서 다시 보기',
                            onPressed: () {
                              final ctx = _detailSectionKey.currentContext;
                              if (ctx != null) {
                                Scrollable.ensureVisible(
                                  ctx,
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            },
                          )
                        : GHButton(
                            label: '❖ 상세 궁합 보고서 확인하기',
                            onPressed: _unlock,
                            trailing: GHPricePill(unlockCost),
                          ),
                  ),
                ],
              )
            : null,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: GHColors.gold),
                ),
              )
            : result == null
            ? (_deletedNotFound
                  ? _ErrorState(
                      message: '이미 삭제된 궁합 결과예요.\n궁합스토리 목록으로 돌아가 주세요.',
                      retryLabel: '목록으로 돌아가기',
                      onRetry: () => Navigator.of(context).pop(),
                    )
                  : _ErrorState(
                      onRetry: () {
                        setState(() => _loading = true);
                        _load();
                      },
                    ))
            // [Phase 4 §5] RepaintBoundary로 결과 콘텐츠 전체를 감싼다.
            // GHScreen.child는 이미 SingleChildScrollView 안에 배치되므로
            // (gh_screen.dart 참고) 별도 스크롤뷰를 추가하지 않고, 이
            // RepaintBoundary 레이어 자체가 "화면에 실제로 그려진 전체
            // 높이"를 그대로 캡처 대상으로 갖는다 — 8개 분야 등급 카드와
            // (해금 후) 8개 상세 리포트까지 더해져 화면보다 훨씬 길어져도
            // 스크롤 뷰포트가 아니라 콘텐츠 전체 높이 기준으로 캡처되어
            // 잘리지 않는다(ColoredBox로 배경색을 명시해 투명 영역이
            // PNG에서 검게 찍히지 않도록 한다).
            : RepaintBoundary(
                key: _originalResultKey,
                child: ColoredBox(
                  color: GHColors.bg2,
                  child: _ResultBody(
                    result: result,
                    unlocking: false,
                    onUnlock: _unlock,
                    onOpenMap: _openMapHighlight,
                    detailSectionKey: _detailSectionKey,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.onRetry,
    this.message = '결과를 불러오지 못했어요.',
    this.retryLabel = '다시 시도',
  });
  final VoidCallback onRetry;
  final String message;
  final String retryLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: GHText.ui(size: 14, color: GHColors.gray),
        ),
        const SizedBox(height: 16),
        GHButton(label: retryLabel, onPressed: onRetry, expand: false),
      ],
    ),
  );
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.result,
    required this.unlocking,
    required this.onUnlock,
    required this.onOpenMap,
    required this.detailSectionKey,
  });
  final Map<String, dynamic> result;
  final bool unlocking;
  final VoidCallback onUnlock;
  final VoidCallback onOpenMap;
  final GlobalKey detailSectionKey;

  @override
  Widget build(BuildContext context) {
    final ownerName = result['ownerName'] as String? ?? '나';
    final guestName = result['guestName'] as String? ?? '상대방';
    final relationTypeLabel = result['relationTypeLabel'] as String?;
    final relationTypeDesc = result['relationTypeDesc'] as String?;
    final chemistryScore = result['chemistryScore'];
    final score = chemistryScore is num ? chemistryScore.toInt() : null;
    final band = score != null ? GHBand.of(score) : null;
    final unlocked = result['unlocked'] == true;
    final unlockCost = (result['unlockCost'] as num?)?.toInt() ?? 100;
    // [2026-11 환불 UI 보완 지시] 서버가 LLM 생성에 실패해 100P를 자동
    // 환불한 경우(`refunded:true`), 해금된 상세 보고서가 실제로는
    // "참고용 템플릿 해석"임을 사용자에게 명확히 알린다. 정상 LLM
    // 해석(`refunded:false`)일 때는 배너를 아예 렌더링하지 않는다 —
    // 과금/환불 로직 자체는 서버가 이미 끝낸 사실을 화면에 반영만 한다.
    final refunded = unlocked && result['refunded'] == true;
    final categoriesRaw = result['categories'];
    final categories = categoriesRaw is List
        ? categoriesRaw.whereType<Map>().toList()
        : const <Map>[];
    // [버그 수정 — 대표 신고 "궁합지도 초대장 주제에 맞는 궁합을 본다고
    // 해야지 8개본다고 돼어있잔아"] 서버(`GET /results/{resultId}`,
    // `filterStoredByMajorId()`)가 초대 생성 시 선택된 majorId 기준으로
    // 이미 categories를 1개로 필터링해 내려주므로, 화면도 majorId가
    // 있으면 선택된 주제 라벨만 보여준다(레거시 majorId=null은 기존처럼
    // "8개 분야"로 표시).
    final majorId = result['majorId'] as String?;
    final major = ghMajorById(majorId);
    // [2026-11 궁합 세부주제 표시 버그 수정 — 대표 신고 "성격/대화/감정
    // 궁합을 따로 다 봤는데 다 똑같다" / 스크린샷 실증("썸 궁합"을
    // 고르고도 항상 "궁합 결과예요"로만 표시됨)] 사용자가 고른 세부
    // 주제(subName, 예: "썸 궁합")가 있으면 타이틀/섹션명/잠금해제 안내
    // 문구 모두에 그대로 반영한다(서버 변경 없이 Flutter만으로 가능).
    final subName = result['subName'] as String?;
    final subDisplay = subName ?? major.name;
    final freeSectionTitle = subName != null
        ? '$subName 등급'
        : majorId != null
        ? '${major.shortName} 궁합 등급'
        : '8개 분야 궁합 등급';
    final detailRaw = result['detail'];
    final detail = detailRaw is List
        ? detailRaw.whereType<Map>().toList()
        : const <Map>[];
    final detailByCategory = {
      for (final d in detail)
        if (d['categoryId'] != null) d['categoryId'] as String: d,
    };

    // [v4 S17] PersonPair/ElementBars 전용 — `owner`/`member` 신규 필드
    // (하위호환 추가, admin_web 3개 라우트에 이미 함께 추가됨)가 없는
    // 구버전 응답이면 PersonPair가 조용히 생략된다.
    final ownerSaju = GhPersonSaju.fromMap(result['owner']);
    final memberSaju = GhPersonSaju.fromMap(result['member']);

    // [v4 S17 항목 8 — 핵심 요약 카드 키워드 칩 3개] 서버에 전용 키워드
    // 필드가 없으므로(00_DEV_MAPPING §7에 신규 필드 요구 없음), 이미
    // 내려오는 실제 데이터(분야 축약명 · 점수 밴드 라벨 · 선택 분야의
    // 등급)만으로 구성한다 — 가짜 데이터를 지어내지 않는다.
    final majorCategoryGrade = categories
        .firstWhere(
          (c) => c['categoryId'] == majorId,
          orElse: () => const {},
        )['grade'] as String?;
    final summaryKeywords = <String>[
      major.short,
      if (band != null) band.label,
      if (majorCategoryGrade != null) '$majorCategoryGrade등급',
    ].take(3).toList();

    final heroArt = subName != null
        ? ghArtSub(major.id, subName)
        : ghArtSquare(major.id);
    final heroAlign = subName != null ? ghArtAlign(major.id, subName) : 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── §5 항목 2-3: 히어로(kenBurns) + GHScoreRing136 걸침 ──
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(GHRadius.hero),
              child: SizedBox(
                height: 280,
                width: double.infinity,
                child: _KenBurnsHero(
                  assetPath: heroArt,
                  alignY: heroAlign,
                ),
              ),
            ),
            Positioned(
              bottom: -56,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GHMono('${ghSubShort(subDisplay)} 점수', color: GHColors.gray),
                  const SizedBox(height: 4),
                  if (score != null && band != null)
                    GHScoreRing(score: score, sub: band.label),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 66),
        // ── §5 항목 4: GHTier(무료/프리미엄) + 분야 칩 ──
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              GHChip(label: unlocked ? '✦ 프리미엄 해금' : '○ 무료 결과', active: unlocked),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GHColors.accent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(GHRadius.chip),
                  border: Border.all(color: GHColors.accent.withValues(alpha: .5)),
                ),
                child: Text(
                  '${major.hanja} · ${major.name}',
                  style: GHText.ui(size: 12, weight: FontWeight.w600, color: GHColors.accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ── §5 항목 5: resultTitle(그라데이션) + 서브타이틀 ──
        Center(
          child: ShaderMask(
            shaderCallback: (rect) => GHGradients.title.createShader(rect),
            child: Text(
              subDisplay,
              textAlign: TextAlign.center,
              style: GHText.resultTitle(size: 28, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '$ownerName님과 $guestName님의 결과예요',
            textAlign: TextAlign.center,
            style: GHText.cardTitle(size: 16, color: GHColors.fg),
          ),
        ),
        const SizedBox(height: 22),
        // ── §5 항목 6: StarMap(2인) + PersonPair ──
        AspectRatio(
          aspectRatio: 4 / 3,
          child: StarMap(aName: ownerName, bName: guestName, draw: true),
        ),
        if (ownerSaju != null && memberSaju != null) ...[
          const SizedBox(height: 18),
          PersonPair(
            ownerName: ownerName,
            memberName: guestName,
            owner: ownerSaju,
            member: memberSaju,
          ),
        ],
        const SizedBox(height: 18),
        // ── §5 항목 7: 점선 버튼 「지도에서 보기」 ──
        _DashedMapButton(partnerName: guestName, onTap: onOpenMap),
        const SizedBox(height: 22),
        // ── §5 항목 8: 핵심 요약 카드(glow) ──
        if (relationTypeDesc != null) ...[
          _GlowSummaryCard(
            subDisplay: subDisplay,
            relationTypeLabel: relationTypeLabel,
            relationTypeDesc: relationTypeDesc,
            keywords: summaryKeywords,
          ),
          const SizedBox(height: 22),
        ],
        // [§5 항목 9 — 항목별 점수 카드(3축)] 00_DEV_MAPPING.md §7 데이터
        // 바인딩 표가 "신규 필요 result.axes[]{title,score} · 카드
        // 숨김(§12-2)"로 명시한다 — 서버에 해당 필드가 없으므로(admin_web
        // 응답에 axes가 전혀 없음을 확인) §12-2 fallback 규칙대로 이
        // 카드는 렌더링하지 않는다(가짜 점수를 만들어 보여주지 않음).
        //
        // 대신 서버가 실제로 내려주는 분야별 등급 데이터(FREE RESULT)는
        // 기존 기능이므로 그대로 유지한다(§6 "기존 기능을 임의로 줄이지
        // 않는다" 원칙).
        GHSectionHead(mono: 'FREE RESULT', title: freeSectionTitle),
        for (final c in categories) ...[
          _CategoryRow(
            categoryId: c['categoryId'] as String?,
            grade: c['grade'] as String?,
            detail: detailByCategory[c['categoryId']],
            unlocked: unlocked,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        // ── §5 항목 10 + S18(보고서 잠금, 〃 미해금 섹션) ── 00_DEV_MAPPING.md
        // 화면 매핑 표 72줄 "S18 보고서 잠금 | 16 | 〃(미해금 섹션)"에 따라
        // S18은 별도 화면/파일이 아니라 이 화면의 미해금 상태 섹션으로
        // 구현한다(S18_report_lock.png의 독자적 AppBar는 디자인 목업
        // 관행상 섹션을 단독 프레임으로 보여준 것으로 해석 — 개발 문서
        // 표의 명시적 지시를 우선한다). §5 S18 전문(494-500줄) 5개 요소를
        // 모두 포함한 `_ReportLockSection`으로 교체한다.
        if (!unlocked) ...[
          _ReportLockSection(
            subDisplay: subDisplay,
            unlockCost: unlockCost,
            unlocking: unlocking,
            onTap: unlocking ? null : onUnlock,
            previewText: relationTypeDesc,
          ),
        ] else ...[
          GHSectionHead(
            key: detailSectionKey,
            mono: 'DETAIL REPORT',
            title: '상세 궁합 보고서',
          ),
          if (refunded) ...[
            const _RefundNoticeBanner(),
            const SizedBox(height: 14),
          ],
          for (final c in categories) ...[
            _DetailCard(
              categoryId: c['categoryId'] as String?,
              detail: detailByCategory[c['categoryId']],
            ),
            const SizedBox(height: 14),
          ],
        ],
        const SizedBox(height: 18),
        // ── §5 항목 11: 하단 고지 ──
        Text(
          '궁합 풀이는 정통 사주를 바탕으로 한 해석이며,\n관계의 방향은 두 사람이 함께 만들어 가요.',
          textAlign: TextAlign.center,
          style: GHText.ui(size: 12, height: 1.6, color: GHColors.gray),
        ),
      ],
    );
  }
}

/// [v4 S17 §5 항목 2 — 히어로 kenBurns] `GHMotion.kenBurns`(38초) 토큰을
/// 실제로 재생하는 신규 구현(이전까지 토큰만 정의돼 있고 사용처가 없었음).
/// 패키지 의존 없이 `AnimationController` + `Transform.scale`로 1.0→1.12
/// 완만한 확대를 38초 주기로 반복(reverse)한다.
class _KenBurnsHero extends StatefulWidget {
  const _KenBurnsHero({required this.assetPath, required this.alignY});
  final String assetPath;
  final double alignY;

  @override
  State<_KenBurnsHero> createState() => _KenBurnsHeroState();
}

class _KenBurnsHeroState extends State<_KenBurnsHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: GHMotion.kenBurns,
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.12,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (context, _) => Transform.scale(
      scale: _scale.value,
      child: Image.asset(
        widget.assetPath,
        fit: BoxFit.cover,
        alignment: Alignment(0, widget.alignY),
        errorBuilder: (_, _, _) => ColoredBox(
          color: GHColors.bg2.withValues(alpha: .7),
          child: const Center(
            child: Icon(Icons.image_outlined, color: GHColors.gray),
          ),
        ),
      ),
    ),
  );
}

/// [v4 S17 §5 항목 7 — 점선 버튼] 「✦ {상대}님의 별이 궁합지도에
/// 놓였어요」 + 「지도에서 보기 ›」. S16의 `_DashedRectPainter`(CustomPaint
/// 기반, 외부 패키지 의존 없음) 방식을 그대로 재사용한다.
class _DashedMapButton extends StatelessWidget {
  const _DashedMapButton({required this.partnerName, required this.onTap});
  final String partnerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: CustomPaint(
      painter: _DashedRectPainter(color: GHColors.violetText, radius: 14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Text('✦', style: TextStyle(fontSize: 13, color: GHColors.violetText)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$partnerName님의 별이 궁합지도에 놓였어요',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GHText.ui(size: 12.5, weight: FontWeight.w600, color: GHColors.fg),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '지도에서 보기 ›',
              style: GHText.ui(size: 12, weight: FontWeight.w700, color: GHColors.violetText),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = GHBorder.width;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        const dashLen = 5.0, gapLen = 3.5;
        final next = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// [v4 S17 §5 항목 8 — 핵심 요약 카드(glow)] S16의 `_GlowSummaryCard`와
/// 동일한 시각 언어(glow shadow + line 테두리)를 공유하되, 세부명을 담은
/// mono 라벨과 키워드 칩 3개가 추가된 S17 전용 버전.
class _GlowSummaryCard extends StatelessWidget {
  const _GlowSummaryCard({
    required this.subDisplay,
    required this.relationTypeLabel,
    required this.relationTypeDesc,
    required this.keywords,
  });
  final String subDisplay;
  final String? relationTypeLabel;
  final String relationTypeDesc;
  final List<String> keywords;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(GHRadius.card),
      border: Border.all(color: GHColors.line, width: GHBorder.width),
      boxShadow: [BoxShadow(color: GHColors.glowShadow, blurRadius: 22, offset: const Offset(0, 8))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GHMono('SUMMARY · $subDisplay 핵심 요약', color: GHColors.accent),
        const SizedBox(height: 10),
        Text(
          relationTypeDesc,
          textAlign: TextAlign.center,
          style: GHText.title(size: 19).copyWith(height: 1.4),
        ),
        if (relationTypeLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            relationTypeLabel!,
            textAlign: TextAlign.center,
            style: GHText.ui(size: 13.5, height: 1.75, color: GHColors.gray),
          ),
        ],
        if (keywords.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in keywords)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GHRadius.chip),
                    border: Border.all(color: GHColors.accent, width: GHBorder.width),
                  ),
                  child: Text(
                    k,
                    style: GHText.ui(size: 12, weight: FontWeight.w700, color: GHColors.accent),
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// [v4 S18 보고서 잠금 — 구조표 16, 00_DEV_MAPPING.md §5 494-500줄]
/// 화면 매핑 표(72줄)가 "S18 | 16 | 〃(미해금 섹션)"으로 명시하므로 별도
/// 화면/파일을 만들지 않고 `_ResultBody`의 미해금 분기 안에서 S18 전체
/// 5개 요소를 렌더링한다(S18_report_lock.png의 독자적 AppBar는 디자인
/// 목업이 섹션을 단독 프레임으로 보여준 관행으로 해석):
///   1. 모드전환칩(○ 무료 결과 → ✦ 상세 보고서) + 헤드라인
///   2. 미리보기 잠금 카드(「I 핵심 요약」+본문 2줄 노출+블러+자물쇠)
///   3. WHAT YOU GET(ghReportSections 전체 I~VI, I만 "미리보기" 태그)
///   4. PricePanel(compact) — result_gate.dart의 `_PricePanel`은 private라
///      재사용할 수 없으므로(그 파일은 절대 변경 금지) 동일 시각 언어로
///      이 파일 안에 압축 버전을 새로 만든다.
///   5. Footer는 이미 GunghapResultScreen.footer(공유+구매)가 담당하므로
///      이 섹션 내부에는 넣지 않는다(중복 CTA 방지) — 탭하면 기존
///      `onUnlock`(결제 게이트, 절대 변경 금지)을 그대로 호출한다.
class _ReportLockSection extends StatelessWidget {
  const _ReportLockSection({
    required this.subDisplay,
    required this.unlockCost,
    required this.unlocking,
    required this.onTap,
    required this.previewText,
  });
  final String subDisplay;
  final int unlockCost;
  final bool unlocking;
  final VoidCallback? onTap;
  // [§5 S18 항목 2 — 미리보기 카드 본문] 서버가 이미 내려주는
  // relationTypeDesc(핵심 요약 카드에 쓰는 것과 동일한 실제 텍스트)를
  // 재사용한다 — 전용 "I장 미리보기" 필드가 서버에 없으므로(§12-2
  // 원칙대로 가짜 문장을 지어내지 않음) 이미 있는 실제 데이터로 대체.
  final String? previewText;

  @override
  Widget build(BuildContext context) {
    final sections = ghReportSections(subDisplay); // I~VI 전체
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. 모드전환칩 + 헤드라인 ──
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GHChip(label: '○ 무료 결과', active: false),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→', style: TextStyle(color: GHColors.gray, fontSize: 13)),
              ),
              const GHChip(label: '✦ 상세 보고서', active: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '두 사람의 별의 지도를\n더 깊이 펼쳐 볼까요',
          textAlign: TextAlign.center,
          style: GHText.title(size: 22, color: GHColors.fg).copyWith(height: 1.38),
        ),
        const SizedBox(height: 20),
        // ── 2. 미리보기 잠금 카드(r22, 1.5px line, 블러+자물쇠) ──
        _LockedPreviewCard(sectionTitle: sections.first.title, previewText: previewText),
        const SizedBox(height: 20),
        // ── 3. WHAT YOU GET(I~VI 전체 목록, I 우측 "미리보기") ──
        GHMono('WHAT YOU GET', color: GHColors.accent),
        const SizedBox(height: 6),
        Text('상세 보고서에 담기는 내용', style: GHText.cardTitle(size: 16)),
        const SizedBox(height: 12),
        for (final s in sections) ...[
          _WhatYouGetRow(section: s, isPreview: s == sections.first),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        // ── 4. PricePanel(compact) ──
        _CompactPricePanel(unlockCost: unlockCost),
        const SizedBox(height: 18),
        // CTA — Footer(공유+구매)가 이미 하단에 고정돼 있으므로, 본문
        // 안에서도 한 번 더 누를 수 있게 동일 동작의 보조 버튼을 둔다
        // (S18 명세의 "Footer Primary" 요구를 본문에서도 보강).
        GHButton(
          label: unlocking ? '잠금해제하는 중…' : '❖ 상세 궁합 보고서 확인하기',
          onPressed: unlocking ? null : onTap,
          trailing: GHPricePill(unlockCost),
        ),
        const SizedBox(height: 10),
        Text(
          '한 번 열면 내 궁합에서 언제든 다시 볼 수 있어요',
          textAlign: TextAlign.center,
          style: GHText.ui(size: 12, color: GHColors.gray),
        ),
      ],
    );
  }
}

/// [S18 항목 2] 「I 핵심 요약」 소제목 + 본문 2줄 노출 + 아래쪽 블러
/// (sigma 5, 55% 흰 그라데이션 덮개) + 중앙 자물쇠 원(52) + 안내 문구.
class _LockedPreviewCard extends StatelessWidget {
  const _LockedPreviewCard({required this.sectionTitle, required this.previewText});
  final String sectionTitle;
  final String? previewText;

  @override
  Widget build(BuildContext context) {
    final body = previewText ?? '두 사람의 사주를 바탕으로 한 상세 해석이 이어집니다.';
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: GHColors.card,
          border: Border.all(color: GHColors.line, width: GHBorder.width),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('I', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GHColors.accent)),
                    const SizedBox(width: 6),
                    Text(sectionTitle, style: GHText.cardTitle(size: 15)),
                  ],
                ),
                const SizedBox(height: 10),
                // [블러 영역] 본문 텍스트를 그린 뒤 그 위에
                // ImageFiltered(blur 5)로 흐리게 처리 — 이 프로젝트
                // 다른 화면(splash_screen.dart 등)이 이미 쓰는 패턴.
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GHText.reportBody(),
                  ),
                ),
                const SizedBox(height: 64),
              ],
            ),
            // 그라데이션 덮개(아래쪽일수록 흰색 불투명도 ↑, 55%)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 92,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        GHColors.card.withValues(alpha: 0),
                        GHColors.card.withValues(alpha: .55),
                        GHColors.card,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: GHGradients.primary,
                      boxShadow: [BoxShadow(color: GHColors.glowShadow, blurRadius: 16)],
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '이어지는 내용은 상세 보고서에서',
                    style: GHText.ui(size: 12, weight: FontWeight.w600, color: GHColors.gray),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [S18 항목 3] WHAT YOU GET 한 줄 — 번호(accent) · 제목(14.5/700) ·
/// 설명(12) · I장만 우측에 "미리보기"(mint) 태그를 덧붙인다.
class _WhatYouGetRow extends StatelessWidget {
  const _WhatYouGetRow({required this.section, required this.isPreview});
  final GHReportSection section;
  final bool isPreview;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 24,
        child: Text(
          section.no,
          style: GHText.hanja(size: 13, color: GHColors.accent),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    section.title,
                    style: GHText.ui(size: 14.5, weight: FontWeight.w700, color: GHColors.fg),
                  ),
                ),
                if (isPreview) ...[
                  const SizedBox(width: 6),
                  Text('미리보기', style: GHText.ui(size: 11, weight: FontWeight.w700, color: GHColors.mint)),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(section.desc, style: GHText.ui(size: 12, color: GHColors.gray)),
          ],
        ),
      ),
    ],
  );
}

/// [S18 항목 4 — PricePanel(compact)] `result_gate.dart`의 `_PricePanel`
/// (private, 절대 변경 금지인 그 파일 소속이라 외부 재사용 불가)과 같은
/// 시각 언어를 쓰되 한 줄로 압축한 버전. 보유 잔액 표시를 위해
/// [LuckPouchProvider]를 watch한다.
class _CompactPricePanel extends StatelessWidget {
  const _CompactPricePanel({required this.unlockCost});
  final int unlockCost;

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<LuckPouchProvider>().balance;
    final short = balance < unlockCost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GHColors.line, width: GHBorder.width),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: GHColors.fieldBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('❖', style: TextStyle(color: GHColors.violet, fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('상세 보고서 1회 열람', style: GHText.ui(size: 13, weight: FontWeight.w700, color: GHColors.fg)),
                const SizedBox(height: 2),
                Text(
                  '보유 복주머니 $balance개',
                  style: GHText.ui(size: 11.5, color: short ? GHColors.rose : GHColors.gray),
                ),
              ],
            ),
          ),
          Text(
            '복주머니 $unlockCost개',
            style: GHText.ui(size: 14, weight: FontWeight.w800, color: GHColors.accent),
          ),
        ],
      ),
    );
  }
}

// [2026-11 환불 UI 보완 지시] LLM 호출이 끝내 실패해 서버가 100P를 자동
// 환불한 경우에만 노출되는 안내 배너. `GHCard`/기존 색상 토큰
// (GHColors.rose)을 그대로 재사용해 궁합지도 디자인 언어를 벗어나지
// 않는다 — 신규 색상/컴포넌트를 만들지 않음. [S17 UI 재작성 — 절대
// 변경 금지] 이 위젯은 한 글자도 바뀌지 않았다.
class _RefundNoticeBanner extends StatelessWidget {
  const _RefundNoticeBanner();

  @override
  Widget build(BuildContext context) => GHCard(
    borderRadius: GHRadius.cardSm,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '상세 해석 생성이 원활하지 않아 복주머니 100P가 자동 환불되었습니다. '
            '아래 내용은 참고용 해석입니다.',
            style: GHText.ui(
              size: 12.5,
              weight: FontWeight.w600,
              height: 1.5,
              color: GHColors.rose,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.categoryId,
    required this.grade,
    required this.detail,
    required this.unlocked,
  });
  final String? categoryId;
  final String? grade;
  final Map? detail;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final major = ghMajorById(categoryId);
    return GHCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: GHRadius.cardSm,
      minHeight: 60,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GHColors.gold.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GHColors.divider),
            ),
            alignment: Alignment.center,
            child: CatIcon(kind: major.icon, size: 28, active: unlocked),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(major.name, style: GHText.cardTitle(size: 14.5)),
          ),
          if (grade != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: GHColors.cardSolid,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: GHColors.lineSoft),
              ),
              child: Text(
                grade!,
                style: GHText.ui(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: GHColors.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.categoryId, required this.detail});
  final String? categoryId;
  final Map? detail;

  @override
  Widget build(BuildContext context) {
    final major = ghMajorById(categoryId);
    if (detail == null) {
      return GHCard(
        child: Text(
          '${major.name} 상세 데이터를 불러오지 못했습니다.',
          style: GHText.ui(size: 13, color: GHColors.gray),
        ),
      );
    }
    final relationshipFeature = detail!['relationshipFeature'] as String?;
    final strength = detail!['strength'] as String?;
    final conflictRisk = detail!['conflictRisk'] as String?;
    // [2026-11 유료 보고서 7단계 확대 지시 — "유료이니 분석을 더해서 4단계
    // 밖에 안되니 7,8단계 만들어서 진행 충분히 결과를 만들어줘야지"]
    // 신규 3필드(대화 방식/성장 가능성/주의할 점). 레거시(majorId=null)
    // 결과는 서버 응답에 이 3필드가 아예 없으므로(undefined → JSON에서
    // 생략) null로 들어와 해당 섹션이 자연스럽게 숨겨진다 — 기존 화면은
    // 100% 그대로 유지된다.
    final communicationStyle = detail!['communicationStyle'] as String?;
    final growthPotential = detail!['growthPotential'] as String?;
    final cautionPoint = detail!['cautionPoint'] as String?;
    final improvement = detail!['improvement'] as String?;

    return GHCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GHColors.gold.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GHColors.divider),
                ),
                alignment: Alignment.center,
                child: CatIcon(kind: major.icon, size: 24, active: true),
              ),
              const SizedBox(width: 10),
              Text(major.name, style: GHText.reportSection()),
            ],
          ),
          const SizedBox(height: 14),
          if (relationshipFeature != null)
            _DetailSection(label: '두 사람의 관계 특징', body: relationshipFeature),
          if (strength != null)
            _DetailSection(label: '잘 맞는 부분', body: strength),
          if (conflictRisk != null)
            _DetailSection(label: '갈등 가능성', body: conflictRisk),
          if (communicationStyle != null)
            _DetailSection(label: '대화와 교감의 방식', body: communicationStyle),
          if (growthPotential != null)
            _DetailSection(label: '관계가 깊어지는 계기', body: growthPotential),
          if (cautionPoint != null)
            _DetailSection(label: '조심해야 할 순간', body: cautionPoint),
          if (improvement != null)
            _DetailSection(label: '관계 개선 방향', body: improvement, last: true),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.label,
    required this.body,
    this.last = false,
  });
  final String label;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '◇ ',
              style: TextStyle(fontSize: 9, color: GHColors.gold),
            ),
            Text(
              label,
              style: GHText.ui(
                size: 12.5,
                weight: FontWeight.w700,
                color: GHColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(body, style: GHText.reportBody()),
      ],
    ),
  );
}
