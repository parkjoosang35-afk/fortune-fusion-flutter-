import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/matching_provider.dart';
import '../domain/matching_model.dart';

/// 03§5.3 MatchingDiscoverScreen(카드스와이프, PostListScreen 변형)
/// 06§4.6 GET /matching/recommendations + POST /matching/like 대응
class MatchingDiscoverScreen extends StatefulWidget {
  const MatchingDiscoverScreen({super.key});

  @override
  State<MatchingDiscoverScreen> createState() => _MatchingDiscoverScreenState();
}

class _MatchingDiscoverScreenState extends State<MatchingDiscoverScreen> {
  /// provider.candidatesState의 좋아요 처리분과 별개로, "넘기기(skip)"는 API 대응이
  /// 없으므로(06§4.6에 dislike 엔드행복머니 없음) 로컬 덱에서만 제거해 화면 흐름을 유지한다.
  final List<MatchingCandidateModel> _deck = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<MatchingProvider>().loadRecommendations();
    if (!mounted) return;
    final data = context.read<MatchingProvider>().candidatesState.data;
    setState(() {
      _deck
        ..clear()
        ..addAll(data ?? []);
      _initialized = true;
    });
  }

  /// [3단계 - 행복머니 소비: 운명의 동행] 관심표시 1건당 서버가 point_policies.
  /// matching_like 정책으로 행복머니를 차감한다(정책 없으면 무료). 서버가 이미
  /// 지갑을 트랜잭션으로 갱신했으므로, 클라이언트는 WalletProvider.load()로
  /// 잔액 캐시만 재조회한다(amulet_repository.purchase()와 동일한 "중복차감방지형"
  /// 패턴 - 여기서 spend()를 별도로 또 호출하면 이중 차감이 된다).
  Future<void> _handleLike(MatchingCandidateModel candidate) async {
    setState(() => _deck.removeWhere((c) => c.userId == candidate.userId));
    final result = await context.read<MatchingProvider>().like(
      candidate.userId,
    );
    if (!mounted) return;
    if (!result.success) {
      AppToast.show(context, result.errorMessage ?? '좋아요 처리에 실패했습니다.', isError: true);
      return;
    }
    if (result.balanceAfter != null) {
      // 서버가 이미 차감을 완료했으므로 잔액만 동기화(재차감 아님).
      await context.read<WalletProvider>().load();
    }
    if (!mounted) return;
    if (result.matched) {
      _showMatchedDialog(candidate);
    } else {
      AppToast.show(context, '${candidate.nickname}님에게 관심을 보냈어요.');
    }
  }

  void _handleSkip(MatchingCandidateModel candidate) {
    setState(() => _deck.removeWhere((c) => c.userId == candidate.userId));
  }

  void _showMatchedDialog(MatchingCandidateModel candidate) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 매칭 성사!'),
        content: Text('${candidate.nickname}님과 서로 관심을 확인했어요.\n대화를 시작해보세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('나중에'),
          ),
          AppButton(
            label: '매칭 목록 보기',
            fullWidth: false,
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/ai-fortune/matching/pairs');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MatchingProvider>().candidatesState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 매칭'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded),
            tooltip: '매칭 목록',
            onPressed: () =>
                Navigator.of(context).pushNamed('/ai-fortune/matching/pairs'),
          ),
        ],
      ),
      body: SafeArea(
        child: !_initialized || state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.isError
            ? AppErrorState(
                message: state.errorMessage ?? '추천 대상을 불러오지 못했습니다.',
                onRetry: _load,
              )
            : _deck.isEmpty
            ? AppEmptyState(
                icon: Icons.people_outline_rounded,
                title: '오늘의 추천 대상을 모두 확인했어요',
                description: '내일 새로운 추천 대상을 만나보세요',
                action: AppButton.ghost(label: '다시 불러오기', onPressed: _load),
              )
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (
                            var i = _deck.length - 1;
                            i >= 0 && i >= _deck.length - 3;
                            i--
                          )
                            _buildCard(
                              _deck[i],
                              isTop: i == _deck.length - 1,
                              depth: _deck.length - 1 - i,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundActionButton(
                          icon: Icons.close_rounded,
                          color: AppColors.textHint,
                          onTap: () => _handleSkip(_deck.last),
                        ),
                        const SizedBox(width: AppSpacing.xxl),
                        _RoundActionButton(
                          icon: Icons.favorite_rounded,
                          color: AppColors.primary,
                          onTap: () => _handleLike(_deck.last),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCard(
    MatchingCandidateModel candidate, {
    required bool isTop,
    required int depth,
  }) {
    final card = Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: depth * 10.0),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(candidate.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${candidate.nickname} (${candidate.age})',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            candidate.introText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: candidate.preferences
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    backgroundColor: AppColors.primaryContainer,
                    labelStyle: const TextStyle(color: AppColors.primary),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );

    if (!isTop) return card;

    return Dismissible(
      key: ValueKey(candidate.userId),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _handleLike(candidate);
        } else {
          _handleSkip(candidate);
        }
      },
      background: _swipeHint(
        alignment: Alignment.centerLeft,
        icon: Icons.favorite_rounded,
        color: AppColors.success,
      ),
      secondaryBackground: _swipeHint(
        alignment: Alignment.centerRight,
        icon: Icons.close_rounded,
        color: AppColors.error,
      ),
      child: card,
    );
  }

  Widget _swipeHint({
    required Alignment alignment,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Icon(icon, color: color, size: 40),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}
