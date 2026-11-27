// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_story_screen.dart
// [궁합지도 Phase 4 — Flutter 개발 지시서 §3] 마이페이지 "궁합스토리".
//
// [절대 원칙] 이 화면은 `GET /api/public/gunghap/my-results` 서버 응답을
// 그대로 표시한다 — 로컬 SharedPreferences 목록이나 하드코딩 RECENT
// 목록(`gunghap_data.dart`의 [ghRecentHistory], 디자인 미리보기 전용
// 더미)을 절대 사용하지 않는다. DIRECT/INVITE 결과가 통합되어 이미
// 최신순으로 정렬된 채 내려온다([GunghapProvider.fetchMyResults] 참고).
//
// [상대방 이름 표기 원칙] DIRECT 결과는 서버 설계상 `ownerName`이 항상
// null이다(로그인 사용자 본인이 곧 owner라 별도 저장 안 함) — "상대방
// 이름"은 resultType과 무관하게 항상 `guestName` 필드를 사용한다
// (`gunghap_repository.dart` [GunghapRepository.fetchMyResults] 문서 참고).
//
// [S25/S46/S47/S48 — 00_DEV_MAPPING.md §5 S25(578-590줄) + §12-4(846줄)]
// v4 명세는 "최근/저장/초대받은" 3탭 세그먼트 + S48(초대받은 대기 행)을
// 요구하지만, §12-4가 스스로 "미지원 시 「최근」 단일"을 권장 대안으로
// 명시한다 — 이 프로젝트 서버(`my-results` API, `GunghapInvite` 스키마)를
// 직접 확인한 결과 (a) 결과 항목에 "저장" 여부 플래그가 없고(모든 결과가
// 동일하게 영구 보관되며 별도 상태 필드가 없음), (b) 초대는 익명 토큰
// 링크 기반이라 "누가 나를 초대했는지"를 조회하는 API 자체가 없다(게스트
// 참여자를 식별해 저장하지 않는 것이 §2① "초대 발송자가 상대방 정보를
// 미리 알 필요 없는 구조" 설계의 핵심). 따라서 가짜 데이터를 만들지
// 않고 §12-4 권장대로 세그먼트 없이 "최근" 단일 목록으로 구현한다(S48
// 초대받은 탭도 동일 사유로 미구현).
//
// 반면 S46(편집 모드)·S47(삭제 확인 바텀시트)은 서버 API(`DELETE
// /gunghap/results/{resultId}`)가 이미 존재하므로 명세대로 구현한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/gunghap_provider.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/cat_icon.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';
import 'gunghap_result_screen.dart';

class GunghapStoryScreen extends StatefulWidget {
  const GunghapStoryScreen({super.key});

  @override
  State<GunghapStoryScreen> createState() => _GunghapStoryScreenState();
}

