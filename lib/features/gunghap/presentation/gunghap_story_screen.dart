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
import 'gunghap_result_screen.dart';

class GunghapStoryScreen extends StatefulWidget {
  const GunghapStoryScreen({super.key});

  @override
  State<GunghapStoryScreen> createState() => _GunghapStoryScreenState();
}

class _GunghapStoryScreenState extends State<GunghapStoryScreen> {
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

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final resultId = item['resultId'] as String?;
    if (resultId == null) return;
    final guestName = item['guestName'] as String? ?? '상대방';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GHColors.cardSolid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        scrollable: true,
        title: Text(
          '$guestName님과의 궁합을 삭제할까요',
          style: GHText.cardTitle(size: 17, color: GHColors.ivory),
        ),
        content: Text(
          '삭제하면 이 궁합 결과를 다시 볼 수 없어요.',
          style: GHText.ui(size: 13.5, height: 1.55, color: GHColors.gray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('취소', style: GHText.ui(size: 14, color: GHColors.ivory)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('삭제', style: GHText.ui(size: 14, color: GHColors.rose)),
          ),
        ],
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
      appBar: GHAppBar(
        title: '궁합스토리',
        onBack: () => Navigator.of(context).maybePop(),
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
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Text('✦', style: TextStyle(fontSize: 28, color: GHColors.gold)),
            const SizedBox(height: 14),
            Text(
              '아직 저장된 궁합 결과가 없어요',
              style: GHText.cardTitle(size: 16, color: GHColors.ivory),
            ),
            const SizedBox(height: 8),
            Text(
              '궁합을 확인하면 이곳에 기록이 쌓여요.',
              textAlign: TextAlign.center,
              style: GHText.ui(size: 13, color: GHColors.gray),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
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
            onTap: isDeleting ? null : () => _openResult(resultId),
            onDelete: isDeleting ? null : () => _confirmDelete(item),
          );
        },
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({
    required this.item,
    required this.deleting,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final bool deleting;
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
              const SizedBox(width: 4),
              deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GHColors.gray,
                      ),
                    )
                  : InkResponse(
                      onTap: onDelete,
                      radius: 20,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: GHColors.gray,
                        ),
                      ),
                    ),
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
