// ═══════════════════════════════════════════════════════════════
// FILE: midnight_bottom_nav.dart
// [하단바 리디자인 2차 — design_handoff_sintong_main.zip "Midnight Navy"]
//
// 사용자 요청: "신통방통 전체 하단바도 지금 준걸로 전체 다 바꿔줬으면해"
// — 기존 "심야의 신전" Variant A(어두운 보라/#0E0A14 톤)를, 홈 화면과
// 함께 새로 핸드오프된 Midnight Navy(#0B1326/#070D1B + Champagne
// Gold #D4AF37/#EBD58E) 톤으로 전면 교체한다. 이 위젯은 앱 전역에서
// 공유되므로(AppShell + MainBottomNavBar + 신당/정통사주/궁합 등 여러
// Scaffold가 직접 참조) 한 곳만 고치면 "신통방통 전체 하단바"가 자동으로
// 전부 바뀐다 — 호출부를 일일이 찾아 수정할 필요가 없다.
//
// 탭 구성(홈/신당부적/복주머니/마이)과 "인덱스가 의미하는 라우트"는 이번
// 교체에서도 전혀 건드리지 않는다(README의 새 하단 탭바 레이블도
// "홈 · 신당부적 · 복주머니 · 마이"로 기존과 완전히 동일) — 이 파일은
// "바의 외형과 인터랙션"만 책임지고, 실제 탭 전환/네비게이션 로직
// (IndexedStack 인덱스 변경, push 등)은 호출부(AppShell,
// MainBottomNavBar)가 그대로 담당한다.
//
// [아이콘 교체 — README "하단 탭바" 절] 기존 아이콘(집 모양 실루엣,
// 신당 원뿔모자, 복주머니, 사람 반신)을 새 핸드오프 HTML의 `ic` 객체가
// 정의한 라인 스타일 아이콘(24px, stroke-width 1.5)으로 전부 교체했다
// — 집/문(홈), 부적 방패(신당부적), 복주머니(복주머니), 사람(마이).
// assets/icons/bottom_nav/ 의 8개 SVG 파일명은 그대로 유지하고 내용만
// 새 path로 교체해, 이 Dart 파일이나 kMidnightNavTabs의 iconKey 매핑은
// 전혀 바꾸지 않고도 아이콘만 바뀌도록 했다(최소 변경 원칙).
// 색상도 새 토큰에 맞춰 default #F5F5F0(ivory, opacity .55로 muted
// 재현) / active #EBD58E(gold-hi)로 다시 구웠다 — 신당(神堂) 탭만 별도
// 금색(#c9a368)을 쓰던 이전 예외는, 새 디자인이 탭 전부 동일한
// Champagne Gold 하나만 쓰도록 지정해 제거했다(붉은색 미사용 원칙은
// 그대로 유지, 신당 전용 색 분기만 통합).
//
// [아이콘 자체 글로우 레이어 제거] 이전 "심야의 신전" 버전은 아이콘
// 실루엣 전체에 blur drop-shadow를 근사하기 위해 블러 틴트 레이어 +
// 원본 레이어의 2-레이어 스택을 썼다. 새 README 스펙은 아이콘 자체에는
// 글로우를 요구하지 않고(활성 아이콘은 그냥 단색 #EBD58E), 오직 아이콘
// 아래 4px 금색 점(dot)에만 `0 0 8px #D4AF37` 글로우를 요구한다 — 그래서
// 아이콘은 단일 레이어로 단순화하고, 글로우는 기존처럼 점의
// `BoxShadow`로만 재현한다(코드 단순화, 시각 결과는 스펙과 일치).
//
// [배경 블러(backdrop-filter: blur(14px)) — 알려진 근사치] README는
// "바 배경에 blur 14px"를 요구한다. 픽셀 단위로 재현하려면 이 바를 쓰는
// 모든 Scaffold에 `extendBody: true`를 걸어야 하는데(현재는
// `bottomNavigationBar:`가 자동으로 밀어내는 비-오버레이 레이아웃이라
// 바 뒤에 콘텐츠가 깔리지 않음), 이는 이번 범위를 넘는 광범위한 레이아웃
// 변경이라 기존처럼 BackdropFilter는 심어두되(추후 extendBody 전환 시
// 자동 작동) 당장 체감 차이는 작다 — 바 하단이 어차피 완전 불투명
// #070D1B라 실사용 영향은 미미하다.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 디자인 토큰 — design_handoff_sintong_main.zip README.md
/// "하단 탭바" 절 + "Design Tokens" 표 그대로(Midnight Navy).
class MidnightNavTokens {
  MidnightNavTokens._();