class _GunghapStoryScreenState extends State<GunghapStoryScreen> {
  // [S46 편집 모드] AppBar 우측 토글(편집/완료) — 켜면 행마다 우측
  // 44×44 rose ✕ 버튼이 나타나고, 행 탭(결과열람)은 비활성화된다.
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<GunghapProvider>();
    final ok = await provider.fetchMyResults();
    if (!mounted || ok) return;
    final code = provider.errorCode;
    if (code == 'UNAUTHORIZED') {
      AppToast.show(context, '로그인이 필요합니다.', isError: true);
      Navigator.of(context).pushNamed('/login');
      return;
    }
    final isNetworkError = code == 'NETWORK_ERROR';
    AppToast.show(
      context,
      isNetworkError
          ? (provider.error ?? '서비스 연결이 원활하지 않습니다.')
          : (provider.error ?? '궁합스토리를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'),
      isError: true,
      onRetry: _load,
    );
  }

  Future<void> _openResult(String resultId) async {
    // [재조회 — 재생성/재계산/재차감 금지] GunghapResultScreen은
    // fetchResult(resultId)만 호출하는 순수 조회 화면이다 — 새 궁합
    // 계산이나 복주머니 차감이 일어나지 않는다.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GunghapResultScreen(resultId: resultId)),
    );
    // [삭제된 결과 접근 시 안내] 결과 화면에서 삭제된 뒤 돌아왔을 수
    // 있으므로, 복귀 시 목록을 다시 불러와 최신 상태로 갱신한다.
    if (mounted) _load();
  }

  // [S47 삭제 확인 — 00_DEV_MAPPING.md §5 S47] 「이 궁합 기록을 지울까요」
  // 17/700 + 「{A} ✦ {B} · {세부}」 + 「지운 기록은 되돌릴 수 없어요.」 ·
  // Footer 2열 Secondary 「취소」 / 「지우기」(rose 배경). `my-results`
  // 응답에 majorId/subName이 없으므로(route.ts 확인) 「세부」 자리는 실제
  // 내려오는 `relationTypeLabel`로 대체한다(가짜 데이터 금지 원칙).
  // "구매 시" 상세 보고서 경고 문구는 이 목록 응답에 unlocked 필드가
  // 없어 판단 불가능하므로 생략한다.
  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final resultId = item['resultId'] as String?;
    if (resultId == null) return;
    final ownerName = item['ownerName'] as String? ?? '나';
    final guestName = item['guestName'] as String? ?? '상대방';
    final relationTypeLabel = item['relationTypeLabel'] as String?;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _DeleteConfirmSheet(
        ownerName: ownerName,
        guestName: guestName,
        subLabel: relationTypeLabel,
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final provider = context.read<GunghapProvider>();
    final ok = await provider.deleteResult(resultId);
    if (!mounted) return;

    if (!ok) {
      final code = provider.errorCode;
      final message = switch (code) {
        'NOT_FOUND' => '이미 삭제된 결과예요.',
        'FORBIDDEN' => '내가 만든 궁합 결과만 삭제할 수 있어요.',
        'NETWORK_ERROR' => provider.error ?? '서비스 연결이 원활하지 않습니다.',
        _ => provider.error ?? '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      };
      AppToast.show(context, message, isError: true);
      // [NOT_FOUND인데 화면엔 아직 남아있던 경우] 서버·클라이언트 상태가
      // 어긋난 것이므로 목록을 다시 불러와 동기화한다.
      if (code == 'NOT_FOUND') _load();
      return;
    }
    // [삭제 후 목록 갱신] Provider.deleteResult가 이미 로컬 myResults에서
    // 해당 항목을 제거했으므로 이 화면은 자동으로 갱신된다(context.watch).
    AppToast.show(context, '삭제했어요.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();

    return GHScreen(
      bottomNav: const MainBottomNavBar(currentIndex: 3),
      // [S25 — 00_DEV_MAPPING.md 579줄 "AppBar 「내 궁합」 + 우
      // 「편집」/「완료」(14/600)"] 타이틀을 기존 "궁합스토리"에서
      // 명세의 "내 궁합"으로 변경하고, 우측에 편집/완료 토글 버튼을
      // 추가한다(목록이 비어있으면 편집할 것이 없으므로 숨긴다).
      appBar: GHAppBar(
        title: '내 궁합',
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          if (provider.myResults.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _editMode = !_editMode),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _editMode ? '완료' : '편집',
                  style: GHText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: GHColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
      child: _buildBody(provider),
    );
  }

  Widget _buildBody(GunghapProvider provider) {
    if (provider.isLoadingMyResults && provider.myResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: GHColors.gold)),
      );
    }

    if (provider.error != null && provider.myResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Text(
              '궁합스토리를 불러오지 못했어요.',
              style: GHText.ui(size: 14, color: GHColors.gray),
            ),
            const SizedBox(height: 16),
            GHButton(label: '다시 시도', onPressed: _load, expand: false),
          ],
        ),
      );
    }

    if (provider.myResults.isEmpty) {
      // [S25 빈 상태 — 00_DEV_MAPPING.md 583줄 "StarMap 50% + 「아직
      // 이어진 별이 없어요」 + md 「궁합 분석 시작하기」"] 기존 ✦
      // 글자 + 문구에서 StarMap 배경(50% 투명도) + 명세 문구 + 홈으로
      // 이동하는 md 버튼으로 보강한다.
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Opacity(
              opacity: .5,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: StarMap(draw: false, labels: false),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '아직 이어진 별이 없어요',
              style: GHText.cardTitle(size: 16, color: GHColors.ivory),
            ),
            const SizedBox(height: 8),
            Text(
              '궁합을 확인하면 이곳에 기록이 쌓여요.',
              textAlign: TextAlign.center,
              style: GHText.ui(size: 13, color: GHColors.gray),
            ),
            const SizedBox(height: 18),
            GHButton(
              label: '궁합 분석 시작하기',
              size: GHButtonSizeT.md,
              expand: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RefreshIndicator(
            color: GHColors.gold,
            backgroundColor: GHColors.cardSolid,
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              itemCount: provider.myResults.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = provider.myResults[i];
                final resultId = item['resultId'] as String? ?? '';
                final isDeleting = provider.deletingResultId == resultId;
                return _StoryRow(
                  item: item,
                  deleting: isDeleting,
                  editMode: _editMode,
                  onTap: (isDeleting || _editMode) ? null : () => _openResult(resultId),
                  onDelete: isDeleting ? null : () => _confirmDelete(item),
                );
              },
            ),
          ),
        ),
        // [S25 캐션 — 00_DEV_MAPPING.md 584줄 §12-7] "저장" 탭/90일 보관
        // 정책은 §12-7에서 "정책 확정 전 숨김"을 권장하므로(이
        // 프로젝트 서버가 보관기간/영구저장 여부를 구분하지 않음) 표시하지
        // 않는다(사실과 다른 문구를 보여주지 않기 위함).
      ],
    );
  }
}

