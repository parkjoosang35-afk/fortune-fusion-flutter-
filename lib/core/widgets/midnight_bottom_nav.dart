// ═══════════════════════════════════════════════════════════════
// FILE: midnight_bottom_nav.dart
// [하단바 리디자인 — design_handoff_bottom_nav.zip "심야의 신전" Variant A]
//
// 기존 app_shell.dart/main_bottom_nav_bar.dart가 각자 들고 있던 화이트
// Material BottomNavigationBar(선택 #111111/비선택 #9A9AA2, 흰 배경)를
// 이 공용 다크 위젯으로 교체하기 위한 컴포넌트. 디자인 핸드오프
// README.md의 수치·색·모션 고정값을 그대로 재현한다(hifi).
//
// 탭 구성(홈/소원방/복주머니/마이)과 "인덱스가 의미하는 라우트"는 기존과
// 100% 동일하게 유지한다 — 이 파일은 "바의 외형과 인터랙션"만 책임지고,
// 실제 탭 전환/네비게이션 로직(IndexedStack 인덱스 변경, push 등)은
// 호출부(AppShell, MainBottomNavBar)가 그대로 담당한다.
//
// [아이콘 렌더링 방식 — README "Assets" 절 그대로 따름]
// 각 아이콘은 default/active 파일이 따로 있고, 이미 자체적으로 단색
// 솔리드 색이 구워져 있다(default: #E8DCC8 불투명, active: #F5CF6A
// 불투명 + 복주머니만 장식용 다이아몬드가 바 배경색(#0E0A14)으로 덮임).
// README는 "<img>로 쓰면 미선택 투명도는 opacity: 0.5로 맞추세요"라고
// 명시한다 — 파일 자체는 완전 불투명이므로, 미선택 아이콘에만 추가로
// Opacity(0.5)를 씌워 디자인 토큰(rgba(232,220,200,.50))과 맞춘다.
// 선택 아이콘은 복주머니의 2색 구조(금빛 주머니 + 어두운 마름모)를
// 깨뜨리면 안 되므로 전체 틴트(ColorFilter 단색 교체)를 하지 않고
// 파일 그대로 사용한다 — README: "복주머니 active는 마름모 문양 때문에
// active 파일을 그대로 사용하세요".
//
// [선택 글로우 — drop-shadow(0 0 6px rgba(245,207,106,.45)) 재현]
// Flutter에는 임의 실루엣을 따라가는 CSS drop-shadow 직접 대응 위젯이
// 없어서, 같은 아이콘을 글로우 색(반투명 골드)으로 단색 틴트한 뒤
// 블러 처리한 사본을 뒤에 깔고 그 위에 원본(색 보존) 아이콘을 얹는
// 2-레이어 스택으로 근사한다. 복주머니의 다이아몬드 컷아웃도 블러
// 레이어에서는 단색으로 뭉개지지만(글로우 용도이므로 무관), 위의 선명한
// 원본 레이어가 실제 보이는 아이콘이라 디테일 손실은 없다.
//
// [배경 블러(backdrop-filter: blur(20px)) — 알려진 근사치]
// README 동작 규칙 04는 "바 배경에 blur 20px, 스크롤 콘텐츠가 바 뒤에서
// 은은하게 비쳐요"를 요구한다. 이를 픽셀 단위로 재현하려면 이 바를 쓰는
// 모든 Scaffold에 `extendBody: true`를 걸고 각 화면의 스크롤 콘텐츠에
// 하단 패딩(`kMidnightNavContentReserve` + safe area)을 일일이 추가해야
// 한다(현재 각 화면은 `bottomNavigationBar:`가 자동으로 밀어내는 비-오버레이
// 레이아웃을 쓰고 있어 바 뒤에 콘텐츠가 깔리지 않는다). 이번 작업
// 범위에서는 하단바 자체의 외형·색·모션·아이콘을 hifi로 맞추는 데
// 집중하고, 이 블러-투과 효과는 위젯에 BackdropFilter를 심어 "나중에
// 개별 화면을 extendBody로 전환하면 자동으로 작동"하도록만 준비해 둔다
// (현재처럼 extendBody 없이 쓰면 블러 대상이 없어 단순 불투명 그라데이션
// 바와 시각적으로 거의 동일하게 보인다 — 바 하단이 어차피 완전 불투명
// #0E0A14라 실사용 체감 차이는 작다).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 디자인 토큰 — README.md "Design Tokens" 표 그대로.
class MidnightNavTokens {
  MidnightNavTokens._();

