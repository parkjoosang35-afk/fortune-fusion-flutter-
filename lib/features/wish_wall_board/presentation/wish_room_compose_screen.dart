import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_buttons.dart';
import '../widgets/wish_room_scroll.dart';
import '../widgets/wish_room_seal.dart';
import '../widgets/wish_room_seal_mapping.dart';

/// 소원방(Wish Room) — 03. 소원 작성(Compose) 화면.
///
/// [디자인 핸드오프 — pixel-perfect 재현] `wish-screens.jsx`의
/// `ScreenCompose` 컴포넌트를 발명 없이 그대로 재구현한다: 상단 nav(←/
/// `NEW WISH · N`/✕) → 타이틀("어떤 소원을/봉인하시겠어요?") → 한지
/// 두루마리([WishRoomScroll], 날짜+본문(커서 blink)+글자수/익명뱃지) →
/// 6개 씰 피커(願/合/康/福/緣/財) → CTA("🕯 촛불에 봉인하기").
///
/// [절충 결정 — 데이터 요구사항 vs V2 UX] dev-spec.md의 V2 원본 Compose는
/// 단일 화면(카테고리 선택=씰 선택 1스텝 + 본문 1스텝)이지만, 기존
/// [WishWallProvider.createWish]는 4개 필드(categoryId/glassLevel/text/
/// visibility)를 요구한다. 발명을 최소화하기 위해 다음 매핑을 사용한다:
/// - 씰 선택 → [sealForCategory]의 역매핑([primaryCategoryForSeal])으로
///   categoryId 결정 (기존 5-step의 "Step1 카테고리" 역할을 그대로 대체).
/// - glassLevel(밝기/정성) → V2 디자인에는 별도 슬라이더가 없으므로, 이
///   화면에서는 항상 0.7(기존 5-step의 중간값)로 고정한다. 정성 표현은
///   이미 04 Home의 "촛불 크기"와 05 Detail의 "간절함 게이지"가 서버 응원
///   수(supportCount)로 자동 계산하므로, 작성 시점에 사용자가 직접 밝기를
///   정하지 않아도 이후 화면의 정보 구조가 깨지지 않는다.
/// - 공개범위 → 원본의 "♦ 익명 공개" 뱃지를 탭하면 anonymous ↔ public이
///   토글된다(원본 정적 텍스트를 인터랙티브하게 확장 — 최소 침습).
class WishRoomComposeScreen extends StatefulWidget {
  const WishRoomComposeScreen({super.key});

  @override
  State<WishRoomComposeScreen> createState() => _WishRoomComposeScreenState();
}

