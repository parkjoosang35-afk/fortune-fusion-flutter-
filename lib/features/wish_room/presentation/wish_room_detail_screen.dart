import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../shop/domain/shop_item_visuals.dart';
import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/blessing_bag_bottom_sheet.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_buttons.dart';
import '../widgets/wish_room_candle.dart';
import '../widgets/wish_room_candle_ignite_overlay.dart';
import '../widgets/wish_room_growth_widgets.dart';
import '../widgets/wish_room_item_meaning_card.dart';
import '../widgets/wish_room_rise_heart.dart';
import '../widgets/wish_room_seal.dart';
import '../widgets/wish_room_seal_mapping.dart';
import 'wish_room_celebration_screen.dart';
import 'wish_room_comments_screen.dart';

/// 소원방(Wish Room) — 05. 소원 상세(Detail) 화면.
///
/// [디자인 핸드오프 — pixel-perfect 재현] `wish-screens.jsx`의
/// `ScreenDetail` 컴포넌트를 그대로 재구현한다: 상단 nav(←/`WISH · N°NN`/⋯)
/// → 히어로 캔들(90px+radial glow) → 소원카드(날짜eyebrow+본문+3 pill) →
/// 간절함 게이지(★★★★☆+progress bar) → 액션 버튼 → quote footer(dashed
/// border).
///
/// [STEP04 PART2 §6 — 내/타인 소원 겸용 구조 결정]
/// 이 화면은 "내 소원"과 "다른 사람 소원" 상세를 겸용한다(홈 화면의 내
/// 소원 목록과, Feed의 다른 사람 소원 목록이 모두 이 화면으로 push된다).
/// 서버 `toWishDto()`가 이미 `isMine`(로그인 사용자 본인 소원 여부)을
/// 내려주므로([WishPost.isMine]), 이 값으로 액션 버튼 구성을 분기한다:
/// - 내 소원(isMine=true): 기존 그대로 "🔥 소원 더하기"(응원)+"✿ 이뤄졌어요".
/// - 다른 사람 소원(isMine=false): "💛 함께 응원하기"/"✨ 함께 응원했어요"+
///   "🎁 복주머니 보내기" — "이뤄졌어요"는 소원 당사자만 판단할 수 있는
///   액션이므로 숨긴다(발명 없이 기존 markWishFulfilled를 본인 소원에만
///   노출).
/// 화면을 물리적으로 둘로 쪼개지 않고 조건부 렌더링으로 처리해 중복 화면을
/// 만들지 않는다(사용자 지시 — 중복 화면/역할을 함부로 합치거나 쪼개지
/// 말 것).
///
/// - "🔥 소원 더하기"/"💛 함께 응원하기" → 기존 무료 응원
///   ([WishWallProvider.support])에 매핑한다.
/// - "✿ 이뤄졌어요" → [Phase02-A 클라이언트 연동] 서버에 실제 wishState/
///   fulfilledAt 필드가 생겼으므로, 로컬 확인 다이얼로그 →
///   [WishWallProvider.markWishFulfilled](서버 `PATCH /wishes/:id/fulfilled`,
///   지급+상태갱신을 하나의 트랜잭션으로 처리) → 08
///   [WishRoomCelebrationScreen]으로 push한다. 서버가 실제 지급한
///   grantedAmount를 반환하므로 더 이상 클라이언트가
///   [BlessingBagPolicyAdapter.earnWishFulfilledBonus]를 직접 호출하지
///   않는다(중복 지급 방지 — 서버 트랜잭션 안에서 이미 checkPolicyEligibility
///   로 건당 1회를 판정·지급함). 하드코딩됐던 `daysToFulfill=89`는 제거하고
///   [WishPost.createdAt] 기준 실제 경과일([_daysSince])을 그대로 넘겨준다.
/// - "🎁 복주머니 보내기" → 기존 [showBlessingBagBottomSheet]를 그대로
///   재사용한다(wish_room_home_screen.dart의 `_openBlessingBagSend`와 동일
///   패턴, 새 API/구조 추가 없음).
/// - 간절함의 크기(★/progress) → [WishPost.glow](0.0~1.0, supportCount 기반
///   기존 계산식)를 그대로 재사용해 5단계 별점/게이지로 환산한다(새 필드
///   추가 없이 기존 데이터로 표현).
class WishRoomDetailScreen extends StatefulWidget {
  const WishRoomDetailScreen({super.key, required this.wishId, this.index = 1});

