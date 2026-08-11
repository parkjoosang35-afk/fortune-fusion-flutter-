import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wish_item_model.dart';
import '../providers/wish_room_providers.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/category_chip_group.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';
import '../widgets/wish_room_common_buttons.dart';
import '../widgets/wish_room_scroll.dart';
import '../widgets/wish_room_seal.dart';

/// [대형 작업 — 디자인 핸드오프 8개 화면 재구현] "Compose" — 소원 작성 화면.
///
/// `design_handoff/wish-screens.jsx`의 `ScreenCompose` 스펙을 그대로
/// 재구현한다: `BgAtmosphere(sigilSize:280, sigilOpacity:0.18, dust:false)`
/// 위에 상단 아이콘버튼(←/✕) + eyebrow("NEW WISH · 001") → 타이틀
/// "어떤 소원을\n봉인하시겠어요?" → 두루마리(Scroll) 안에 날짜 라벨 +
/// 소원 입력 + 글자수/"♦ 익명 봉인" 풀터 → "봉인 인장 선택" Seal picker
/// (6개, 라벨 포함, 선택 시 테두리+배경 강조) → btnPrimary
/// "🕯 촛불에 봉인하기".
///
/// [카테고리 선택 유지] JSX 스펙에는 없지만, 저장 데이터 모델
/// ([WishItem]/`WishRoomController.addWish`)은 `WishCategory`를 필수로
/// 요구하므로 기존 카테고리 칩 선택 UI(`CategoryChipGroup`)는 스펙 UI 아래에
/// 그대로 유지한다(기존 로직/데이터 모델을 변경하지 않는다는 원칙).
///
/// [Seal은 여전히 순수 시각 프리셋] `_selectedSeal`은 저장 로직(`_save`)에
/// 전달되지 않는다 — [WishItem]에 도장 필드가 없다는 원칙은 이전과 동일하게
/// 유지한다.
class WishWriteScreen extends ConsumerStatefulWidget {
  const WishWriteScreen({super.key});

  @override
  ConsumerState<WishWriteScreen> createState() => _WishWriteScreenState();
}

class _WishWriteScreenState extends ConsumerState<WishWriteScreen> {
  final _controller = TextEditingController();
  WishCategory? _selectedCategory;
  bool _isSaving = false;

  /// [디자인 핸드오프 — Seal picker] README `3. Compose Wish`의 6개 도장
  /// 선택기 순수 시각 상태. 저장 데이터 모델([WishItem])에는 영향을 주지
  /// 않는다(위 클래스 docstring 참고).
  WishSeal _selectedSeal = WishSeal.wish;

  @override
  void initState() {
    super.initState();
    // 두루마리 하단 글자수 카운터를 실시간으로 갱신하기 위해 리스너를 둔다
    // (기존 onChanged: (_) => setState(())도 동일 목적으로 이미 있었으나,
    // 두루마리 재구현으로 별도 텍스트 위젯이 카운트를 그려야 하므로 명시적
    // listener로 통일한다).
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _selectedCategory == null || _isSaving) return;

    setState(() => _isSaving = true);
    await ref
        .read(wishRoomControllerProvider.notifier)
        .addWish(title: title, category: _selectedCategory!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        _controller.text.trim().isNotEmpty && _selectedCategory != null;
    final charCount = _controller.text.characters.length;

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBackground(
              mainSigilSize: 280,
              mainSigilOpacity: 0.18,
              showDust: false,
            ),
          ),
          SafeArea(
            child: DramaticEntrance(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  WishRoomSpacing.md,
                  WishRoomSpacing.sm,
                  WishRoomSpacing.md,
                  WishRoomSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Row(
                      children: [
                        WishRoomIconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 18,
                            color: WishRoomColors.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Text('NEW WISH · 001', style: WishRoomTextStyles.eyebrow),
                        const Spacer(),
                        WishRoomIconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: WishRoomColors.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: WishRoomSpacing.md),
                    Text(
                      '어떤 소원을\n봉인하시겠어요?',
                      style: WishRoomTextStyles.titleXl,
                    ),
                    const SizedBox(height: WishRoomSpacing.md),
                    // ── Scroll paper ──
                    WishRoomScroll(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _paperDateLabel(),
                            style: const TextStyle(
                              fontFamily: 'IBMPlexMonoWish',
                              fontSize: 9,
                              letterSpacing: 2.7,
                              color: Color(0xFF8B5A2B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 130),
                            child: TextField(
                              controller: _controller,
                              maxLines: null,
                              minLines: 4,
                              maxLength: 60,
                              cursorColor: const Color(0xFF3A2515),
                              style: WishRoomTextStyles.wishBodyPaper,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                counterText: '',
                                hintText: '이루고 싶은 소원을 적어보세요',
                                hintStyle: WishRoomTextStyles.wishBodyPaper
                                    .copyWith(
                                      color: const Color(0x663A2515),
                                    ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0x558B5A2B),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$charCount / 60 字',
                                      style: const TextStyle(
                                        fontFamily: 'IBMPlexMonoWish',
                                        fontSize: 9,
                                        letterSpacing: 1.35,
                                        color: Color(0xFF8B5A2B),
                                      ),
                                    ),
                                    const Text(
                                      '♦ 익명 봉인',
                                      style: TextStyle(
                                        fontFamily: 'IBMPlexMonoWish',
                                        fontSize: 9,
                                        letterSpacing: 1.35,
                                        color: Color(0xFF8B5A2B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: WishRoomSpacing.lg),
                    // ── Seal picker ──
                    Text(
                      '봉인 인장 선택',
                      style: WishRoomTextStyles.bodySm.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: WishSeal.values.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: WishRoomSpacing.sm),
                        itemBuilder: (context, index) {
                          final seal = WishSeal.values[index];
                          final isSelected = seal == _selectedSeal;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedSeal = seal),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: isSelected
                                        ? WishRoomColors.glowShadow
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? WishRoomColors.glow
                                          : WishRoomColors.surfaceCardBorder,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: AnimatedScale(
                                    scale: isSelected ? 1.08 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: WishRoomSeal(
                                      text: seal.glyph,
                                      size: 36,
                                      selected: isSelected,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  seal.label,
                                  style: TextStyle(
                                    fontFamily: 'GowunBatangWish',
                                    fontSize: 10,
                                    color: isSelected
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
                    const SizedBox(height: WishRoomSpacing.lg),
                    // ── 카테고리 선택(데이터 모델 필수값, 스펙 외 추가 UI) ──
                    Text(
                      '어떤 마음에 정성을 담고 싶으신가요?',
                      style: WishRoomTextStyles.bodySm,
                    ),
                    const SizedBox(height: WishRoomSpacing.sm),
                    CategoryChipGroup(
                      selected: _selectedCategory,
                      onSelected: (category) =>
                          setState(() => _selectedCategory = category),
                    ),
                    const SizedBox(height: WishRoomSpacing.xl),
                    // ── CTA ──
                    WishRoomPrimaryButton(
                      label: _isSaving ? '봉인하는 중...' : '🕯 촛불에 봉인하기',
                      onPressed: canSave && !_isSaving ? _save : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// README Compose 스펙의 두루마리 상단 날짜 라벨("2026 · 08 · 11 · 火"
  /// 형식)을 오늘 날짜로 생성한다. 요일 한자는 월화수목금토일 순서.
  String _paperDateLabel() {
    const weekdayHanja = ['月', '火', '水', '木', '金', '土', '日'];
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final weekday = weekdayHanja[now.weekday - 1];
    return '${now.year} · $month · $day · $weekday';
  }
}
