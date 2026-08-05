import 'dart:collection';
import 'package:flutter/material.dart';

/// [재화 구조 정리 - 복주머니 적립/차감 토스트]
/// 모든 화면(홈/마이페이지/커뮤니티/운세결과/부적/상담 등)에서 공용으로 사용하는
/// 복주머니 적립/차감/부족 알림 위젯. 시스템 알림(SnackBar)처럼 딱딱하게 보이지
/// 않도록, 라인 아이콘 + 부드러운 파스텔 배경의 전용 카드로 구현한다.
///
/// 사용법: main.dart/app.dart의 MaterialApp.builder에서
/// `LuckPouchToastOverlay(child: child)`로 앱 전체를 감싸두면, 이후 어디서든
/// `LuckPouchToastController.instance.showEarn(...)` 등을 호출하기만 하면
/// 화면 위에 토스트가 뜬다(개별 화면이 자체 SnackBar/Dialog를 만들 필요 없음).
enum LuckPouchToastType { earn, spend, insufficient }

class LuckPouchToastEntry {
  final int id;
  final LuckPouchToastType type;
  final String title;
  final String subtitle;

  LuckPouchToastEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
  });
}

class LuckPouchToastController extends ChangeNotifier {
  LuckPouchToastController._();
  static final LuckPouchToastController instance = LuckPouchToastController._();

  final Queue<LuckPouchToastEntry> _queue = Queue<LuckPouchToastEntry>();
  LuckPouchToastEntry? _current;
  int _nextId = 0;

  LuckPouchToastEntry? get current => _current;

  void _enqueue(LuckPouchToastType type, String title, String subtitle) {
    final entry = LuckPouchToastEntry(
      id: _nextId++,
      type: type,
      title: title,
      subtitle: subtitle,
    );
    _queue.add(entry);
    if (_current == null) {
      _playNext();
    }
  }

  void _playNext() {
    if (_queue.isEmpty) {
      _current = null;
      notifyListeners();
      return;
    }
    _current = _queue.removeFirst();
    notifyListeners();
    Future.delayed(
      const Duration(milliseconds: 1700),
      _dismissCurrentAndPlayNext,
    );
  }

  void _dismissCurrentAndPlayNext() {
    _current = null;
    notifyListeners();
    // 종료 애니메이션(약 220ms)이 끝난 뒤 다음 토스트를 순차로 재생한다.
    Future.delayed(const Duration(milliseconds: 240), _playNext);
  }

  /// 복주머니 적립 토스트. [reason]은 "게시글 작성 보상", "출석 체크" 같은 짧은 사유.
  void showEarn(int amount, String reason) {
    _enqueue(LuckPouchToastType.earn, '복주머니 +$amount개', '$reason로 복주머니가 쌓였어요');
  }

  /// 복주머니 차감 토스트. [reason]은 "응원 보내기", "부적 만들기" 같은 짧은 사유.
  void showSpend(int amount, String reason) {
    _enqueue(LuckPouchToastType.spend, '복주머니 -$amount개', '$reason에 사용했어요');
  }

  /// 복주머니 부족 안내 토스트.
  void showInsufficient({String? reason}) {
    _enqueue(
      LuckPouchToastType.insufficient,
      '복주머니가 부족해요',
      reason ?? '활동으로 모으거나 충전해 보세요',
    );
  }
}

/// [디자인 규격] bg #F6F5FA, accent #C6F24E, 메인텍스트 #111111,
/// 보조텍스트 #6B6B75, radius 16~20, padding 14~16. 네온/그림자 과다/컨페티
/// 금지 — 라인 아이콘 + 옅은 그림자만 사용한다.
class LuckPouchToastOverlay extends StatefulWidget {
  final Widget child;
  const LuckPouchToastOverlay({required this.child, super.key});

  @override
  State<LuckPouchToastOverlay> createState() => _LuckPouchToastOverlayState();
}

class _LuckPouchToastOverlayState extends State<LuckPouchToastOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: LuckPouchToastController.instance,
              builder: (context, _) {
                final entry = LuckPouchToastController.instance.current;
                return Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, -0.12),
                          end: Offset.zero,
                        ).animate(animation);
                        final scale = Tween<double>(
                          begin: 0.94,
                          end: 1.0,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slide,
                            child: ScaleTransition(scale: scale, child: child),
                          ),
                        );
                      },
                      child: entry == null
                          ? const SizedBox.shrink(key: ValueKey('empty'))
                          : _LuckPouchToastCard(
                              entry: entry,
                              key: ValueKey(entry.id),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LuckPouchToastCard extends StatelessWidget {
  final LuckPouchToastEntry entry;
  const _LuckPouchToastCard({required this.entry, super.key});

  static const _bg = Color(0xFFF6F5FA);
  static const _accent = Color(0xFFC6F24E);
  static const _mainText = Color(0xFF111111);
  static const _subText = Color(0xFF6B6B75);

  IconData get _icon {
    switch (entry.type) {
      case LuckPouchToastType.earn:
        return Icons.auto_awesome_outlined;
      case LuckPouchToastType.spend:
        return Icons.check_circle_outline;
      case LuckPouchToastType.insufficient:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 18, color: _mainText),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        color: _mainText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      style: const TextStyle(color: _subText, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