  // [색 — README Design Tokens + 2차 보정] README 원본 navy-2(#070D1B)는
  // 명도가 너무 낮아(luminance ~13/255) 시트 배경(navyTop #0E1830 등)과
  // 거의 구분이 안 되고, 실기기에서 "하단바가 그냥 까맣다"는 피드백을
  // 받았다(사용자 확인). 색조(hue)는 그대로 네이비 블루를 유지하되
  // 명도만 ~2.6배 밝혀 "검정"이 아니라 눈에 띄는 "남색"으로 보이도록
  // 조정했다(README 수치에서 의도적으로 벗어난 보정값 — 사용자 승인).
  static const Color bgBottom = Color(0xFF162544); // 보정 navy(명도 상향)
  static const Color bgTop = Color(0x00162544); // 그라데이션 시작(투명)
  static const Color inactive = Color(0x8CF5F5F0); // rgba(245,245,240,.55)
  static const Color active = Color(0xFFEBD58E); // --gold-hi
  static const Color glow = Color(0xFFD4AF37); // --gold (점 글로우용)
  static const Color line = Color(
    0x24D4AF37,
  ); // --line-soft rgba(212,175,55,.14)

  static const double barTopPad = 12;
  static const double barSidePad = 18;
  static const double tabMinHeight = 54;
  static const double tabPadTop = 0;
  static const double tabPadBottom = 0;
  static const double tabGap = 5;
  static const double iconSize = 24;
  static const double dotSize = 4;

  static const Duration colorTransition = Duration(seconds: 1);
  static const Curve colorCurve = Curves.easeInOut;
  static const Duration pressDuration = Duration(milliseconds: 200);
  static const double pressScale = 0.96;