class _WishRoomComposeScreenState extends State<WishRoomComposeScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxLen = 140;
  static const List<WishSeal> _seals = [
    WishSeal.wish,
    WishSeal.pass,
    WishSeal.health,
    WishSeal.fortune,
    WishSeal.bond,
    WishSeal.wealth,
  ];

  final _textController = TextEditingController();
  WishSeal _selectedSeal = WishSeal.wish;
  bool _anonymous = true;
  bool _submitting = false;
  late final AnimationController _cursorBlink;

  @override
  void initState() {
    super.initState();
    _cursorBlink = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _cursorBlink.dispose();
    super.dispose();
  }

  String get _dateLabel {
    final now = DateTime.now();
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final w = weekdays[(now.weekday - 1) % 7];
    return '${now.year} · ${now.month.toString().padLeft(2, '0')} · '
        '${now.day.toString().padLeft(2, '0')} · $w';
  }

  bool get _canSubmit =>
      _textController.text.trim().length >= 5 &&
      _textController.text.length <= _maxLen &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final result = await context.read<WishWallProvider>().createWish(
        categoryId: primaryCategoryForSeal(_selectedSeal),
        glassLevel: 0.7,
        text: _textController.text.trim(),
        visibility: _anonymous
            ? WishVisibility.anonymous
            : WishVisibility.public,
      );
      if (!mounted) return;
      // [흐름] 봉인 완료 → 기존 "작성완료" 화면(WishWallSuccessScreen, 별도
      // 트리거·별도 화면임을 문서 §8에서 이미 확인)이 아니라, 이 세션에서
      // 이 화면과 짝을 이루는 확인 스낵바만 띄우고 소원방 홈으로 되돌아간다
      // — 07 Box Opening/08 Celebration은 각각 "개봉"/"성취" 전용 트리거이므로
      // 작성 직후에는 표시하지 않는다(설계 원칙 §7 혼동 방지 그대로 유지).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: WishRoomColors.backgroundMid,
          content: Text(
            result.grantedAmount > 0
                ? '🕯 소원이 봉인되었어요 · 복주머니 +${result.grantedAmount}개'
                : '🕯 소원이 봉인되었어요',
            style: const TextStyle(
              fontSize: 13,
              color: WishRoomColors.textPrimary,
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('소원 봉인에 실패했어요. 다시 시도해 주세요. ($e)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final len = _textController.text.length;
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(
              sigilSize: 280,
              sigilOpacity: 0.18,
              dust: false,
            ),
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
                      const Text(
                        'NEW WISH · 001',
                        style: TextStyle(
                          fontFamily: 'IBMPlexMonoWish',
                          fontSize: 10,
                          letterSpacing: 3.0,
                          color: WishRoomColors.textSecondary,
                        ),
                      ),
                      WishRoomIconButton(
                        icon: '✕',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '어떤 소원을\n봉인하시겠어요?',
                    style: TextStyle(
                      fontFamily: 'NotoSerifKRWish',
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      height: 1.3,
                      color: WishRoomColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WishRoomScroll(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dateLabel,
                                  style: const TextStyle(
                                    fontFamily: 'IBMPlexMonoWish',
                                    fontSize: 9,
                                    letterSpacing: 2.5,
                                    color: Color(0xFF8B5A2B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 130,
                                  ),
                                  child: Stack(
                                    children: [
                                      TextField(
                                        controller: _textController,
                                        maxLines: null,
                                        maxLength: _maxLen,
                                        cursorColor: const Color(0xFF3A2515),
                                        style: const TextStyle(
                                          fontFamily: 'GowunBatangWish',
                                          fontSize: 17,
                                          height: 1.8,
                                          color: Color(0xFF3A2515),
                                        ),
                                        decoration: const InputDecoration(
                                          isCollapsed: true,
                                          border: InputBorder.none,
                                          counterText: '',
                                          hintText:
                                              '엄마 무릎 수술이\n무사히 잘 끝나고\n아프지 않기를',
                                          hintStyle: TextStyle(
                                            fontFamily: 'GowunBatangWish',
                                            fontSize: 17,
                                            height: 1.8,
                                            color: Color(0x663A2515),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.only(top: 10),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Color(0x558B5A2B),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$len / $_maxLen 字',
                                        style: const TextStyle(
                                          fontFamily: 'IBMPlexMonoWish',
                                          fontSize: 9,
                                          letterSpacing: 1.5,
                                          color: Color(0xFF8B5A2B),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _anonymous = !_anonymous,
                                        ),
                                        child: Text(
                                          _anonymous ? '♦ 익명 봉인' : '♦ 이름 공개',
                                          style: const TextStyle(
                                            fontFamily: 'IBMPlexMonoWish',
                                            fontSize: 9,
                                            letterSpacing: 1.5,
                                            color: Color(0xFF8B5A2B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '봉인 인장 선택',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 0.5,
                                color: WishRoomColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 78,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _seals.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final seal = _seals[i];
                                final selected = seal == _selectedSeal;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedSeal = seal),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: selected
                                              ? WishRoomColors.glowShadow
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: selected
                                                ? WishRoomColors.glow
                                                : WishRoomColors
                                                    .surfaceCardBorder,
                                            width: selected ? 2 : 1,
                                          ),
                                        ),
                                        child: WishRoomSeal(
                                          text: seal.glyph,
                                          color: WishRoomColors.accent,
                                          size: 36,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        seal.label,
                                        style: TextStyle(
                                          fontFamily: 'GowunBatangWish',
                                          fontSize: 10,
                                          color: selected
                                              ? WishRoomColors.textPrimary
                                              : WishRoomColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  WishRoomPrimaryButton(
                    label: _submitting ? '봉인하는 중...' : '촛불에 봉인하기',
                    leading: _submitting ? null : '🕯',
                    onPressed: _canSubmit ? _submit : null,
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
