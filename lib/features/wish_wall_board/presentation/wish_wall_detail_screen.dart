import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import '../widgets/blessing_bag_bottom_sheet.dart';
import '../widgets/wish_wall_candle.dart';
import '../widgets/wish_wall_seal.dart';
import '../widgets/wish_wall_sigil.dart';

/// 02. 소원 상세 화면.
///
/// [디자인 히스토리] 옛 "신통방통 소원방"(wish_room) `WishRoomDetailScreen`의
/// 화면 구성(상단 마법진 + 촛불 연소 시각화 + 인장 + 두루마리풍 본문 카드 +
/// 간절함 별점 + 3분할 통계 타일 + 큰 액션 버튼들)을 그대로 재현한다.
/// 옛 화면의 "얹힌 조각"(화폐) 통계와 "복 나눔"(화폐 소비) 버튼은 지금
/// 시스템의 복주머니 언어("복주머니" 통계 + 복주머니 보내기 버튼)로
/// 대체했고, 화폐를 만들지 않는 응원/오늘의기도 액션은 그대로 유지한다.
class WishWallDetailScreen extends StatefulWidget {
  const WishWallDetailScreen({super.key, required this.wishId});
  final String wishId;

  @override
  State<WishWallDetailScreen> createState() => _WishWallDetailScreenState();
}