  /// README "전체 구조" 표: 하단 탭바 높이 92px(패딩 포함). 화면
  /// 콘텐츠 하단에 reserve할 패딩 기준값 — 세이프 에어리어는 호출부가
  /// `MediaQuery.of(context).padding.bottom`을 더해서 쓴다.
  static const double contentReserve = 66;
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
///
/// [신당(神堂) 통합 — A안, 공식 지시서 `01_dev_spec_v1.4.pdf` §3.1~3.2]
/// 1번 슬롯(구 "소원방")의 라벨/아이콘만 "신당부적"으로 교체한다. 탭
/// 개수는 4개 그대로 유지 — 소원방 기능 자체는 폐지되지 않고 하단바
/// 라벨만 빠질 뿐, 홈 카드·마이페이지 등 기존 진입점으로 계속 접근
/// 가능하다(app_shell.dart `_openWishRoom` 등 참고). 아이콘 색상은
/// 지시서 고정값(활성 #c9a368 금색 / 비활성 회색)을 따르며, 신당 내부
/// 붉은색 희소성 보호를 위해 이 탭에는 붉은색을 쓰지 않는다 — 그래서
/// 이 탭만은 `_MidnightNavIcon`의 공용 글로우 틴트(#F5CF6A)가 아니라
/// 아이콘 파일 자체에 #c9a368을 구워 넣어 별도 처리한다(아래
/// `_MidnightNavIcon` 참고).
const List<MidnightNavTabData> kMidnightNavTabs = [
  MidnightNavTabData(iconKey: 'home', label: '홈'),
  MidnightNavTabData(iconKey: 'shrine', label: '신당부적'),
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
    this.badgedIndices = const <int>{},
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onReselected;
  final List<MidnightNavTabData> tabs;

  /// [신당(神堂) 통합 — A안 §3.2 "배지"] 보관 중인 소지부가 있을 때만
  /// 신당 탭 아이콘 오른쪽 위에 금색 점(6px)을 표시한다. 호출부
  /// (AppShell)가 `ShrineSessionProvider.state.kept`를 watch해 이 인덱스
  /// 집합을 넘긴다. 다른 탭에도 재사용 가능하도록 일반화된 Set으로 둔다.
  final Set<int> badgedIndices;

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
      // [버그 수정 — 정통사주 진입 시 화면 깜박거림(APK 실기기 리포트)]
      // 원인: Android 기본 렌더러 Impeller가 "애니메이션 중인 ClipPath
      // (sajuDimensionEnterRoute의 원형 확산 진입 전환) 안에 BackdropFilter가
      // 있는" 조합에서 매 프레임 블러 레이어를 재합성하며 깜빡임을 일으키는
      // 알려진 엔진 결함이다(Flutter 공식 이슈 #165106 등 — Impeller가
      // Android API 29+ 기본 렌더러로 전환된 이후 보고됨). 이 하단바
      // (MidnightBottomNavBar)는 타로/귀인지도 등 다른 화면에서도 동일하게
      // 쓰이지만, 그 화면들의 진입 전환은 Clip 애니메이션을 쓰지 않아
      // 증상이 드러나지 않았을 뿐 — 즉 하단바 자체의 구조적 문제이므로
      // 화면별 땜질이 아니라 이 공용 위젯 한 곳에서 고친다.
      // [해법] BackdropFilter 서브트리를 RepaintBoundary로 격리해 별도
      // 레이어로 캐시한다 — Impeller가 이 레이어를 ClipPath 애니메이션과
      // 분리해서 합성하게 되어 재깜빡임이 사라진다(Flutter 팀이 권장하는
      // 표준 우회법). 디자인·색상·블러 반경·레이아웃은 전혀 바뀌지 않는다.
      child: RepaintBoundary(
        child: ClipRect(
          child: BackdropFilter(
            // [위 파일 헤더 설명 참고] extendBody 없이 쓰이는 현재 화면들에선
            // 블러 대상이 없어 사실상 no-op이지만, 추후 extendBody 전환 시
            // 자동으로 README "하단 탭바" 절(블러 14px)이 작동하도록 남겨둔다.
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                MidnightNavTokens.barSidePad,
                MidnightNavTokens.barTopPad,
                MidnightNavTokens.barSidePad,
                bottomInset,
              ),
              decoration: const BoxDecoration(
                // [2차 보정] README 원본은 navy-2(#070D1B) 기준
                // `linear-gradient(180deg, rgba(7,13,27,0),
                // rgba(7,13,27,.94) 30%)`였으나, 위 [MidnightNavTokens.
                // bgBottom] 명도 보정과 동일한 이유로 보정 navy(#162544)
                // 기준으로 맞춘다 — 그라데이션 형태(0%→30%→100%)는 그대로.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00162544), // 0%
                    Color(0xF0162544), // 30%
                    Color(0xF0162544), // 100%까지 동일 톤 유지
                  ],
                  stops: [0, 0.30, 1.0],
                ),
                border: Border(
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
                        showBadge: badgedIndices.contains(i),
                      ),
                    ),
                ],
              ),
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
    this.showBadge = false,
  });

  final MidnightNavTabData data;
  final bool selected;
  final VoidCallback onTap;

  /// [신당(神堂) 통합 — A안 §3.2] 아이콘 오른쪽 위 금색 점(6px) 표시 여부.
  final bool showBadge;

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
                      showBadge: widget.showBadge,
                    ),
                    const SizedBox(height: MidnightNavTokens.tabGap),
                    AnimatedDefaultTextStyle(
                      duration: MidnightNavTokens.colorTransition,
                      curve: MidnightNavTokens.colorCurve,
                      style: TextStyle(
                        // [폰트 중앙화 — 2026-11 마이페이지 B시안] 하단 탭
                        // 라벨도 "메뉴 아이템 이름" 규칙(600~700)을 따르도록
                        // 비선택 상태를 500 -> 600으로 상향.
                        fontFamily: 'Pretendard',
                        fontSize: 11,
                        height: 1,
                        letterSpacing: -0.11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
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
                      margin: EdgeInsets.zero,
                      width: MidnightNavTokens.dotSize,
                      height: MidnightNavTokens.dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? MidnightNavTokens.active
                            : Colors.transparent,
                        // README: "아래 4px 금색 점(glow 0 0 8px #D4AF37)".
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: MidnightNavTokens.glow,
                                  blurRadius: 8,
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
  const _MidnightNavIcon({
    required this.iconKey,
    required this.selected,
    this.showBadge = false,
  });

  final String iconKey;
  final bool selected;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    const size = MidnightNavTokens.iconSize;
    final icon = _buildIcon(size);
    if (!showBadge) return icon;
    // [신당(神堂) 통합 — A안 §3.2 "배지"] 보관 중인 소지부가 있을 때만
    // 아이콘 오른쪽 위에 금색 점(6px)을 겹쳐 그린다.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: MidnightNavTokens.active,
                boxShadow: [
                  BoxShadow(color: MidnightNavTokens.active, blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [Midnight Navy 교체 — README "하단 탭바" 절] 새 핸드오프는 아이콘
  // 자체에 drop-shadow 글로우를 요구하지 않는다(활성 아이콘은 단순
  // 단색 #EBD58E 라인 아이콘). 글로우는 아이콘 아래 4px 점에만 적용되며
  // 그건 `_MidnightNavTabState`의 `AnimatedContainer`가 이미 담당한다 —
  // 그래서 이전의 블러+틴트 2-레이어 스택을 걷어내고 단일 SvgPicture로
  // 단순화했다(시각 결과는 새 스펙과 일치, 렌더 비용도 감소).
  Widget _buildIcon(double size) {
    final asset = _iconAsset(iconKey, active: selected);
    if (!selected) {
      return Opacity(
        opacity: 0.5,
        child: SvgPicture.asset(asset, width: size, height: size),
      );
    }
    return SvgPicture.asset(asset, width: size, height: size);
  }
}