  static const Color bgBottom = Color(0xFF0E0A14); // --nav-bg-bottom
  static const Color bgTop = Color(0xF50E0B16); // --nav-bg-top rgba(16,11,22,.96)
  static const Color inactive = Color(0x80E8DCC8); // --nav-inactive rgba(232,220,200,.50)
  static const Color active = Color(0xFFF5CF6A); // --nav-active = --glow (캔들 골드)
  static const Color glow = Color(0x73F5CF6A); // --nav-glow rgba(245,207,106,.45)
  static const Color line = Color(0x1EFFEBC8); // --line rgba(255,235,200,.12)

  static const double barTopPad = 2;
  static const double barSidePad = 6;
  static const double tabMinHeight = 58;
  static const double tabPadTop = 11;
  static const double tabPadBottom = 6;
  static const double tabGap = 5;
  static const double iconSize = 26;
  static const double dotSize = 4;

  static const Duration colorTransition = Duration(seconds: 1);
  static const Curve colorCurve = Curves.easeInOut;
  static const Duration pressDuration = Duration(milliseconds: 200);
  static const double pressScale = 0.96;

  /// README 동작 규칙 05: 화면 콘텐츠 하단에 reserve할 패딩
  /// ("60px + safe-area-inset-bottom"). 세이프 에어리어는 호출부가
  /// `MediaQuery.of(context).padding.bottom`을 더해서 쓴다.
  static const double contentReserve = 60;
}

/// 탭 한 개의 정적 정보(아이콘 파일명 기준 key, 라벨). 라우트는 호출부
/// (AppShell/MainBottomNavBar)가 기존처럼 자체 관리하므로 여기엔 없다.
class MidnightNavTabData {
  const MidnightNavTabData({required this.iconKey, required this.label});

  /// `assets/icons/bottom_nav/ic_nav_{iconKey}_{default|active}.svg`의
  /// `{iconKey}` 부분.
  final String iconKey;
  final String label;
}

/// README "탭 매핑" 표 고정 순서 — 홈(0) · 소원방(1) · 복주머니(2) · 마이(3).
/// 기존 app_shell.dart/main_bottom_nav_bar.dart의 `_navItems`와 인덱스
/// 의미가 완전히 동일하다(운세 탭은 이미 삭제되어 있었음).
const List<MidnightNavTabData> kMidnightNavTabs = [
  MidnightNavTabData(iconKey: 'home', label: '홈'),
  MidnightNavTabData(iconKey: 'wishroom', label: '소원방'),
  MidnightNavTabData(iconKey: 'pouch', label: '복주머니'),
  MidnightNavTabData(iconKey: 'my', label: '마이'),
];

String _iconAsset(String key, {required bool active}) =>
    'assets/icons/bottom_nav/ic_nav_${key}_${active ? 'active' : 'default'}.svg';

/// 신통방통 "심야의 신전" 하단 탭바 — 공용 위젯.
///
/// [AppShell]의 `IndexedStack` 하단과, `AppShell` 바깥에서 push된 화면들
/// (정통사주/타로/귀인지도 등)의 `MainBottomNavBar` 양쪽에서 동일하게
/// 쓰인다. 탭을 누르면 항상 [onTap]이 호출되고(기존 동작과 동일), 이미
/// 선택된 탭을 다시 누르면 추가로 [onReselected]도 호출된다(README
/// "같은 탭 다시 탭 → 스크롤 맨 위로" — 실제 스크롤 처리는 호출부 책임).
class MidnightBottomNavBar extends StatelessWidget {
  const MidnightBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onReselected,
    this.tabs = kMidnightNavTabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onReselected;
  final List<MidnightNavTabData> tabs;

