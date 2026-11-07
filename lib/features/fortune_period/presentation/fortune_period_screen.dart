/// [오늘의 운세 — 단일 서사 화면]
///
/// [2026-11 전면 개편] 기존 "오늘/주간/월간" 3탭 + 총평·흐름·분야별·주의사항
/// 다중 섹션 구조를 폐기했다. 사용자 피드백("주간/월간은 거의 쓰레기 수준")에
/// 따라 주간/월간을 삭제하고, 오늘의 운세 하나만 남겨 AI(무당체: 반말/단정체)
/// 해석이 만든 하나의 이어지는 글(단일 서사, 섹션/카드 구분 없음)을 그대로
/// 보여준다. 같은 엔진 계산값이 여러 섹션에 중복 노출되던 기존 버그도
/// 구조적으로 사라진다(텍스트 블록이 하나뿐이므로).
///
/// [서버 연동] `FortunePeriodRepository.fetchCurrent(FortuneKind.today)`가
/// `GET /api/public/fortune-period/today`(get-or-create, 서버가 KST
/// 기준 period_key로 중복 생성을 막고, 신규 생성 시 saju_engine의 AI 무당체
/// 해석까지 호출한다)를 호출한다. 화면 진입 시 1회만 호출한 결과를 메모리에
/// 캐시해 재사용한다.
library;

import 'package:flutter/material.dart';

import '../../../core/util/original_result_capture.dart';
import '../../../core/util/save_filename.dart';
import '../../share/application/share_service.dart';
import '../../share/domain/share_result_model.dart';
import '../data/fortune_period_repository.dart';
import '../domain/fortune_period_model.dart';
import '../theme/fortune_period_theme.dart';
import '../widgets/fortune_common_widgets.dart';
import '../widgets/fortune_sigil.dart';
import 'saju_input_screen.dart';

class FortunePeriodScreen extends StatefulWidget {
  const FortunePeriodScreen({super.key});

  @override
  State<FortunePeriodScreen> createState() => _FortunePeriodScreenState();
}

class _FortunePeriodScreenState extends State<FortunePeriodScreen> {
  final _repo = FortunePeriodRepository();
  static const _kind = FortuneKind.today;

  // [저장/공유 실제 구현 — 2026-12] 기존에는 공유 버튼이 "공유 기능은
  // 준비 중이에요" 토스트만 띄우는 더미였다(사용자 신고: "공유하기
  // 클릭시 나오는것 삭제" — 실제 동작하는 저장+공유하기로 교체 요청).
  // 다른 결과 화면(story_detail_screen.dart 등)과 동일한 패턴으로
  // RepaintBoundary 캡처 키를 둔다. 이 화면은 헤더가 AppBar로 고정되어
  // 있고(스크롤 본문에 포함되지 않음) 본문 자체가 이미 SingleChildScrollView
  // 안에서 전부 레이아웃되는 일반 Column이라, leadingKeys 없이 캡처 대상
  // 영역(기간 헤더+본문 서사+행운 아이템)만 감싸는 하나의 키로 충분하다.
  final _originalResultKey = GlobalKey();

  bool _loaded = false;
  bool _loading = false;
  FortunePeriodResult? _result;
  String? _errorCode;
  String? _errorMessage;
  List<FortuneArchiveItem> _history = const [];

  // 지난 운세 열람 중 상태(ArchiveList → PastBanner).
  bool _viewingPast = false;
  bool _loadingPast = false;
  FortunePeriodResult? _pastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    if (_loaded && !force) return; // 이미 이번 화면 진입에서 가져온 결과 재사용
    setState(() {
      _loading = true;
      _errorCode = null;
      _errorMessage = null;
    });

