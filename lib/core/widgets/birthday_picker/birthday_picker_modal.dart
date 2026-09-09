/// [BirthdayPickerModal 포팅 — 4/4: 메인 위젯]
///
/// 원본: `handoff-extract/BirthdayPickerModal.jsx`(835줄) — 신통방통
/// 소원방 디자인 핸드오프 패키지의 생년월일+태어난시간 입력 모달을
/// Flutter Dart 위젯으로 재구현한다. 정통사주69/AI사주/궁합 등 앱 전역의
/// 기존 OS 기본 캘린더(`showDatePicker`/`showTimePicker`) 입력 화면을
/// 이 위젯 하나로 통일하기 위한 공용 컴포넌트다.
///
/// [흐름] STEP1(생년월일 8자리 숫자 키패드) → STEP2(12지신 시간대 3×4
/// 그리드, `requireTime=false`면 "시간 모름" 옵션 노출) → 1.5초 저장
/// 애니메이션(SavedToast) → onConfirm 콜백.
///
/// [사용법] 직접 위젯을 쓰지 않고 [showBirthdayPicker] 헬퍼 함수로 전체
/// 화면 라우트를 push해 결과를 Future로 받는 것을 권장한다(Flutter 관용
/// 패턴). 팔레트 매핑은 dev-spec.md 기준:
///   - 정통사주69/토정비결 → hanji + requireTime=true
///   - AI운세/오늘의흐름   → midnight + requireTime=false
///   - AI사주(신형)        → midnight + requireTime=true
///   - 궁합                → midnight + requireTime=false (2회 호출)
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'birthday_picker_palette.dart';
import 'birthday_picker_sigil.dart';
import 'birthday_picker_types.dart';

export 'birthday_picker_palette.dart';
export 'birthday_picker_types.dart';

/// 전체 화면 라우트로 BirthdayPickerModal을 열고 결과를 기다린다.
/// 사용자가 뒤로가기/백드롭으로 닫으면 null을 반환한다.
Future<BirthdayPickerValue?> showBirthdayPicker(
  BuildContext context, {
  BirthdayPickerPalette palette = BirthdayPickerPalette.midnight,
  bool requireTime = true,
  BirthdayPickerValue? initialValue,
  String? title,
  String? ctaLabel,
  String? sourceLabel,
}) {
  return Navigator.of(context).push<BirthdayPickerValue>(
    PageRouteBuilder<BirthdayPickerValue>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return BirthdayPickerModal(
          palette: palette,
          requireTime: requireTime,
          initialValue: initialValue,
          title: title,
          ctaLabel: ctaLabel,
          sourceLabel: sourceLabel,
          onClose: () => Navigator.of(ctx).pop(),
          onConfirm: (v) => Navigator.of(ctx).pop(v),
        );
      },
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.34, 1.2, 0.64, 1),
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    ),
  );
}

class BirthdayPickerModal extends StatefulWidget {
  const BirthdayPickerModal({
    super.key,
    this.palette = BirthdayPickerPalette.midnight,
    this.requireTime = true,
    this.initialValue,
    this.title,
    this.ctaLabel,
    this.sourceLabel,
    required this.onClose,
    required this.onConfirm,
  });

  final BirthdayPickerPalette palette;
  final bool requireTime;
  final BirthdayPickerValue? initialValue;
  final String? title;
  final String? ctaLabel;
  final String? sourceLabel;
  final VoidCallback onClose;
  final ValueChanged<BirthdayPickerValue> onConfirm;

  @override
  State<BirthdayPickerModal> createState() => _BirthdayPickerModalState();
}

class _SavedState {
  const _SavedState({required this.y, required this.m, required this.d, this.timeLabel});
  final int y;
  final int m;
  final int d;
  final String? timeLabel;
}