  void _handleTap(int index) {
    if (index == currentIndex) {
      onReselected?.call(index);
    }
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Semantics(
      container: true,
      label: '주요 메뉴',
      child: ClipRect(
        child: BackdropFilter(
          // [위 파일 헤더 설명 참고] extendBody 없이 쓰이는 현재 화면들에선
          // 블러 대상이 없어 사실상 no-op이지만, 추후 extendBody 전환 시
          // 자동으로 README 동작 규칙 04(블러 20px)가 작동하도록 남겨둔다.
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              MidnightNavTokens.barSidePad,
              MidnightNavTokens.barTopPad,
              MidnightNavTokens.barSidePad,
              bottomInset,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00140E1A), // rgba(20,14,26,0) — 0%
                  MidnightNavTokens.bgTop, // 18%
                  MidnightNavTokens.bgBottom, // 100%
                ],
                stops: [0, 0.18, 1.0],
              ),
              border: const Border(
                top: BorderSide(color: MidnightNavTokens.line, width: 1),
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _MidnightNavTab(
                      data: tabs[i],
                      selected: i == currentIndex,
                      onTap: () => _handleTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MidnightNavTab extends StatefulWidget {
  const _MidnightNavTab({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final MidnightNavTabData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MidnightNavTab> createState() => _MidnightNavTabState();
}

class _MidnightNavTabState extends State<_MidnightNavTab> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.data.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? MidnightNavTokens.pressScale : 1.0,
          duration: MidnightNavTokens.pressDuration,
          curve: Curves.easeOut,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MidnightNavTokens.tabMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                top: MidnightNavTokens.tabPadTop,
                bottom: MidnightNavTokens.tabPadBottom,
              ),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MidnightNavIcon(
                      iconKey: widget.data.iconKey,
                      selected: selected,
                    ),
                    const SizedBox(height: MidnightNavTokens.tabGap),
                    AnimatedDefaultTextStyle(
                      duration: MidnightNavTokens.colorTransition,
                      curve: MidnightNavTokens.colorCurve,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11,
                        height: 1,
                        letterSpacing: -0.11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? MidnightNavTokens.active
                            : MidnightNavTokens.inactive,
                      ),
                      child: Text(widget.data.label),
                    ),
                    const SizedBox(height: MidnightNavTokens.tabGap),
                    AnimatedContainer(
                      duration: MidnightNavTokens.colorTransition,
                      curve: MidnightNavTokens.colorCurve,
                      margin: const EdgeInsets.only(top: -1),
                      width: MidnightNavTokens.dotSize,
                      height: MidnightNavTokens.dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? MidnightNavTokens.active
                            : Colors.transparent,
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: MidnightNavTokens.active,
                                  blurRadius: 6,
                                ),
                              ]
                            : const [],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 아이콘 표시 — default(선 아이콘, 50% 불투명)/active(채움 아이콘 +
/// 글로우) 상태에 따라 완전히 다른 파일을 그대로 보여준다(위 파일 헤더
/// 설명 참고 — currentColor 틴트가 아니라 파일 교체 방식).
class _MidnightNavIcon extends StatelessWidget {
  const _MidnightNavIcon({required this.iconKey, required this.selected});

  final String iconKey;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const size = MidnightNavTokens.iconSize;
    if (!selected) {
      return Opacity(
        opacity: 0.5,
        child: SvgPicture.asset(
          _iconAsset(iconKey, active: false),
          width: size,
          height: size,
        ),
      );
    }
    final asset = _iconAsset(iconKey, active: true);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 글로우 레이어 — 단색 틴트 + 블러로 drop-shadow 근사.
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
            child: SvgPicture.asset(
              asset,
              width: size,
              height: size,
              colorFilter: const ColorFilter.mode(
                MidnightNavTokens.glow,
                BlendMode.srcIn,
              ),
            ),
          ),
          // 선명한 원본 레이어 — 복주머니의 2색(금빛+다이아몬드) 보존.
          SvgPicture.asset(asset, width: size, height: size),
        ],
      ),
    );
  }
}