    final result = await _repo.fetchCurrent(_kind);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.success && result.data != null) {
        _result = result.data;
        _loaded = true;
      } else {
        _errorCode = result.errorCode;
        _errorMessage = result.errorMessage;
      }
    });

    if (result.success && result.data != null) {
      _loadHistory();
    } else if (result.errorCode == 'SAJU_REQUIRED') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goRegister();
      });
    }
  }

  Future<void> _loadHistory() async {
    final res = await _repo.fetchHistory(_kind, limit: 6);
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() => _history = res.data!);
    }
  }

  Future<void> _goRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SajuInputScreen(mode: SajuInputMode.first),
      ),
    );
    if (!mounted) return;
    // 등록 후 상태를 초기화하고 다시 조회한다.
    setState(() {
      _loaded = false;
      _result = null;
      _history = const [];
      _viewingPast = false;
      _pastResult = null;
    });
    _load(force: true);
  }

  Future<void> _openPast(String periodKey) async {
    if (periodKey == _result?.periodKey) return; // 현재 기간이면 그대로 둔다
    setState(() => _loadingPast = true);
    final res = await _repo.fetchPast(_kind, periodKey);
    if (!mounted) return;
    setState(() {
      _loadingPast = false;
      if (res.success && res.data != null) {
        _pastResult = res.data;
        _viewingPast = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage ?? '지난 운세를 불러오지 못했습니다.')),
        );
      }
    });
  }

  void _backToCurrent() {
    setState(() {
      _viewingPast = false;
      _pastResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FortunePeriodColors.bg1,
      appBar: AppBar(
        backgroundColor: FortunePeriodColors.bg1,
        elevation: 0,
        foregroundColor: FortunePeriodColors.fg,
        title: const Text(
          '오늘의 운세',
          style: TextStyle(
            fontFamily: FortunePeriodType.serif,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: FortunePeriodColors.fg,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && !_loaded) {
      return const _LoadingState();
    }
    if (_errorCode == 'SAJU_REQUIRED') {
      // 등록 화면으로 자동 이동 처리 중 — 짧게 로딩만 보여준다.
      return const _LoadingState();
    }
    if (!_loaded || _result == null) {
      return _ErrorState(
        message: _errorMessage ?? '기운이 잠시 닿지 않았어요',
        onRetry: () => _load(force: true),
      );
    }

    final showPast = _viewingPast && _pastResult != null;
    final data = showPast ? _pastResult! : _result!;

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPast)
              _PastBanner(onCurrent: _backToCurrent)
            else
              const SizedBox.shrink(),
            if (showPast) const SizedBox(height: 14),
            // [저장/공유 2026-12] 기간 헤더 + 서사 + 행운 아이템만 캡처
            // 대상으로 묶는다(지난 운세 목록/공유 버튼 자체는 저장 이미지에
            // 포함하지 않는다 — 다른 결과 화면들도 동일하게 "결과 본문"만
            // 캡처한다). 이 Column은 이미 바깥 SingleChildScrollView 안에서
            // 전체 높이로 레이아웃되므로 별도 스크롤 래퍼 없이
            // OriginalResultScene(RepaintBoundary 전용)만으로 충분하다.
            OriginalResultScene(
              captureKey: _originalResultKey,
              background: FortunePeriodColors.bg1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!showPast) _PeriodHeader(result: data),
                  if (showPast) _PastPeriodHeader(result: data),
                  const SizedBox(height: 22),
                  _NarrativeCard(result: data),
                  if (data.luckyColor.isNotEmpty ||
                      data.luckyDirection.isNotEmpty ||
                      data.luckyNumber.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _LuckyItemsSection(result: data),
                  ],
                ],
              ),
            ),
            if (!showPast && _history.isNotEmpty) ...[
              const SizedBox(height: 28),
              _ArchiveSection(
                items: _history,
                currentKey: _result!.periodKey,
                loading: _loadingPast,
                onOpen: _openPast,
              ),
            ],
            const SizedBox(height: 28),
            _ShareSection(
              result: data,
              captureKey: _originalResultKey,
            ),
          ],
        ),
      ),
    );
  }
}

/// `.v2-period` — 기간 라벨/메인 타이틀/보조 설명.
class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.result});
  final FortunePeriodResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(result.period.label, style: FortunePeriodType.mono10),
        const SizedBox(height: 8),
        Text(
          result.period.main,
          textAlign: TextAlign.center,
          style: FortunePeriodType.periodMain,
        ),
        const SizedBox(height: 5),
        Text(
          result.period.sub,
          textAlign: TextAlign.center,
          style: FortunePeriodType.periodSub,
        ),
        if (result.dayGanZhi != null && result.dayGanZhi!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            result.dayGanZhi!,
            textAlign: TextAlign.center,
            style: FortunePeriodType.noteMono.copyWith(
              color: FortunePeriodColors.glow,
            ),
          ),
        ],
      ],
    );
  }
}

/// 과거 결과 열람 시 — `period` 메타가 없으므로(조회 전용) 보관 상태만
/// 간단히 보여준다.
class _PastPeriodHeader extends StatelessWidget {
  const _PastPeriodHeader({required this.result});
  final FortunePeriodResult result;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(FortunePeriodRadius.pill),
          border: Border.all(color: FortunePeriodColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: FortunePeriodColors.glow,
              ),
            ),
            const Text('지난 운세 · 보관된 결과', style: FortunePeriodType.pastBanner),
          ],
        ),
      ),
    );
  }
}