/// [S47 삭제 확인 시트] 「이 궁합 기록을 지울까요」 17/700 +
/// 「{A} ✦ {B} · {세부}」 + 「지운 기록은 되돌릴 수 없어요.」 · Footer 2열
/// Secondary 「취소」 / 「지우기」(rose 배경).
class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet({
    required this.ownerName,
    required this.guestName,
    required this.subLabel,
  });
  final String ownerName;
  final String guestName;
  final String? subLabel;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: GHGradients.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GHRadius.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GHColors.lineSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '이 궁합 기록을 지울까요',
            textAlign: TextAlign.center,
            style: GHText.cardTitle(size: 17, color: GHColors.fg),
          ),
          const SizedBox(height: 8),
          Text(
            subLabel != null ? '$ownerName ✦ $guestName · $subLabel' : '$ownerName ✦ $guestName',
            textAlign: TextAlign.center,
            style: GHText.ui(size: 13.5, color: GHColors.gray),
          ),
          const SizedBox(height: 6),
          Text(
            '지운 기록은 되돌릴 수 없어요.',
            textAlign: TextAlign.center,
            style: GHText.ui(size: 12.5, color: GHColors.rose),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: GHButton(
                  label: '취소',
                  variant: GHButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DangerButton(
                  label: '지우기',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({
    required this.item,
    required this.deleting,
    required this.editMode,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final bool deleting;
  // [S46 편집 모드] true면 행 탭을 비활성화하고 우측에 44×44 rose
  // ✕ 버튼을 노출한다(00_DEV_MAPPING.md 587줄).
  final bool editMode;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    // [상대방 이름 원칙] resultType과 무관하게 항상 guestName을 사용한다
    // (DIRECT는 ownerName이 항상 null — gunghap_repository.dart 참고).
    final guestName = item['guestName'] as String? ?? '상대방';
    final resultType = item['resultType'] as String?;
    final relationTypeLabel = item['relationTypeLabel'] as String?;
    final grade = item['grade'] as String?;
    final createdAtRaw = item['createdAt'] as String?;
    final dateLabel = _formatDate(createdAtRaw);

    return Opacity(
      opacity: deleting ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: GHColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GHColors.lineSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: GHColors.bg2.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GHColors.divider),
                ),
                alignment: Alignment.center,
                child: const CatIcon(kind: 'heart', size: 28, active: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            guestName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GHText.cardTitle(size: 15),
                          ),
                        ),
                        if (resultType == 'DIRECT') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: GHColors.violet.withValues(alpha: .5),
                              ),
                            ),
                            child: Text(
                              'DIRECT',
                              style: GHText.mono(size: 8.5, color: GHColors.violetText),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (relationTypeLabel != null) ...[
                          Flexible(
                            child: Text(
                              relationTypeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GHText.ui(size: 12, color: GHColors.gold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('·', style: GHText.ui(size: 12, color: GHColors.gray)),
                          const SizedBox(width: 6),
                        ],
                        if (dateLabel != null)
                          Text(
                            dateLabel,
                            style: GHText.mono(size: 9.5, color: GHColors.gray),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (grade != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GHColors.gold.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: GHColors.gold.withValues(alpha: .5)),
                  ),
                  child: Text(
                    grade,
                    style: GHText.ui(size: 11.5, weight: FontWeight.w700, color: GHColors.gold),
                  ),
                ),
              ],
              if (editMode) ...[
                const SizedBox(width: 8),
                deleting
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: GHColors.rose,
                            ),
                          ),
                        ),
                      )
                    : InkResponse(
                        onTap: onDelete,
                        radius: 24,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: GHColors.rose.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: GHColors.rose.withValues(alpha: .45),
                            ),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: GHColors.rose,
                          ),
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return DateFormat('yyyy.MM.dd').format(local);
  }
}

/// [S47 Footer 「지우기」] `GHButtonVariant`에 rose(경고) 배경 버튼이 없으므로
/// (기존 열거형을 건드리지 않기 위해) 동일한 시각 언어(GHRadius.button ·
/// GHButton.button 텍스트 스타일 · 44 높이 터치 영역)로 로컬 전용 위젯을
/// 둔다 — 이 파일 밖에서는 쓰이지 않는 S47 전용 1회성 버튼.
class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      constraints: const BoxConstraints(minHeight: GHButtonSize.lg),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GHColors.rose,
        borderRadius: BorderRadius.circular(GHRadius.button),
      ),
      child: Text(label, style: GHText.button(size: 15.5, color: Colors.white)),
    ),
  );
}
