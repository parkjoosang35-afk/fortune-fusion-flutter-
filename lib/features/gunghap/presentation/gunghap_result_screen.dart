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
// (해금 시) 8개 상세 리포트까지 아무리 길어져도 잘리지 않는다. 저장
// 버튼은 [GHScreen.footer](스크롤 영역 밖, 캡처 범위 밖)에 둬서
// 귀인지도와 동일하게 버튼 자체는 저장 이미지에 포함되지 않는다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/util/original_result_capture.dart';
import '../../../core/util/save_filename.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/result_text_scale_overlay.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';
import '../application/gunghap_provider.dart';
import '../domain/gunghap_data.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/cat_icon.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';

class GunghapResultScreen extends StatefulWidget {
  const GunghapResultScreen({super.key, required this.resultId});
  final String resultId;

  @override
  State<GunghapResultScreen> createState() => _GunghapResultScreenState();
}

class _GunghapResultScreenState extends State<GunghapResultScreen> {
  bool _loading = true;
  bool _unlocking = false;
  // [궁합지도 Phase 4 §4 — 결과 재열람] 궁합스토리에서 과거 기록을 다시
  // 열람할 때, 그 사이 결과가 삭제됐을 수 있다(DELETE
  // /api/public/gunghap/results/{resultId} 이미 Phase 3에서 구현/배포됨).
  // 서버는 이 경우 404 + code:'NOT_FOUND'를 반환하므로(fetchResult가
  // decoded['code']를 그대로 전달), "다시 시도" 버튼이 의미 없는
  // 전용 안내 문구 + 목록으로 돌아가기 동작을 구분해서 보여준다.
  bool _deletedNotFound = false;
  // [Phase 4 §5 — 결과 이미지 갤러리 저장] 결과 콘텐츠 전체를 감싸는
  // RepaintBoundary 캡처 키. `_ResultBody` 전체(스텝/타이틀/별자리맵/
  // 요약카드/8개 분야 등급/상세 리포트까지)를 하나의 레이어로 캡처한다.
  final _originalResultKey = GlobalKey();
  bool _savingImage = false;

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

  Future<void> _unlock() async {
    final provider = context.read<GunghapProvider>();
    final pouch = context.read<LuckPouchProvider>();
    setState(() => _unlocking = true);
    final ok = await provider.unlock(widget.resultId);
    if (!mounted) return;
    setState(() => _unlocking = false);

    if (!ok) {
      if (provider.errorCode == 'INSUFFICIENT_BALANCE') {
        AppToast.show(
          context,
          '복주머니가 부족합니다. 복주머니를 모아 다시 시도해 주세요.',
          isError: true,
        );
      } else if (provider.errorCode == 'NETWORK_ERROR') {
        AppToast.show(
          context,
          provider.error ?? '서비스 연결이 원활하지 않습니다.',
          isError: true,
          onRetry: _unlock,
        );
      } else {
        AppToast.show(
          context,
          provider.error ?? '잠금해제하지 못했습니다. 잠시 후 다시 시도해 주세요.',
          isError: true,
          onRetry: _unlock,
        );
      }
      return;
    }
    // [재화 단일화 원칙] 서버 원장을 다시 조회해 앱 전역 잔액 표시를
    // 동기화한다(GunghapProvider는 결제를 직접 다루지 않음 — 파일 상단
    // 주석/GunghapProvider.unlock() 문서 참고).
    await pouch.load();
    if (!mounted) return;
    AppToast.show(context, '상세 보고서가 열렸어요.');
  }

  // [Phase 4 §5 — 결과 이미지 갤러리 저장] 귀인지도
  // (`guinji_result_card_screen.dart._saveImage`)와 완전히 동일한
  // 구조: captureOriginalResult/saveOriginalResult 공용 유틸을 그대로
  // 재사용하고, 성공/실패 토스트도 그 유틸이 전담한다(이 화면에서
  // 별도 토스트 문구를 만들지 않음 — REQ-05/REQ-09 표준 유지).
  // 파일명은 공통 규칙(`sintong_gunghap_{resultId}_{yyyyMMdd_HHmmss}`)을
  // 그대로 따른다.
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();
    final result = provider.result;
    final showResult = !_loading && result != null;