class _BirthdayPickerModalState extends State<BirthdayPickerModal>
    with TickerProviderStateMixin {
  late BirthdayPickerColors _p;

  int _step = 1; // 1 = date, 2 = time
  late List<String> _digits;
  BirthdayZhiTime? _selectedZhi;
  bool _unknownSelected = false;
  _SavedState? _saved;

  late AnimationController _shakeCtrl;
  late AnimationController _sigilCtrl;
  late AnimationController _caretCtrl;

  @override
  void initState() {
    super.initState();
    _p = kBirthdayPalettes[widget.palette]!;
    _digits = _initialDigits();
    final t = widget.initialValue?.time;
    _selectedZhi = t == null
        ? null
        : kBirthdayZhiTimes.where((z) => z.zhi == t.zhi).cast<BirthdayZhiTime?>().firstOrNull;
    _unknownSelected = widget.initialValue != null && widget.initialValue!.time == null;

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _sigilCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _caretCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _sigilCtrl.dispose();
    _caretCtrl.dispose();
    super.dispose();
  }

  List<String> _initialDigits() {
    final v = widget.initialValue;
    if (v == null) return List.filled(8, '');
    final y = v.year.toString().padLeft(4, '0');
    final m = v.month.toString().padLeft(2, '0');
    final d = v.day.toString().padLeft(2, '0');
    return '$y$m$d'.split('');
  }

  // ── derived date state ──
  // [버그 수정] `String.contains('')`는 모든 문자열에서 항상 true를
  // 반환하므로(빈 부분 문자열은 어디에나 "포함"됨) `!s.contains('')`는
  // 늘 false가 되어 버렸다 — 즉 8자리를 다 채워도 _y/_m/_d가 항상 null을
  // 반환해 STEP2 전환 시 `_y!`/`_m!`/`_d!`에서 널 체크 예외가 터지고
  // 화면이 통째로 비어버리는 원인이었다. 배열 원소 자체가 비었는지
  // (join 이전에) 확인하도록 수정한다.
  int? get _y {
    final slice = _digits.sublist(0, 4);
    if (slice.any((x) => x.isEmpty)) return null;
    return int.tryParse(slice.join());
  }

  int? get _m {
    final slice = _digits.sublist(4, 6);
    if (slice.any((x) => x.isEmpty)) return null;
    return int.tryParse(slice.join());
  }

  int? get _d {
    final slice = _digits.sublist(6, 8);
    if (slice.any((x) => x.isEmpty)) return null;
    return int.tryParse(slice.join());
  }

  bool get _dateComplete => _digits.every((x) => x.isNotEmpty);

  BirthdayDateValidation get _validation => validateBirthdayDate(_y, _m, _d);

  bool get _canGoStep2 => _dateComplete && _validation.ok;

  bool get _timeChosen => _selectedZhi != null || _unknownSelected;

  bool get _canSubmitFinal =>
      _canGoStep2 && (_timeChosen || !widget.requireTime);

  void _pushDigit(String ch) {
    final idx = _digits.indexOf('');
    if (idx == -1) return;
    setState(() => _digits[idx] = ch);
    _maybeShake();
  }

  void _popDigit() {
    var idx = -1;
    for (var i = _digits.length - 1; i >= 0; i--) {
      if (_digits[i].isNotEmpty) {
        idx = i;
        break;
      }
    }
    if (idx == -1) return;
    setState(() => _digits[idx] = '');
  }

  void _clearAll() => setState(() => _digits = List.filled(8, ''));

  void _maybeShake() {
    if (!_validation.ok) {
      _shakeCtrl.forward(from: 0);
    }
  }

  void _handleStep1Next() {
    if (!_canGoStep2) return;
    HapticFeedback.selectionClick();
    setState(() => _step = 2);
  }

  void _handleZhiSelect(BirthdayZhiTime z) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedZhi = z;
      _unknownSelected = false;
    });
  }

  void _handleUnknown() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedZhi = null;
      _unknownSelected = true;
    });
  }

  void _handleBack() {
    if (_step == 2) {
      setState(() => _step = 1);
    } else {
      widget.onClose();
    }
  }

  Future<void> _handleFinalSubmit() async {
    if (!_canSubmitFinal) return;
    final y = _y!, m = _m!, d = _d!;
    BirthdayPickerTimeValue? time;
    String? timeLabel;
    if (_unknownSelected) {
      timeLabel = '시간 모름';
    } else if (_selectedZhi != null) {
      final z = _selectedZhi!;
      time = BirthdayPickerTimeValue(
        zhi: z.zhi,
        hanja: z.hanja,
        rangeStart: z.rangeStart,
        rangeEnd: z.rangeEnd,
        label: '${z.label} (${z.hint})',
      );
      timeLabel = '${z.label} · ${z.hanja}';
    }

    setState(() => _saved = _SavedState(y: y, m: m, d: d, timeLabel: timeLabel));
    HapticFeedback.lightImpact();

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final date = DateTime(y, m, d);
    // JS Date.getDay(): 0=일..6=토. Dart DateTime.weekday: 1=월..7=일.
    final weekday = date.weekday == 7 ? 0 : date.weekday;
    widget.onConfirm(
      BirthdayPickerValue(year: y, month: m, day: d, weekday: weekday, time: time),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final stepTitle = _step == 1
        ? ('태어난 날을', widget.title ?? '알려주세요', '숫자를 순서대로 눌러주세요')
        : ('태어난 시간은', '언제였을까요', '12지신 중 해당하는 시간을 골라주세요');

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // backdrop tap-to-close
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: p.backdrop),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.bg1, p.bg2, p.tail],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // background radial washes (decorative, simplified)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BgWashPainter(colors: p.bgWashes),
                    ),
                  ),
                  // rotating sigil
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _sigilCtrl,
                        builder: (context, child) {
                          return Opacity(
                            opacity: widget.palette == BirthdayPickerPalette.hanji
                                ? 0.2
                                : 0.28,
                            child: Transform.rotate(
                              angle: _sigilCtrl.value * 2 * math.pi,
                              child: BirthdaySigil(
                                size: 420,
                                color: p.sigilColor,
                                opacity: p.sigilOpacity,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (p.hanjiGrain)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.35,
                          child: CustomPaint(painter: _HanjiGrainPainter()),
                        ),
                      ),
                    ),
                  if (p.stars) Positioned.fill(child: _StarField(count: 70)),

                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                      child: Column(
                        children: [
                          _Header(
                            p: p,
                            step: _step,
                            sourceLabel: widget.sourceLabel,
                            stepTitle: stepTitle,
                            onBack: _handleBack,
                          ),
                          Expanded(
                            child: _step == 1
                                ? _Step1(
                                    p: p,
                                    digits: _digits,
                                    validation: _validation,
                                    dateComplete: _dateComplete,
                                    y: _y,
                                    m: _m,
                                    d: _d,
                                    shakeCtrl: _shakeCtrl,
                                    caretCtrl: _caretCtrl,
                                    canGoStep2: _canGoStep2,
                                    ctaLabel: '다음 · 시간 입력',
                                    onDigit: _pushDigit,
                                    onBackspaceOne: _popDigit,
                                    onBackspaceClear: _clearAll,
                                    onSubmit: _handleStep1Next,
                                  )
                                : _Step2(
                                    p: p,
                                    y: _y!,
                                    m: _m!,
                                    d: _d!,
                                    requireTime: widget.requireTime,
                                    selected: _selectedZhi,
                                    unknownSelected: _unknownSelected,
                                    canSubmit: _canSubmitFinal,
                                    ctaLabel: widget.ctaLabel ?? '저장하기',
                                    onSelect: _handleZhiSelect,
                                    onUnknown: _handleUnknown,
                                    onEditDate: () => setState(() => _step = 1),
                                    onSubmit: _handleFinalSubmit,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_saved != null)
                    _SavedToast(
                      p: p,
                      y: _saved!.y,
                      m: _saved!.m,
                      d: _saved!.d,
                      timeLabel: _saved!.timeLabel,
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

// ============================================================
// Header + Step indicator
// ============================================================
class _Header extends StatelessWidget {
  const _Header({
    required this.p,
    required this.step,
    required this.sourceLabel,
    required this.stepTitle,
    required this.onBack,
  });

  final BirthdayPickerColors p;
  final int step;
  final String? sourceLabel;
  final (String, String, String) stepTitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CircleBackButton(p: p, onTap: onBack),
            Expanded(
              child: Column(
                children: [
                  Text(
                    sourceLabel ?? 'SAJU · 정보 입력',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 10,
                      letterSpacing: 3.5,
                      color: p.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'STEP $step · ${step == 1 ? '생년월일' : '태어난 시간'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 11,
                      letterSpacing: 2,
                      color: p.fg,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 36),
          ],
        ),
        const SizedBox(height: 10),
        _StepIndicator(step: step, totalSteps: 2, p: p),
        const SizedBox(height: 18),
        Text(
          stepTitle.$1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Noto Serif KR',
            fontWeight: FontWeight.w900,
            fontSize: 26,
            height: 1.25,
            letterSpacing: -0.4,
            color: p.fg,
          ),
        ),
        Text(
          stepTitle.$2,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Noto Serif KR',
            fontWeight: FontWeight.w900,
            fontSize: 26,
            height: 1.25,
            letterSpacing: -0.4,
            color: p.glow,
            shadows: [Shadow(color: p.glowShadow, blurRadius: 30)],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stepTitle.$3,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Gowun Batang',
            fontSize: 13,
            color: p.muted,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.p, required this.onTap});
  final BirthdayPickerColors p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: p.card,
          shape: BoxShape.circle,
          border: Border.all(color: p.line),
        ),
        child: Icon(Icons.chevron_left, color: p.fg, size: 20),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.totalSteps, required this.p});
  final int step;
  final int totalSteps;
  final BirthdayPickerColors p;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final active = i + 1 == step;
        final done = i + 1 < step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: (done || active) ? p.glow : p.line,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [BoxShadow(color: p.glowShadow, blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

// ============================================================
// STEP 1: Date entry
// ============================================================
class _Step1 extends StatelessWidget {
  const _Step1({
    required this.p,
    required this.digits,
    required this.validation,
    required this.dateComplete,
    required this.y,
    required this.m,
    required this.d,
    required this.shakeCtrl,
    required this.caretCtrl,
    required this.canGoStep2,
    required this.ctaLabel,
    required this.onDigit,
    required this.onBackspaceOne,
    required this.onBackspaceClear,
    required this.onSubmit,
  });

  final BirthdayPickerColors p;
  final List<String> digits;
  final BirthdayDateValidation validation;
  final bool dateComplete;
  final int? y;
  final int? m;
  final int? d;
  final AnimationController shakeCtrl;
  final AnimationController caretCtrl;
  final bool canGoStep2;
  final String ctaLabel;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspaceOne;
  final VoidCallback onBackspaceClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: shakeCtrl,
          builder: (context, child) {
            final t = shakeCtrl.value;
            final dx = math.sin(t * math.pi * 6) * (1 - t) * 8;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _DateDisplay(digits: digits, p: p, caretCtrl: caretCtrl),
        ),
        const SizedBox(height: 12),
        _ResultBanner(
          complete: dateComplete && validation.ok,
          y: y,
          m: m,
          d: d,
          error: !validation.ok ? validation.msg : null,
          p: p,
        ),
        const Spacer(),
        _Keypad(
          canSubmit: canGoStep2,
          ctaLabel: ctaLabel,
          p: p,
          onDigit: onDigit,
          onBackspaceOne: onBackspaceOne,
          onBackspaceClear: onBackspaceClear,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _DateDisplay extends StatelessWidget {
  const _DateDisplay({required this.digits, required this.p, required this.caretCtrl});
  final List<String> digits;
  final BirthdayPickerColors p;
  final AnimationController caretCtrl;

  @override
  Widget build(BuildContext context) {
    final firstEmpty = digits.indexOf('');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _slot(0, true, firstEmpty),
        _slot(1, true, firstEmpty),
        _slot(2, true, firstEmpty),
        _slot(3, true, firstEmpty),
        _sep('年'),
        _slot(4, false, firstEmpty),
        _slot(5, false, firstEmpty),
        _sep('月'),
        _slot(6, false, firstEmpty),
        _slot(7, false, firstEmpty),
        _sep('日'),
      ],
    );
  }

  Widget _sep(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 14,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 10,
            letterSpacing: 2,
            color: p.slotHint,
          ),
        ),
      ),
    );
  }

  Widget _slot(int idx, bool big, int firstEmpty) {
    final ch = digits[idx];
    final filled = ch.isNotEmpty;
    final isCaret = !filled && idx == firstEmpty;
    return SizedBox(
      width: big ? 34 : 30,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (filled)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Text(
                ch,
                style: TextStyle(
                  fontFamily: 'Noto Serif KR',
                  fontWeight: FontWeight.bold,
                  fontSize: big ? 36 : 34,
                  letterSpacing: -0.5,
                  color: p.fg,
                  shadows: [Shadow(color: p.glowShadow, blurRadius: 20)],
                ),
              ),
            )
          else
            Text(
              '0',
              style: TextStyle(
                fontFamily: 'Noto Serif KR',
                fontWeight: FontWeight.bold,
                fontSize: big ? 36 : 34,
                color: p.slotEmpty.withValues(alpha: (p.slotEmpty.a) * 0.55),
              ),
            ),
          if (isCaret)
            Positioned(
              bottom: 8,
              child: AnimatedBuilder(
                animation: caretCtrl,
                builder: (context, _) {
                  final visible = caretCtrl.value < 0.5;
                  return Opacity(
                    opacity: visible ? 1 : 0,
                    child: Container(
                      width: big ? 22 : 20,
                      height: 2,
                      decoration: BoxDecoration(
                        color: p.glow,
                        boxShadow: [BoxShadow(color: p.glow, blurRadius: 8)],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (filled)
            Positioned(
              bottom: 6,
              child: Container(
                width: big ? 22 : 20,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      p.glow.withValues(alpha: 0),
                      p.glow.withValues(alpha: 0.65),
                      p.glow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.complete,
    required this.y,
    required this.m,
    required this.d,
    required this.error,
    required this.p,
  });

  final bool complete;
  final int? y;
  final int? m;
  final int? d;
  final String? error;
  final BirthdayPickerColors p;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Text(
        error!,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Gowun Batang', fontSize: 13, color: p.errorColor),
      );
    }
    if (!complete || y == null || m == null || d == null) {
      return Text(
        'YEAR · MONTH · DAY',
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: 10,
          letterSpacing: 3,
          color: p.slotHint,
        ),
      );
    }
    final date = DateTime(y!, m!, d!);
    final wIdx = date.weekday == 7 ? 0 : date.weekday;
    final age = DateTime.now().year - y!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${kBirthdayDayKoKr[wIdx]}요일',
                style: TextStyle(fontFamily: 'Gowun Batang', fontSize: 14, color: p.fg.withValues(alpha: 0.9)),
              ),
              TextSpan(
                text: '  ${kBirthdayDayHanjaKr[wIdx]}',
                style: TextStyle(fontFamily: 'Noto Serif KR', fontWeight: FontWeight.w900, color: p.glow),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 4, height: 4, decoration: BoxDecoration(color: p.slotHint, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Text(
          '$age세',
          style: TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 11, letterSpacing: 2, color: p.muted),
        ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.canSubmit,
    required this.ctaLabel,
    required this.p,
    required this.onDigit,
    required this.onBackspaceOne,
    required this.onBackspaceClear,
    required this.onSubmit,
  });

  final bool canSubmit;
  final String ctaLabel;
  final BirthdayPickerColors p;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspaceOne;
  final VoidCallback onBackspaceClear;
  final VoidCallback onSubmit;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['clear', '0', 'back'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _key(k),
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: canSubmit ? onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? p.glow : p.card,
              foregroundColor: canSubmit ? p.ctaText : p.slotHint,
              disabledBackgroundColor: p.card,
              disabledForegroundColor: p.slotHint,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              ctaLabel,
              style: const TextStyle(fontFamily: 'Gowun Batang', fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _key(String k) {
    if (k == 'clear') {
      return SizedBox(
        height: 60,
        child: TextButton(
          onPressed: onBackspaceClear,
          style: TextButton.styleFrom(foregroundColor: p.muted),
          child: const Text('전체지우기', style: TextStyle(fontFamily: 'Pretendard', fontSize: 13)),
        ),
      );
    }
    if (k == 'back') {
      return SizedBox(
        height: 60,
        child: IconButton(
          onPressed: onBackspaceOne,
          icon: Icon(Icons.backspace_outlined, color: p.fg, size: 22),
        ),
      );
    }
    return SizedBox(
      height: 60,
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onDigit(k),
          highlightColor: p.cardHover,
          splashColor: p.cardHover,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.line),
            ),
            alignment: Alignment.center,
            child: Text(
              k,
              style: TextStyle(
                fontFamily: 'Noto Serif KR',
                fontSize: 26,
                color: p.fg,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STEP 2: Time entry
// ============================================================
class _Step2 extends StatelessWidget {
  const _Step2({
    required this.p,
    required this.y,
    required this.m,
    required this.d,
    required this.requireTime,
    required this.selected,
    required this.unknownSelected,
    required this.canSubmit,
    required this.ctaLabel,
    required this.onSelect,
    required this.onUnknown,
    required this.onEditDate,
    required this.onSubmit,
  });

  final BirthdayPickerColors p;
  final int y;
  final int m;
  final int d;
  final bool requireTime;
  final BirthdayZhiTime? selected;
  final bool unknownSelected;
  final bool canSubmit;
  final String ctaLabel;
  final ValueChanged<BirthdayZhiTime> onSelect;
  final VoidCallback onUnknown;
  final VoidCallback onEditDate;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // saved date summary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.card,
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택하신 날짜',
                      style: TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 9, letterSpacing: 2, color: p.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$y년 $m월 $d일',
                      style: TextStyle(fontFamily: 'Gowun Batang', fontSize: 15, fontWeight: FontWeight.bold, color: p.fg),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onEditDate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.muted,
                  side: BorderSide(color: p.line),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: const Text('수정', style: TextStyle(fontFamily: 'Pretendard', fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _ZhiTimeGrid(
            selected: selected,
            onSelect: onSelect,
            unknownSelected: unknownSelected,
            onUnknown: onUnknown,
            p: p,
            requireTime: requireTime,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: canSubmit ? () => onSubmit() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? p.glow : p.card,
              foregroundColor: canSubmit ? p.ctaText : p.slotHint,
              disabledBackgroundColor: p.card,
              disabledForegroundColor: p.slotHint,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              ctaLabel,
              style: const TextStyle(fontFamily: 'Gowun Batang', fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZhiTimeGrid extends StatelessWidget {
  const _ZhiTimeGrid({
    required this.selected,
    required this.onSelect,
    required this.unknownSelected,
    required this.onUnknown,
    required this.p,
    required this.requireTime,
  });

  final BirthdayZhiTime? selected;
  final ValueChanged<BirthdayZhiTime> onSelect;
  final bool unknownSelected;
  final VoidCallback onUnknown;
  final BirthdayPickerColors p;
  final bool requireTime;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: [
              for (final z in kBirthdayZhiTimes)
                _ZhiCell(
                  z: z,
                  active: !unknownSelected && selected?.zhi == z.zhi,
                  p: p,
                  onTap: () => onSelect(z),
                ),
            ],
          ),
          if (!requireTime) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onUnknown,
                style: OutlinedButton.styleFrom(
                  backgroundColor: unknownSelected ? p.cardHover : Colors.transparent,
                  foregroundColor: unknownSelected ? p.glow : p.muted,
                  side: BorderSide(
                    color: unknownSelected ? p.chipBorder : p.line,
                    style: BorderStyle.solid,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('◈ ', style: TextStyle(fontSize: 11)),
                    Text(
                      '태어난 시간을 잘 모르겠어요',
                      style: TextStyle(fontFamily: 'Gowun Batang', fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZhiCell extends StatelessWidget {
  const _ZhiCell({required this.z, required this.active, required this.p, required this.onTap});
  final BirthdayZhiTime z;
  final bool active;
  final BirthdayPickerColors p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? p.glow : p.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? p.glow : p.line),
            boxShadow: active ? [BoxShadow(color: p.glowShadow, blurRadius: 16)] : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    z.hanja,
                    style: TextStyle(
                      fontFamily: 'Noto Serif KR',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: active ? p.ctaText : p.fg,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    z.label,
                    style: TextStyle(
                      fontFamily: 'Gowun Batang',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: active ? p.ctaText : p.fg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                z.hint,
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 9,
                  letterSpacing: 1,
                  color: (active ? p.ctaText : p.muted).withValues(
                    alpha: active ? 0.75 : 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Saved toast overlay
// ============================================================
class _SavedToast extends StatefulWidget {
  const _SavedToast({required this.p, required this.y, required this.m, required this.d, this.timeLabel});
  final BirthdayPickerColors p;
  final int y;
  final int m;
  final int d;
  final String? timeLabel;

  @override
  State<_SavedToast> createState() => _SavedToastState();
}

class _SavedToastState extends State<_SavedToast> with TickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  late AnimationController _sealCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
    _sealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..forward();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _sealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
        child: BackdropDecoratedBox(
          overlay: p.overlay,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _rotateCtrl,
                      builder: (context, _) => Opacity(
                        opacity: 0.55,
                        child: Transform.rotate(
                          angle: _rotateCtrl.value * 2 * math.pi,
                          child: BirthdaySigil(size: 260, color: p.sigilColor, opacity: 0.7),
                        ),
                      ),
                    ),
                    ScaleTransition(
                      scale: CurvedAnimation(parent: _sealCtrl, curve: Curves.elasticOut),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: p.glow,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: p.glowShadow, blurRadius: 40)],
                        ),
                        child: Icon(Icons.check, color: p.checkGlyph, size: 30),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'SAVED',
                  style: TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 10, letterSpacing: 4, color: p.glow),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.y}년 ${widget.m}월 ${widget.d}일',
                  style: TextStyle(fontFamily: 'Noto Serif KR', fontWeight: FontWeight.w900, fontSize: 22, color: p.fg),
                ),
                if (widget.timeLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.timeLabel!,
                    style: TextStyle(fontFamily: 'Gowun Batang', fontSize: 14, color: p.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BackdropDecoratedBox extends StatelessWidget {
  const BackdropDecoratedBox({super.key, required this.overlay, required this.child});
  final Color overlay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: overlay,
      child: child,
    );
  }
}

// ============================================================
// Star field background (midnight palette only)
// ============================================================
class _StarField extends StatelessWidget {
  const _StarField({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _StarFieldPainter(count: count)),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({required this.count});
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < count; i++) {
      final left = ((i * 137.5 + 13) % 100) / 100 * size.width;
      final top = ((i * 89.3 + 7) % 100) / 100 * size.height;
      final s = 1 + (i % 3) * 0.5;
      final op = 0.2 + ((i % 5) / 5) * 0.6;
      final paint = Paint()..color = Colors.white.withValues(alpha: op);
      canvas.drawCircle(Offset(left, top), s, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => false;
}

// ============================================================
// Background radial washes (simplified decorative gradient)
// ============================================================
class _BgWashPainter extends CustomPainter {
  _BgWashPainter({required this.colors});
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final spots = [
      Offset(size.width * 0.2, size.height * -0.05),
      Offset(size.width * 0.9, size.height * 0.2),
      Offset(size.width * 0.5, size.height * 1.1),
    ];
    for (var i = 0; i < colors.length && i < spots.length; i++) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [colors[i], colors[i].withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: spots[i], radius: size.width * 0.9));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BgWashPainter oldDelegate) => false;
}

// ============================================================
// Hanji grain texture (hanji palette only, simplified)
// ============================================================
class _HanjiGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const gap = 3.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HanjiGrainPainter oldDelegate) => false;
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