/// 오늘의 운세 메인 카드 — 헤드라인 + 두세 문단으로 이어지는 하나의 글
/// (섹션/카드 구분 없음, AI 무당체 해석 그대로).
class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.result});
  final FortunePeriodResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FortunePeriodRadius.xl),
        border: Border.all(color: const Color(0x244A2FB0)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FortunePeriodColors.summaryGradStart,
            FortunePeriodColors.summaryGradMid,
            FortunePeriodColors.summaryGradEnd,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5B3FC4),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -80,
            child: FortuneSigil(
              size: 240,
              color: FortunePeriodColors.sigil,
              opacity: 0.35,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('오늘의 운세 · 占辭', style: FortunePeriodType.mono10),
              const SizedBox(height: 16),
              Text(result.headline, style: FortunePeriodType.summaryTitle),
              const SizedBox(height: 18),
              Text(result.text, style: FortunePeriodType.summaryBody),
            ],
          ),
        ],
      ),
    );
  }
}

/// 섹션 소제목 — `.v2-h` (제목 + 오른쪽으로 뻗는 구분선).
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: FortunePeriodType.sectionHead),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: FortunePeriodColors.line)),
      ],
    );
  }
}

/// 행운 아이템 — 색/방향/숫자 3종(엔진이 계산한 고정 속성, 생년월일 기준
/// 부족한 오행 보완용. 날짜가 바뀌어도 변하지 않는다).
class _LuckyItemsSection extends StatelessWidget {
  const _LuckyItemsSection({required this.result});
  final FortunePeriodResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(title: '오늘의 행운 아이템'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FortunePeriodRadius.xl),
            border: Border.all(color: FortunePeriodColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D5B3FC4),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              if (result.luckyColor.isNotEmpty)
                _LuckyItemChip(label: '색', values: result.luckyColor),
              if (result.luckyDirection.isNotEmpty)
                _LuckyItemChip(label: '방향', values: result.luckyDirection),
              if (result.luckyNumber.isNotEmpty)
                _LuckyItemChip(
                  label: '숫자',
                  values: result.luckyNumber.map((n) => '$n').toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LuckyItemChip extends StatelessWidget {
  const _LuckyItemChip({required this.label, required this.values});
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FortunePeriodType.archiveWhen.copyWith(letterSpacing: 1.0),
        ),
        const SizedBox(height: 6),
        Text(values.join(' · '), style: FortunePeriodType.fieldName),
      ],
    );
  }
}