class _WishWallDetailScreenState extends State<WishWallDetailScreen> {
  WishPost? _wish;
  List<WishComment> _comments = [];
  bool _loading = true;
  final _commentController = TextEditingController();
  bool _burst = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<WishWallProvider>();
    final wish = await provider.fetchDetail(widget.wishId);
    final comments = await provider.fetchComments(widget.wishId);
    if (!mounted) return;
    setState(() {
      _wish = wish;
      _comments = comments;
      _loading = false;
    });
  }

  Future<void> _doSupport() async {
    final wish = _wish;
    if (wish == null || wish.hasSupportedByMe) return;
    setState(() => _burst = true);
    final updated = await context.read<WishWallProvider>().support(wish.id);
    if (!mounted) return;
    setState(() => _wish = updated);
  }

  Future<void> _doPray() async {
    final wish = _wish;
    if (wish == null || wish.hasPrayedToday) return;
    final updated = await context.read<WishWallProvider>().pray(wish.id);
    if (!mounted) return;
    setState(() => _wish = updated);
  }

  Future<void> _doPouch() async {
    final wish = _wish;
    if (wish == null) return;
    final sent = await showBlessingBagBottomSheet(context, wish: wish);
    if (sent == true) {
      final refreshed =
          await context.read<WishWallProvider>().fetchDetail(wish.id);
      if (mounted) setState(() => _wish = refreshed);
    }
  }

  Future<void> _doComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _wish == null) return;
    final comment =
        await context.read<WishWallProvider>().addComment(_wish!.id, text);
    _commentController.clear();
    setState(() => _comments = [comment, ..._comments]);
  }

  int get _daysLit {
    final wish = _wish;
    if (wish == null) return 0;
    final days = DateTime.now().difference(wish.createdAt).inDays;
    return days < 1 ? 1 : days;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: WishWallColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: WishWallColors.accent),
        ),
      );
    }
    final wish = _wish;
    if (wish == null) {
      return Scaffold(
        backgroundColor: WishWallColors.bg,
        appBar: AppBar(backgroundColor: WishWallColors.bg, elevation: 0),
        body: Center(
          child: Text('이 소원은 더 이상 없어요', style: WishWallText.body()),
        ),
      );
    }

    final intensity = (wish.glassLevel * 5).round().clamp(0, 5);

    return Scaffold(
      backgroundColor: WishWallColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.5),
              child: WishWallSigil(
                size: 340,
                color: WishWallColors.accent,
                opacity: 0.2,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: WishWallColors.ink,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'WISH · 소원 상세',
                          textAlign: TextAlign.center,
                          style: WishWallText.mono(),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showMoreSheet(context, wish),
                        icon: const Icon(Icons.more_horiz, color: WishWallColors.ink),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                    children: [
                      const SizedBox(height: 8),
                      // 옛 상세 화면의 촛불 연소 시각화 — 감사(이룸) 표시가
                      // 아니면 불이 켜지고, 밝힌 일수에 비례해 촛농이 흐른다.
                      Center(
                        child: WishWallCandle(
                          size: 84,
                          lit: !wish.isGratitude,
                          melted: wish.isGratitude
                              ? 0
                              : (_daysLit.clamp(0, 30) / 2),
                          color: wish.categoryId.lightColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: WishWallSeal(
                          text: wish.categoryId.sealChar,
                          color: wish.categoryId.lightColor,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: wish.isAnonymous
                                    ? WishWallColors.bg3
                                    : WishWallColors.accentSoft,
                                border: Border.all(color: WishWallColors.line),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                wish.isAnonymous ? '?' : wish.authorAvatarEmoji,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              wish.displayName,
                              style: WishWallText.body().copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '· ${_timeAgo(wish.createdAt)} 전',
                              style: WishWallText.caption(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: WishWallColors.bg2,
                          border: Border.all(color: WishWallColors.line),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"${wish.text}"',
                              style: WishWallText.bodyLarge().copyWith(height: 1.5),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: List.generate(5, (i) {
                                final on = i < intensity;
                                return Icon(
                                  on ? Icons.star_rounded : Icons.star_border_rounded,
                                  size: 16,
                                  color: on
                                      ? WishWallColors.accent
                                      : WishWallColors.muted,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: wish.isGratitude ? '이루어짐' : '밝힌 지',
                              value: wish.isGratitude ? '成' : '${_daysLit}일',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              label: '응원',
                              value: _fmtCount(wish.supportCount),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              label: '복주머니',
                              value: _fmtCount(wish.pouchCount),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _BigAction(
                              active: wish.hasSupportedByMe,
                              onTap: _doSupport,
                              icon: '♥',
                              label: wish.hasSupportedByMe ? '함께 빌었어요' : '🕯 함께 빌기',
                              color: WishWallColors.red,
                              showBurst: _burst,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BigAction(
                              active: wish.hasPrayedToday,
                              onTap: _doPray,
                              icon: '✧',
                              label: wish.hasPrayedToday ? '오늘 기도함' : '오늘의 기도',
                              color: WishWallColors.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BigAction(
                              onTap: _doPouch,
                              icon: '✨',
                              label: '❖ 복 나눔',
                              color: WishWallColors.accent2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: WishWallColors.line)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '응원 댓글',
                              style: WishWallText.body().copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${_comments.length}', style: WishWallText.caption()),
                          ],
                        ),
                      ),
                      if (_comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Column(
                            children: [
                              Text(
                                '첫 응원을 남겨보세요',
                                textAlign: TextAlign.center,
                                style: WishWallText.caption(color: WishWallColors.muted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '마음의 촛불이 하나 더 켜져요',
                                textAlign: TextAlign.center,
                                style: WishWallText.caption(color: WishWallColors.dim),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._comments.map((c) => _CommentRow(comment: c)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: WishWallColors.bg2,
          border: Border(top: BorderSide(color: WishWallColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: WishWallColors.bg2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: WishWallColors.line),
                ),
                child: TextField(
                  controller: _commentController,
                  onSubmitted: (_) => _doComment(),
                  style: WishWallText.body(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '따뜻한 응원을 남겨보세요',
                    hintStyle: WishWallText.body(color: WishWallColors.dim),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _commentController,
              builder: (context, value, _) {
                final enabled = value.text.trim().isNotEmpty;
                return InkWell(
                  onTap: enabled ? _doComment : null,
                  borderRadius: BorderRadius.circular(17),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: enabled ? WishWallColors.accent : WishWallColors.line2,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '보내기',
                      style: WishWallText.label(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, WishPost wish) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WishWallColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: WishWallColors.ink),
                title: Text('신고하기', style: WishWallText.body()),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportSheet(context, wish);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: WishWallColors.ink,
                ),
                title: Text('이 소원 숨기기', style: WishWallText.body()),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.read<WishWallProvider>().hideWish(wish.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: WishWallColors.ink),
                title: Text('작성자 차단하기', style: WishWallText.body()),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.read<WishWallProvider>().blockUser(wish.authorId);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showReportSheet(BuildContext context, WishPost wish) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WishWallColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text('신고 사유를 선택해주세요', style: WishWallText.title2()),
              ),
              ...wishReportReasons.map(
                (reason) => ListTile(
                  title: Text(reason, style: WishWallText.body()),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await context
                        .read<WishWallProvider>()
                        .reportWish(wish.id, reason);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('신고가 접수되었습니다')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WishWallColors.bg2,
        border: Border.all(color: WishWallColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: WishWallText.title2().copyWith(fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(label, style: WishWallText.caption()),
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.label,
    required this.color,
    this.active = false,
    this.onTap,
    this.showBurst = false,
  });

  final String icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback? onTap;
  final bool showBurst;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.094) : WishWallColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.27) : WishWallColors.line,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Text(
                  icon,
                  style: TextStyle(
                    fontSize: 20,
                    color: active ? color : WishWallColors.ink,
                  ),
                ),
                if (showBurst)
                  Positioned(top: -14, child: _RiseHeart(color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: WishWallText.family,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: active ? color : WishWallColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiseHeart extends StatefulWidget {
  const _RiseHeart({required this.color});
  final Color color;

  @override
  State<_RiseHeart> createState() => _RiseHeartState();
}

class _RiseHeartState extends State<_RiseHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -18 * t),
            child: Icon(Icons.favorite, size: 14, color: widget.color),
          ),
        );
      },
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});
  final WishComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: comment.isMine
                  ? WishWallColors.accentSoft
                  : WishWallColors.bg3,
              border: Border.all(color: WishWallColors.line),
            ),
            alignment: Alignment.center,
            child: Text(
              comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
              style: TextStyle(
                fontFamily: WishWallText.family,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: comment.isMine
                    ? WishWallColors.accent2
                    : WishWallColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: WishWallText.body().copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${_timeAgo(comment.createdAt)}',
                      style: WishWallText.caption(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: WishWallText.body().copyWith(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtCount(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '${(n / 1000).round()}k';
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  final mins = diff.inMinutes;
  if (mins < 1) return '방금';
  if (mins < 60) return '${mins}분';
  if (mins < 60 * 24) return '${diff.inHours}시간';
  return '${diff.inDays}일';
}