    return ResultTextScaleOverlay(
      child: GHScreen(
        bottomNav: const MainBottomNavBar(currentIndex: 0),
        appBar: GHAppBar(
          title: '궁합 결과',
          onBack: () => Navigator.of(context).pop(),
        ),
        // [Phase 4 §5] 저장 버튼은 캡처 범위(RepaintBoundary) 밖인 footer에
        // 둔다 — 귀인지도와 동일하게 버튼 자체가 저장 이미지에 찍히지 않게
        // 하기 위함. 결과가 아직 없거나(로딩/에러) 보이지 않을 때는 저장할
        // 것이 없으므로 footer를 아예 숨긴다.
        footer: showResult
            ? GHButton(
                label: _savingImage ? '이미지를 준비하는 중…' : '결과 이미지로 저장하기',
                variant: GHButtonVariant.secondary,
                leading: _savingImage
                    ? null
                    : const Icon(
                        Icons.download_rounded,
                        size: 16,
                        color: GHColors.ivory,
                      ),
                onPressed: _savingImage ? null : _saveImage,
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
                    unlocking: _unlocking,
                    onUnlock: _unlock,
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
  });
  final Map<String, dynamic> result;
  final bool unlocking;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final ownerName = result['ownerName'] as String? ?? '나';
    final guestName = result['guestName'] as String? ?? '상대방';
    final relationTypeLabel = result['relationTypeLabel'] as String?;
    final relationTypeDesc = result['relationTypeDesc'] as String?;
    final grade = result['grade'] as String?;
    final chemistryScore = result['chemistryScore'];
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
    // [2026-11 궁합 세부주제 표시 버그 수정 — 대표 신고 "성격/대화/감정
    // 궁합을 따로 다 봤는데 다 똑같다" / 스크린샷 실증("썸 궁합"을
    // 고르고도 항상 "궁합 결과예요"로만 표시됨)] 사용자가 고른 세부
    // 주제(subName, 예: "썸 궁합")가 있으면 타이틀/섹션명/잠금해제 안내
    // 문구 모두에 그대로 반영한다(서버 변경 없이 Flutter만으로 가능).
    final subName = result['subName'] as String?;
    final freeSectionTitle = subName != null
        ? '$subName 등급'
        : majorId != null
        ? '${ghMajorById(majorId).shortName} 궁합 등급'
        : '8개 분야 궁합 등급';
    final lockedReportDesc = subName != null
        ? '$subName 분야의 관계 특징 · 잘 맞는 부분 · 갈등 가능성 · '
              '대화 방식 · 성장 가능성 · 주의할 점 · 개선 방향까지, 실제 사주\n'
              '풀이를 바탕으로 한 7단계 전체 보고서를 확인할 수 있어요.'
        : majorId != null
        ? '${ghMajorById(majorId).shortName} 분야의 관계 특징 · 잘 맞는 부분 · '
              '갈등 가능성 · 관계 개선 방향까지, 실제 사주 풀이를 바탕으로 한\n'
              '전체 보고서를 확인할 수 있어요.'
        : '8개 분야 각각 관계 특징 · 잘 맞는 부분 · 갈등 가능성 ·\n'
              '관계 개선 방향까지, 실제 사주 풀이를 바탕으로 한\n'
              '전체 보고서를 확인할 수 있어요.';
    final detailRaw = result['detail'];
    final detail = detailRaw is List
        ? detailRaw.whereType<Map>().toList()
        : const <Map>[];
    final detailByCategory = {
      for (final d in detail)
        if (d['categoryId'] != null) d['categoryId'] as String: d,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GHSteps(step: 4, labels: ['분야', '나', '상대', '분석']),
        GHTitle(
          mono: 'STEP 04 · RESULT',
          title: subName != null
              ? '$ownerName님과 $guestName님의\n$subName 결과예요'
              : '$ownerName님과 $guestName님의\n궁합 결과예요',
          center: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: StarMap(aName: ownerName, bName: guestName, draw: true),
          ),
        ),
        const SizedBox(height: 10),
        GHCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (grade != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GHColors.gold.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: GHColors.gold),
                      ),
                      child: Text(
                        grade,
                        style: GHText.ui(
                          size: 13,
                          weight: FontWeight.w800,
                          color: GHColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (chemistryScore != null)
                    Text(
                      '$chemistryScore점',
                      style: GHText.ui(
                        size: 13,
                        weight: FontWeight.w700,
                        color: GHColors.ivory,
                      ),
                    ),
                ],
              ),
              if (relationTypeLabel != null) ...[
                const SizedBox(height: 10),
                Text(relationTypeLabel, style: GHText.cardTitle(size: 16)),
              ],
              if (relationTypeDesc != null) ...[
                const SizedBox(height: 6),
                Text(
                  relationTypeDesc,
                  style: GHText.ui(size: 13, height: 1.6, color: GHColors.gray),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
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
        if (!unlocked) ...[
          GHCard(
            borderRadius: GHRadius.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '상세 궁합 보고서',
                        style: GHText.cardTitle(size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lockedReportDesc,
                  style: GHText.ui(size: 13, height: 1.6, color: GHColors.gray),
                ),
                const SizedBox(height: 16),
                GHButton(
                  label: unlocking ? '잠금해제하는 중…' : '상세 보고서 잠금해제하기',
                  onPressed: unlocking ? null : onUnlock,
                  trailing: GHPricePill(unlockCost),
                ),
              ],
            ),
          ),
        ] else ...[
          const GHSectionHead(mono: 'DETAIL REPORT', title: '상세 궁합 보고서'),
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
      ],
    );
  }
}

// [2026-11 환불 UI 보완 지시] LLM 호출이 끝내 실패해 서버가 100P를 자동
// 환불한 경우에만 노출되는 안내 배너. `GHCard`/기존 색상 토큰
// (GHColors.rose)을 그대로 재사용해 궁합지도 디자인 언어를 벗어나지
// 않는다 — 신규 색상/컴포넌트를 만들지 않음.
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