/// `ArchiveList` — 지난 결과 목록(최대 6건, 최신순). 조회 전용.
class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({
    required this.items,
    required this.currentKey,
    required this.loading,
    required this.onOpen,
  });

  final List<FortuneArchiveItem> items;
  final String currentKey;
  final bool loading;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(title: '지난 오늘의 운세'),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FortunePeriodRadius.xl),
            border: Border.all(color: FortunePeriodColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: items.asMap().entries.map((e) {
              final it = e.value;
              final isCurrent = it.periodKey == currentKey;
              return InkWell(
                onTap: loading ? null : () => onOpen(it.periodKey),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? FortunePeriodColors.glow.withValues(alpha: 0.07)
                        : null,
                    border: e.key == 0
                        ? null
                        : const Border(
                            top: BorderSide(color: FortunePeriodColors.line),
                          ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatWhen(it.createdAt),
                              style: FortunePeriodType.archiveWhen,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              it.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FortunePeriodType.archiveTitle,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isCurrent ? '보는 중' : '다시 보기',
                        style: isCurrent
                            ? FortunePeriodType.archiveGo.copyWith(
                                color: FortunePeriodColors.muted,
                              )
                            : FortunePeriodType.archiveGo,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatWhen(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    return '${local.month}.${local.day}';
  }
}

/// `PastBanner` — 지난 운세 열람 중 상단 배너.
class _PastBanner extends StatelessWidget {
  const _PastBanner({required this.onCurrent});
  final VoidCallback onCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FortunePeriodColors.cautionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FortunePeriodColors.cautionBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('지난 운세를 보고 있어요', style: FortunePeriodType.pastBanner),
          GestureDetector(
            onTap: onCurrent,
            child: Text(
              '오늘의 운세로 ›',
              style: FortunePeriodType.pastBanner.copyWith(
                color: FortunePeriodColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [UI 개선 — 2026-12 저장/공유 통합 박스] 기존에는 "☾ 운세 공유하기"
/// 버튼을 누르면 카카오톡/인스타그램/이미지 저장/링크 복사 4개 아이콘이
/// 뜨는 바텀시트가 열렸지만, 그 어느 버튼도 실제로 동작하지 않고
/// "공유 기능은 준비 중이에요" 토스트만 띄우는 더미였다(사용자 신고:
/// "공유하기 클릭시 나오는것 삭제"). story_detail_screen.dart /
/// face_result_screen.dart 등 다른 결과 화면과 동일하게, 실제로 동작하는
/// "저장" + "공유하기" 두 액션만 남긴 테두리 박스로 교체한다(가짜
/// 공유 타깃 시트는 완전히 삭제).
class _ShareSection extends StatelessWidget {
  const _ShareSection({required this.result, required this.captureKey});
  final FortunePeriodResult result;
  final GlobalKey captureKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FortunePeriodRadius.lg),
            color: FortunePeriodColors.card,
            border: Border.all(color: FortunePeriodColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SaveShareAction(
                  icon: Icons.download_rounded,
                  label: '저장',
                  onTap: () => saveOriginalResult(
                    context,
                    captureKey,
                    // [REQ-09] 파일명 규칙 통일.
                    name: buildSaveFileName('fortune_period', result.periodKey),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: FortunePeriodColors.line,
              ),
              Expanded(
                child: _SaveShareAction(
                  icon: Icons.ios_share_rounded,
                  label: '공유하기',
                  onTap: () => _shareResult(context, result),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '이름과 생년월일은 공유되지 않아요',
          textAlign: TextAlign.center,
          style: FortunePeriodType.noteMono,
        ),
      ],
    );
  }

  /// [ShareResultType 선택 근거] `ShareResultType`/admin_web
  /// `share-og-config.ts`의 6개 카테고리(wish/tarot/saju/relationship/
  /// face/palm) 중 "오늘의 운세" 전용 값은 없다 — `fortune` 값은
  /// `@Deprecated`(레거시 전용, 신규 호출부 사용 금지)로 못박혀 있고 코드
  /// 주석이 명시적으로 "신규 공유는 saju를 사용할 것"이라 지시한다.
  /// 이에 따라 saju를 사용한다(수신측 `/r/{shareId}` 링크는 "정통사주"
  /// 뱃지로 표시됨 — 새 전용 카테고리 추가는 admin_web
  /// OG_CONFIG/이미지 에셋까지 바꿔야 하는 별도 작업이라 이번 범위에
  /// 포함하지 않는다). payload의 `kind: 'fortune_period'`로 원본 출처를
  /// 구분해 남긴다.
  void _shareResult(BuildContext context, FortunePeriodResult data) {
    final highlights = <String>[
      data.headline,
      if (data.luckyColor.isNotEmpty) '행운의 색: ${data.luckyColor.join(" · ")}',
      if (data.luckyDirection.isNotEmpty)
        '행운의 방향: ${data.luckyDirection.join(" · ")}',
      if (data.luckyNumber.isNotEmpty)
        '행운의 숫자: ${data.luckyNumber.join(" · ")}',
    ];
    ShareService.shareResult(
      context,
      // ignore: deprecated_member_use_from_same_package
      resultType: ShareResultType.saju,
      title: data.headline,
      description: data.text,
      payload: {
        'kind': 'fortune_period',
        'period': data.period.main,
        if (data.dayGanZhi != null) 'dayGanZhi': data.dayGanZhi,
        'summary': data.text,
        'highlights': highlights,
      },
      sourceRefId: data.periodKey,
      originalResultKey: captureKey,
    );
  }
}

/// [UI 개선 — 2026-12] 저장/공유 통합 박스 내부의 개별 액션(아이콘+라벨).
/// `story_detail_screen.dart`의 `_SaveShareAction`과 동일한 구조를
/// `FortunePeriodColors`/`FortunePeriodType`(백자 팔레트) 토큰으로 재구현한
/// 것 — 이 화면은 흰 배경이므로 어두운 글자색(fg)을 쓴다.
class _SaveShareAction extends StatelessWidget {
  const _SaveShareAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FortunePeriodRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: FortunePeriodColors.glow),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: FortunePeriodType.ui,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: FortunePeriodColors.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `FortuneLoading` — 꺼진 촛불 + 어두운 sigil 로딩 상태.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FortuneSigil(
                  size: 160,
                  color: FortunePeriodColors.sigil,
                  opacity: 0.3,
                ),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(
                      FortunePeriodColors.glow,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('READING · 점사 중', style: FortunePeriodType.mono10),
          const SizedBox(height: 10),
          const Text(
            '오늘의 기운을\n살피고 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: FortunePeriodType.serif,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              height: 1.4,
              color: FortunePeriodColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// `FortuneEmpty` — 엔진/네트워크 오류 상태(사주 미입력은 자동 리다이렉트).
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ERROR · 불러오지 못함', style: FortunePeriodType.mono10),
            const SizedBox(height: 14),
            const Text(
              '기운이 잠시\n닿지 않았어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: FortunePeriodType.serif,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.4,
                color: FortunePeriodColors.fg,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: FortunePeriodType.body,
                fontSize: 13.5,
                height: 1.7,
                color: FortunePeriodColors.muted,
              ),
            ),
            const SizedBox(height: 22),
            FortunePrimaryButton(label: '🕯 다시 불러오기', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
