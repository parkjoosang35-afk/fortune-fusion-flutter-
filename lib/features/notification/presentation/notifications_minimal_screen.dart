import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../mypage/presentation/theme/mypage_minimal_theme.dart';
import '../../wishroom/features/explore/other_room_screen.dart';
import '../notification_provider.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S11] "알림" 목록 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S11 알림" 스펙에 따른
/// 전면 신규 화면이다. 기존 `NotificationsScreen`(다크 `DarkPage`/
/// `AppEmptyState` 톤, 카드형 리스트)은 README가 요구하는 레이아웃(40px
/// 원형 글리프 + 안읽음 점 + 상단 "모두 읽음" 액션 + 서브화면 공통 셸)과
/// 크게 달라 같은 파일을 리스킨하는 대신 새 파일로 작성했다 — 기존 파일은
/// 프로젝트 관례에 따라 삭제하지 않고 코드베이스에 유지한다. 대신
/// `/my/notifications` 라우트만 이 화면을 가리키도록 app_router.dart를
/// 교체한다(S03/S05/S09와 동일한 "신규 파일 + 라우트만 교체" 패턴).
///
/// 데이터 소스(변경 없음, 기존 Provider 재사용):
/// - [NotificationProvider]: items/isLoading/lastError, load()/markAllRead()/
///   markRead(). [전수검수 2026-10-12 F4]가 확립한 "진입 시 load() 완료 후
///   markAllRead() 호출" 순서도 그대로 유지한다 — README의 "모두 읽음" 버튼은
///   이미 자동으로 전체 읽음 처리된 상태에서는 사실상 멱등 동작이 되지만,
///   서버 응답 전 짧은 미읽음 노출 구간이나 향후 자동 읽음 처리 정책이
///   바뀔 경우를 대비해 수동 트리거도 함께 제공한다("로직은 그대로, 스킨만
///   교체" 원칙 — Provider 메서드 시그니처/호출 순서를 바꾸지 않는다).
class NotificationsMinimalScreen extends StatefulWidget {
  const NotificationsMinimalScreen({super.key});

  @override
  State<NotificationsMinimalScreen> createState() =>
      _NotificationsMinimalScreenState();
}

class _NotificationsMinimalScreenState
    extends State<NotificationsMinimalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      provider.load().then((_) => provider.markAllRead());
    });
  }

  Future<void> _refresh() async {
    final provider = context.read<NotificationProvider>();
    await provider.load();
    await provider.markAllRead();
  }

  /// [알림 실제 발송 연동] 탭 시 서버가 내려준 deepLink("wish:w_123")를 파싱해
  /// 소원 상세 화면으로 이동한다. 기존 NotificationsScreen._handleTap과 동일한
  /// 로직 — 형식이 다르거나 알 수 없는 타입이면 아무 동작도 하지 않는다.
  void _handleTap(BuildContext context, NotificationItem item) {
    context.read<NotificationProvider>().markRead(item.id);
    final deepLink = item.deepLink;
    if (deepLink == null || deepLink.isEmpty) return;
    final parts = deepLink.split(':');
    if (parts.length != 2) return;
    final type = parts[0];
    final targetId = parts[1];
    if (type == 'wish' && targetId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtherRoomScreen(roomId: targetId)),
      );
    }
  }

  /// README S11 목업(prototype/subs.js `noti()`)의 글리프 매핑(印 願 四 福)을
  /// deepLink 타입 접두어로부터 유추한다. 서버 데이터에 별도 glyph 필드가
  /// 없으므로, 현재 앱에서 실제로 쓰이는 deepLink 타입(wish)과 그 외 알려진
  /// 카테고리 키워드만 매핑하고, 알 수 없는 경우 중립 글리프로 대체한다.
  String _glyphFor(NotificationItem item) {
    final type = item.deepLink?.split(':').first;
    switch (type) {
      case 'wish':
        return '願';
      case 'saju':
        return '四';
      case 'wallet':
      case 'pouch':
        return '福';
      case 'attendance':
        return '印';
    }
    return '鈴';
  }

  @override
  Widget build(BuildContext context) {
    final notification = context.watch<NotificationProvider>();
    final items = notification.items;
    final isLoading = notification.isLoading && items.isEmpty;

    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: MyPageColors.red,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              // README "서브화면 공통 셸" 상단바: padding 52 12 10,
              // grid 44 1fr 44, 가운데 타이틀 17px/800, 우측 "모두 읽음".
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 40,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: MyPageColors.ink,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          '알림',
                          textAlign: TextAlign.center,
                          style: MyPageTextStyles.header,
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: items.isEmpty
                            ? null
                            : TextButton(
                                onPressed: () =>
                                    context.read<NotificationProvider>().markAllRead(),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '모두\n읽음',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: MyPageFonts.ui,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    height: 1.2,
                                    color: MyPageColors.ink2,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  MyPageSpacing.subX,
                  6,
                  MyPageSpacing.subX,
                  120,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: MyPageColors.red,
                          ),
                        ),
                      )
                    else if (notification.lastError != null && items.isEmpty)
                      _ErrorState(
                        message: notification.lastError!,
                        onRetry: _refresh,
                      )
                    else if (items.isEmpty)
                      const _EmptyNotifications()
                    else
                      Column(
                        children: [
                          for (final item in items)
                            _NotificationRow(
                              glyph: _glyphFor(item),
                              item: item,
                              onTap: () => _handleTap(context, item),
                            ),
                        ],
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// README §S11 행: 40px 원형 글리프(안읽음이면 우상단 8px 빨강 점) +
/// 제목 15px/800 + 본문 13px/600 + 우상단 시간 11px. 누르면 읽음 처리 +
/// deeplink 이동, 읽은 알림은 opacity .6.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.glyph,
    required this.item,
    required this.onTap,
  });

  final String glyph;
  final NotificationItem item;
  final VoidCallback onTap;

  String _timeLabel() {
    final now = DateTime.now();
    final createdAt = item.createdAt;
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24 && now.day == createdAt.day) {
      return '${diff.inHours}시간 전';
    }
    if (diff.inDays == 1 ||
        (now.day - createdAt.day == 1 && now.month == createdAt.month)) {
      return '어제';
    }
    return '${createdAt.month}월 ${createdAt.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final opacity = item.isRead ? 0.6 : 1.0;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: MyPageColors.redSoft,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          glyph,
                          style: const TextStyle(
                            fontFamily: MyPageFonts.hanja,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: MyPageColors.red,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: MyPageColors.red2,
                              border: Border.all(
                                color: MyPageColors.paper,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontFamily: MyPageFonts.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: MyPageColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.body,
                          style: const TextStyle(
                            fontFamily: MyPageFonts.ui,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.5,
                            color: MyPageColors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timeLabel(),
                    style: const TextStyle(
                      fontFamily: MyPageFonts.ui,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: MyPageColors.ink3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Container(height: 1, color: MyPageColors.hair),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_off_rounded,
            size: 40,
            color: MyPageColors.ink3,
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 도착한 알림이 없어요',
            style: MyPageTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            '새 소식이 오면 이곳에 차곡차곡 쌓여요',
            style: MyPageTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: MyPageColors.red2,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: MyPageTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '다시 시도',
              style: TextStyle(
                fontFamily: MyPageFonts.ui,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: MyPageColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