  final String wishId;

  /// 상단 "WISH · N°NN" 표시용 순번(1부터). 목록에서 넘어올 때 위치를
  /// 넘겨주면 표시되고, 없으면 기본값 1을 사용한다.
  final int index;

  @override
  State<WishRoomDetailScreen> createState() => _WishRoomDetailScreenState();
}

class _WishRoomDetailScreenState extends State<WishRoomDetailScreen> {
  WishPost? _wish;
  bool _loading = true;
  bool _busy = false;
  bool _showHeartBurst = false;
  List<WishComment> _comments = [];

  /// [STEP04 PART2 §5] 응원/복주머니 감성 문구. 실제 count는 항상
  /// [WishPost.supportCount]/[WishPost.pouchCount](서버 값)를 그대로 쓰고,
  /// 이 헬퍼는 표현(문구)만 담당한다.
  String _supportCountLabel(int count) {
    if (count <= 0) return '🌙 첫 번째 응원이 되어주세요';
    return '💛 $count명이 함께 빌고 있어요';
  }

  String _pouchCountLabel(int count) {
    if (count <= 0) return '🎁 아직 도착한 복주머니가 없어요';
    return '🎁 $count개의 복주머니가 도착했어요';
  }

  /// [STEP04 PART2 §4] HapticFeedback — 미지원 환경(웹 등)에서 예외가 나도
  /// 화면 흐름에 영향을 주지 않도록 조용히 무시한다.
  Future<void> _safeHaptic() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // 진동 미지원 플랫폼(웹 등) — 안전하게 무시.
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadComments();
  }

  Future<void> _load() async {
    final wish = await context.read<WishWallProvider>().fetchDetail(
      widget.wishId,
    );
    if (!mounted) return;
    setState(() {
      _wish = wish;
      _loading = false;
    });
  }

  /// [소원방 마무리 - Phase A] 응원 3개 미리보기용. 상세 화면 진입 시
  /// 병렬로 불러오고, 전체 목록은 [WishRoomCommentsScreen]에서 다시
  /// 페이징 조회한다(이 화면은 미리보기 용도라 3개만 자르면 됨).
  Future<void> _loadComments() async {
    final comments = await context.read<WishWallProvider>().fetchComments(
      widget.wishId,
    );
    if (!mounted) return;
    setState(() => _comments = comments);
  }

  String get _dateLabel {
    final wish = _wish;
    if (wish == null) return '';
    final d = wish.createdAt;
    return '${d.year} · ${d.month.toString().padLeft(2, '0')} · '
        '${d.day.toString().padLeft(2, '0')} 봉인';
  }

  int get _daysSince {
    final wish = _wish;
    if (wish == null) return 0;
    return DateTime.now().difference(wish.createdAt).inDays + 1;
  }

  /// [STEP04 PART2 §1/§2/§3/§4] 응원하기.
  ///
  /// - 서버가 최종 판단한다: 로컬에서 `hasSupportedByMe`를 강제로 세팅하지
  ///   않고, [WishWallProvider.support]가 반환한 [WishPost]/`alreadySupported`
  ///   값을 그대로 신뢰한다.
  /// - UI에서도 이미 응원한 소원이면 재요청을 막지만(버튼 비활성화 +
  ///   `hasSupportedByMe` 체크), 서버 쪽 중복방지 로직(Like 유니크 제약)이
  ///   최종 방어선이다.
  /// - 신규 응원 성공(alreadySupported==false) 시에만 짧은 하트 연출 +
  ///   Haptic을 실행한다(이미 응원한 소원을 다시 눌러도 재연출하지 않음).
  Future<void> _doSupport() async {
    final wish = _wish;
    if (wish == null || _busy || wish.hasSupportedByMe) return;
    setState(() => _busy = true);
    try {
      final result = await context.read<WishWallProvider>().support(wish.id);
      if (!mounted) return;
      setState(() {
        _wish = result.wish;
        _busy = false;
        if (!result.alreadySupported) _showHeartBurst = true;
      });
      if (!result.alreadySupported) {
        unawaited(_safeHaptic());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wish.isMine ? '내 소원에 정성을 더했어요 💛' : '이 소원을 쓴 사람에게 응원이 전달됐어요 💛',
            ),
          ),
        );
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showHeartBurst = false);
        });
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('오늘은 이미 이 소원에 정성을 더했어요')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('응원에 실패했습니다. 다시 시도해주세요.')));
    }
  }

  /// [소원방 3대 개선 · 요청2 "소원 더하기" 용도 설명] "🔥 소원 더하기"가
  /// 무엇을 하는 버튼인지 몰라 헤매던 문제를 해결하기 위한 안내 다이얼로그.
  /// 실제 동작(support API)을 그대로 설명한다 — 새로운 기능을 추가하지
  /// 않고, 이미 있는 동작을 사용자가 이해할 수 있게 문구만 붙인다.
  /// - 눌러도 복주머니를 주지 않는다(무료 응원, PointPolicy 없음).
  /// - 자기 소원 1건당 딱 1번만 누를 수 있다(서버 Like 유니크 제약).
  /// - 누른 만큼 위의 "간절함의 크기"(★ 게이지) + 소원카드 글로우가 차오른다.
  void _showSupportGuide() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WishRoomColors.backgroundMid,
        title: const Text(
          '🔥 소원 더하기가 뭐예요?',
          style: TextStyle(
            fontFamily: 'NotoSerifKRWish',
            color: WishRoomColors.textPrimary,
            fontSize: 16,
          ),
        ),
        content: const Text(
          '내 소원에 스스로 정성을 더하는 버튼이에요.\n\n'
          '· 누르면 복주머니를 받지는 않아요.\n'
          '· 소원 하나당 딱 한 번만 누를 수 있어요.\n'
          '· 누르면 위의 "간절함의 크기"(★)가 채워지고\n'
          '  소원의 글로우가 더 밝아져요.\n\n'
          '다른 사람의 응원을 받고 싶다면,\n'
          '"모두의 소원방"에서 이 소원에 달린\n'
          '"💛 함께 응원하기"를 받아보세요.',
          style: TextStyle(color: WishRoomColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '알겠어요',
              style: TextStyle(color: WishRoomColors.glow),
            ),
          ),
        ],
      ),
    );
  }

  /// [STEP05-B STEP9-8] 홈 화면 `_handleTodayCandle`과 동일 — 새 보상정책을
  /// 만들지 않고 기존 서버 정책(daily_candle, 1일 1회)만 그대로 호출한다.
  /// [소원방 개편 · 2a] 실제로 새로 촛불을 켠 경우에만 점화 연출을 재생한다
  /// (이미 켠 날은 재연출하지 않음).
  Future<void> _handleTodayCandle() async {
    final policy = context.read<WishWallProvider>().policy;
    final granted = await policy.earnDailyCandleBonus();
    if (!mounted) return;
    if (granted > 0) {
      unawaited(playWishRoomCandleIgnition(context));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          granted > 0 ? '오늘의 촛불을 켰어요 (+$granted 🎁)' : '오늘은 이미 촛불을 켰어요',
        ),
      ),
    );
  }

  Future<void> _openSendPouch() async {
    final wish = _wish;
    if (wish == null) return;
    final sent = await showBlessingBagBottomSheet(context, wish: wish);
    if (sent == true && mounted) {
      final refreshed = await context.read<WishWallProvider>().fetchDetail(
        wish.id,
      );
      if (mounted && refreshed != null) setState(() => _wish = refreshed);
    }
  }

  /// [소원방 3대 개선 · 요청2 어뷰징 방지] "이뤄졌어요"를 소원 작성 직후
  /// 바로 눌러 복주머니만 챙기는 어뷰징을 막기 위한 최소 경과일. 소원을
  /// 봉인한 뒤 최소 3일은 지나야 성취를 기록할 수 있게 한다(값 자체는
  /// 서버 정책이 아니라 클라이언트 UX 가드이며, 서버는 여전히 건당 1회
  /// 지급만 별도로 판정한다).
  static const int _minDaysBeforeFulfillment = 3;

  Future<void> _markFulfilled() async {
    final wish = _wish;
    if (wish == null) return;
    if (_daysSince < _minDaysBeforeFulfillment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '소원을 봉인한 지 $_minDaysBeforeFulfillment일이 지나야 '
            '성취를 기록할 수 있어요 (현재 $_daysSince일째)',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WishRoomColors.backgroundMid,
        title: const Text(
          '소원이 이루어졌나요?',
          style: TextStyle(
            fontFamily: 'NotoSerifKRWish',
            color: WishRoomColors.textPrimary,
          ),
        ),
        content: const Text(
          '"이뤄졌어요"를 누르면 이 소원을 성취로 기록하고\n감사 복주머니를 받아요.',
          style: TextStyle(color: WishRoomColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '아직이에요',
              style: TextStyle(color: WishRoomColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '네, 이루었어요',
              style: TextStyle(color: WishRoomColors.glow),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await context.read<WishWallProvider>().markWishFulfilled(
        wish.id,
      );
      if (!mounted) return;
      setState(() => _wish = result.wish);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성취 처리에 실패했습니다. 다시 시도해주세요.')),
      );
      return;
    }
    if (!mounted) return;
    // [Phase 01 · 2단계 · orphan 화면 연결] 지급된 복주머니 개수는
    // 08 Celebration 화면이 아니라 이 push 이전에 별도로 안내하지 않는다
    // — Celebration 화면 자체가 "성취"라는 큰 순간을 축하하는 전체화면
    // 연출이므로, 적립 안내를 위한 별도 스낵바를 겹쳐 띄우지 않는다
    // (기존 [_ReceivePanel._claim] 등 팝업형 흐름과 달리 이 흐름은 이미
    // 확인 다이얼로그를 거쳤으므로 추가 확인 UI가 필요 없다).
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishRoomCelebrationScreen(
          wishText: wish.text,
          daysToFulfill: _daysSince,
        ),
      ),
    );
  }

  /// [STEP04 PART2 마무리 §2] 신고/차단 메뉴 — 기존 [WishWallProvider.reportWish]/
  /// [hideWish]/[blockUser]를 그대로 재사용한다(신규 API/서버 로직 없음).
  /// 이전 버전은 "신고하기"/"이 소원 숨기기" 2개만 노출했으나, 다른 사람의
  /// 소원(isMine=false)에서는 "작성자 차단하기"도 이미 구현되어 있음에도
  /// 이 화면 메뉴에서 빠져 있었다(`wish_wall_detail_screen.dart`에는 이미
  /// 3개 모두 있었음) — 여기서도 동일하게 3개를 노출해 사용자가 자연스럽게
  /// 찾을 수 있도록 한다. 강하게 노출하지 않기 위해 ⋮(더보기) 안에만
  /// 배치하고, 내 소원(isMine=true)에는 "작성자 차단하기"를 숨긴다(자기
  /// 자신을 차단하는 것은 의미가 없으므로).
  void _showMoreSheet() {
    final wish = _wish;
    if (wish == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: WishRoomColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: WishRoomColors.textPrimary,
                ),
                title: const Text(
                  '신고하기',
                  style: TextStyle(color: WishRoomColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportReasonSheet(wish);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: WishRoomColors.textPrimary,
                ),
                title: const Text(
                  '이 소원 숨기기',
                  style: TextStyle(color: WishRoomColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.read<WishWallProvider>().hideWish(wish.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              if (!wish.isMine)
                ListTile(
                  leading: const Icon(
                    Icons.block,
                    color: WishRoomColors.textPrimary,
                  ),
                  title: const Text(
                    '작성자 차단하기',
                    style: TextStyle(color: WishRoomColors.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await context.read<WishWallProvider>().blockUser(
                      wish.authorId,
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              // [소원방 개편 · 5] 내 소원 삭제 — 내 소원(isMine=true)에서만
              // 노출한다.
              if (wish.isMine)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: WishRoomColors.error,
                  ),
                  title: const Text(
                    '이 소원 삭제하기',
                    style: TextStyle(color: WishRoomColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteWish(wish);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 신고 사유를 실제로 고를 수 있는 선택지 시트. 이전 버전은
  /// `wishReportReasons.first`를 즉시 전송해 사용자가 사유를 선택할 수
  /// 없었던 버그가 있었다 — `wish_wall_detail_screen.dart`의 검증된 패턴을
  /// 그대로 사용한다.
  void _showReportReasonSheet(WishPost wish) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WishRoomColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  '신고 사유를 선택해주세요',
                  style: TextStyle(
                    color: WishRoomColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...wishReportReasons.map(
                (reason) => ListTile(
                  title: Text(
                    reason,
                    style: const TextStyle(color: WishRoomColors.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final provider = context.read<WishWallProvider>();
                    try {
                      await provider.reportWish(wish.id, reason);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('신고가 접수되었어요')),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '신고 처리 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// [소원방 개편 · 5] 삭제 확인 다이얼로그 — 실수 방지를 위해 항상 확인을
  /// 거친 뒤에만 [WishWallProvider.deleteWish]를 호출하고, 성공 시 화면을
  /// 닫는다.
  Future<void> _confirmDeleteWish(WishPost wish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WishRoomColors.backgroundMid,
        title: const Text(
          '소원을 삭제할까요?',
          style: TextStyle(color: WishRoomColors.textPrimary),
        ),
        content: const Text(
          '삭제하면 이 소원은 다시 볼 수 없고, 다른 사람에게도 더 이상\n보이지 않아요.',
          style: TextStyle(color: WishRoomColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(color: WishRoomColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<WishWallProvider>().deleteWish(wish.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('소원을 삭제했어요')));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제 중 문제가 발생했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  /// [소원방 개편 · 3] 이 소원을 응원한 사람 목록을 시트로 보여준다.
  /// 서버 실패/지원 안됨 시 빈 목록이 반환되므로 "불러오는 중" →
  /// "아직 없어요" 두 상태만 다루면 충분하다.
  void _showSupportersSheet(WishPost wish) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WishRoomColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: FutureBuilder<List<WishSupporter>>(
            future: context.read<WishWallProvider>().fetchSupporters(wish.id),
            builder: (context, snapshot) {
              final supporters = snapshot.data ?? const [];
              return SizedBox(
                height: 360,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        '응원해준 사람들',
                        style: TextStyle(
                          color: WishRoomColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: !snapshot.hasData
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: WishRoomColors.glow,
                              ),
                            )
                          : supporters.isEmpty
                          ? const Center(
                              child: Text(
                                '아직 목록을 표시할 수 없어요',
                                style: TextStyle(
                                  color: WishRoomColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: supporters.length,
                              itemBuilder: (context, i) {
                                final s = supporters[i];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.favorite,
                                    color: WishRoomColors.error,
                                    size: 18,
                                  ),
                                  title: Text(
                                    s.nickname,
                                    style: const TextStyle(
                                      color: WishRoomColors.textPrimary,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: WishRoomColors.backgroundDeep,
        body: Center(
          child: CircularProgressIndicator(color: WishRoomColors.glow),
        ),
      );
    }
    final wish = _wish;
    if (wish == null) {
      return Scaffold(
        backgroundColor: WishRoomColors.backgroundDeep,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    WishRoomIconButton(
                      icon: '←',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '소원을 찾을 수 없어요',
                    style: TextStyle(color: WishRoomColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final seal = sealForCategory(wish.categoryId);
    final glow = wish.glow;
    final stars = (glow * 5).round().clamp(0, 5);

    // [복주머니 확장 Phase03 — 인장/촛불 "실사용" 연결] 작성 시 선택한
    // sealItemCode/candleItemCode가 있으면 상점 카탈로그의 실제 글리프/색을
    // 사용하고, 없으면(미선택) 기존 카테고리 기반 기본값을 그대로 쓴다.
    final sealCode = wish.sealItemCode;
    final candleCode = wish.candleItemCode;
    final talismanCode = wish.talismanItemCode;
    final sealGlyph = sealCode != null
        ? sealVisualFor(sealCode).glyph
        : seal.glyph;
    final candleColor = candleCode != null
        ? candleColorFor(candleCode)
        : WishRoomColors.glow;
    final talismanVisual = talismanCode != null
        ? talismanVisualFor(talismanCode)
        : null;

    // [STEP05-B STEP9-7 — 상태 감성 문구 / STEP9-2 — 진행률] 홈 화면에서
    // 이미 검증된 wishStateEmotionalLabel()/wishProgressOf()를 그대로
    // 재사용한다(서버 wishState/sealedAt/unlockAt 값은 변경하지 않고
    // 표시용으로만 변환).
    final stateLabel = wishStateEmotionalLabel(wish);
    final progress = wishProgressOf(wish);

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 420, sigilOpacity: 0.28),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      WishRoomIconButton(
                        icon: '←',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'WISH · N°${widget.index.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontFamily: 'IBMPlexMonoWish',
                          fontSize: 10,
                          letterSpacing: 3.0,
                          color: WishRoomColors.textSecondary,
                        ),
                      ),
                      WishRoomIconButton(icon: '⋯', onPressed: _showMoreSheet),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // [STEP05-B STEP9-4/9-5 — 3초 안에 "이게 내 소원인지 남의
                  // 소원인지" + "지금 상태가 뭔지"를 동시에 보여주는 첫 줄.
                  // isMine은 서버 toWishDto()가 내려주는 값을 그대로 읽기만
                  // 한다(§4/§8 요구 — 내/타인 소원 확실히 구분).
                  Row(
                    children: [
                      Text(
                        wish.isMine ? '🌙 나의 소원' : '🌙 함께 빌어주는 소원',
                        style: const TextStyle(
                          fontFamily: 'GowunBatangWish',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: WishRoomColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          stateLabel,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: WishRoomColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Hero candle
                          SizedBox(
                            height: 180,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Positioned(
                                  top: 0,
                                  child: Container(
                                    width: 200,
                                    height: 200,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          WishRoomColors.glowShadow,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                WishRoomCandle(size: 90, color: candleColor),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Wish card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: WishRoomColors.surfaceCard,
                              border: Border.all(
                                color: WishRoomColors.surfaceCardBorder,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _dateLabel,
                                  style: const TextStyle(
                                    fontFamily: 'IBMPlexMonoWish',
                                    fontSize: 10,
                                    letterSpacing: 3.0,
                                    color: WishRoomColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  wish.text,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSerifKRWish',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    height: 1.5,
                                    color: WishRoomColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    WishRoomPill(
                                      label: sealCode != null
                                          ? '$sealGlyph 인장'
                                          : seal.label,
                                    ),
                                    WishRoomPill(label: wish.categoryId.label),
                                    WishRoomPill(label: '$_daysSince일째'),
                                    // [복주머니 확장 Phase03 — 지킴 부적 보호
                                    // 배지, DECISION-004 합리적 판단] 자동
                                    // 지급 로직 없이 "적용 중" 표시로만
                                    // 실사용 의미를 부여한다. "지킴 보호"
                                    // 문구 자체가 guardian 전용 의미이므로
                                    // 조건은 그대로 유지한다.
                                    // [STEP05-B 마무리 — 하드코딩 아이콘
                                    // 제거] '🛡️' 직접 하드코딩 시
                                    // CanvasKit에서 회색 실루엣 버그가
                                    // 발생했다. talismanVisualFor()로
                                    // 다른 화면과 동일한 아이콘(🧿)을
                                    // 사용해 일관성을 확보한다.
                                    if (wish.talismanItemCode ==
                                        'talisman_guardian')
                                      WishRoomPill(
                                        label:
                                            '${talismanVisualFor(wish.talismanItemCode!).icon} 지킴 보호 중',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // [STEP05-B STEP9-6 — 아이템 설명 카드] 실제
                          // 장착된 아이템(candleItemCode/sealItemCode/
                          // talismanItemCode)에 대해서만 "이름 · 역할 · 오늘
                          // 메시지"를 보여준다. 인장은 미선택이어도 카테고리
                          // 기본 seal.glyph가 항상 있으므로 항상 표시한다.
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (candleCode != null) ...[
                                buildCandleMeaningCard(
                                  candleColor: candleColor,
                                ),
                                const SizedBox(height: 8),
                              ],
                              buildSealMeaningCard(glyph: sealGlyph),
                              if (talismanVisual != null) ...[
                                const SizedBox(height: 8),
                                buildTalismanMeaningCard(
                                  visual: talismanVisual,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Intention gauge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: WishRoomColors.surfaceCard,
                              border: Border.all(
                                color: WishRoomColors.surfaceCardBorder,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '간절함의 크기',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                WishRoomColors.textSecondary,
                                          ),
                                        ),
                                        if (wish.isMine) ...[
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: _showSupportGuide,
                                            child: const Icon(
                                              Icons.info_outline,
                                              size: 14,
                                              color:
                                                  WishRoomColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      List.generate(
                                        5,
                                        (i) => i < stars ? '★' : '☆',
                                      ).join(),
                                      style: const TextStyle(
                                        fontFamily: 'IBMPlexMonoWish',
                                        color: WishRoomColors.glow,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Container(
                                    height: 6,
                                    color: WishRoomColors.surfaceCardBorder,
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: glow.clamp(0.05, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              WishRoomColors.accent,
                                              WishRoomColors.glow,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: WishRoomColors.glowShadow,
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // [STEP05-B STEP9-2/9-9 — 성장 트랙] 서버
                                // sealedAt/unlockAt이 모두 있을 때만 표시
                                // 한다(구버전 소원은 progress==null이라
                                // 조용히 생략).
                                if (progress != null) ...[
                                  const SizedBox(height: 12),
                                  GrowthStageTrack(ratio: progress.ratio),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // [STEP04 PART2 §5] 응원/복주머니 감성 카운트
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: wish.supportCount > 0
                                      ? () => _showSupportersSheet(wish)
                                      : null,
                                  child: Text(
                                    wish.supportCount > 0
                                        ? '${_supportCountLabel(wish.supportCount)} · 누가 응원했는지 보기'
                                        : _supportCountLabel(wish.supportCount),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: WishRoomColors.textPrimary,
                                      decoration: wish.supportCount > 0
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _pouchCountLabel(wish.pouchCount),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: WishRoomColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // [STEP04 PART2 §1/§2/§3/§6] Actions — isMine 조건부
                          // 렌더링. 내 소원은 기존 그대로(소원 더하기+이뤄졌어요),
                          // 다른 사람 소원은 응원+복주머니 버튼으로 대체한다.
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              Row(
                                children: wish.isMine
                                    ? [
                                        Expanded(
                                          child: WishRoomSecondaryButton(
                                            label: '🔥 소원 더하기',
                                            onPressed: _busy
                                                ? null
                                                : _doSupport,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: WishRoomSecondaryButton(
                                            label: '✿ 이뤄졌어요',
                                            onPressed: _markFulfilled,
                                          ),
                                        ),
                                      ]
                                    : [
                                        Expanded(
                                          child: WishRoomSecondaryButton(
                                            label: wish.hasSupportedByMe
                                                ? '✨ 함께 응원했어요'
                                                : '💛 함께 응원하기',
                                            onPressed:
                                                (_busy || wish.hasSupportedByMe)
                                                ? null
                                                : _doSupport,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: WishRoomSecondaryButton(
                                            label: '🎁 복주머니 보내기',
                                            onPressed: _openSendPouch,
                                          ),
                                        ),
                                      ],
                              ),
                              if (_showHeartBurst)
                                const Positioned(
                                  top: -20,
                                  child: WishRoomRiseHeart(
                                    color: WishRoomColors.glow,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                          // [STEP05-B STEP9-8 — 오늘의 소원 활동] 내 소원
                          // (isMine=true)에만 표시한다. 타인 소원에는 이미
                          // 위 Actions에 "함께 응원하기"/"복주머니 보내기"가
                          // 있으므로 중복 섹션을 만들지 않는다(§8 요구 —
                          // 내/타인 소원 기능 혼용 금지). 콜백은 홈 화면과
                          // 동일하게 기존 API(policy.earnDailyCandleBonus,
                          // support, showBlessingBagBottomSheet)에만
                          // 연결한다 — 새 정책/화폐 없음.
                          if (wish.isMine) ...[
                            const SizedBox(height: 18),
                            const Text(
                              '🌙 오늘의 소원 활동',
                              style: TextStyle(
                                fontFamily: 'GowunBatangWish',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: WishRoomColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TodayWishActionsRow(
                              onCandle: _handleTodayCandle,
                              onSupport: wish.hasSupportedByMe
                                  ? null
                                  : (_busy ? null : _doSupport),
                              supportLabel: wish.hasSupportedByMe
                                  ? '응원했어요'
                                  : '응원하기',
                              supportEnabled: !wish.hasSupportedByMe,
                              onPouch: _openSendPouch,
                            ),
                          ],
                          const SizedBox(height: 14),
                          // [소원방 마무리 - Phase A] 응원 미리보기 (최대 3개)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: WishRoomColors.surfaceCard,
                              border: Border.all(
                                color: WishRoomColors.surfaceCardBorder,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '응원 ${_comments.length}개',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: WishRoomColors.textSecondary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              WishRoomCommentsScreen(
                                                wishId: wish.id,
                                                wishText: wish.text,
                                              ),
                                        ),
                                      ),
                                      child: const Text(
                                        '전체보기 →',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: WishRoomColors.glow,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_comments.isEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    '아직 응원이 없어요. 첫 응원을 남겨보세요.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: WishRoomColors.textTertiary,
                                    ),
                                  ),
                                ] else ...[
                                  for (final c in _comments.take(3)) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.authorName,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: WishRoomColors
                                                      .textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                c.text,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  height: 1.4,
                                                  color: WishRoomColors
                                                      .textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Quote footer (dashed border)
                          CustomPaint(
                            painter: _DashedRectPainter(
                              color: WishRoomColors.surfaceCardBorder,
                              radius: 12,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: WishRoomColors.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '"간절히 원하면, 온 우주가 도와준다"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'GowunBatangWish',
                                  fontSize: 12,
                                  height: 1.6,
                                  color: WishRoomColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 점선(dashed) 라운드 사각 테두리 — Flutter 기본 [Border]는 점선을
/// 지원하지 않아 `v2-shell.css`의 `border: 1px dashed var(--line)` 표현을
/// 위해 최소한의 커스텀 페인터를 둔다(이 화면에서만 사용, 재사용 필요 시
/// 향후 공용 위젯으로 승격 가능).
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRectPainter({required this.color, this.radius = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashPath = Path();
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashPath.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + dashSpace;
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
