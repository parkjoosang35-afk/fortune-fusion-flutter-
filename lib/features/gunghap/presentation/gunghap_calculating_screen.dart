// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_calculating_screen.dart
// [궁합지도 핸드오프 v4] `00_DEV_MAPPING.md` §5 S15 "분석 로딩"
// (구조표 13, line 456-461) + S42 "로딩·뒤로가기 확인"(line 462-464)
// 공용 연출 화면 — S12(직접 입력)/S14(게스트 웹 입력) 제출 직후,
// 실제 서버 응답을 기다리는 동안 노출된다.
//
// [설계] 이 화면은 그 자체로 네트워크 요청을 수행하지 않는다 — 호출부
// (S12/S14)가 이미 시작한 `Future<Map<String, dynamic>?>`(joinAnonymous
// 또는 createDirect)를 [future] 파라미터로 전달받아 `await`하고, 완료되면
// [onResult] 콜백으로 결과(성공 Map 또는 실패 null)를 돌려준다. 호출부가
// 기존 성공/실패 처리·네비게이션 로직을 그대로 재사용할 수 있도록, 이
// 화면 자신은 Navigator.push만 담당하고 결과 처리는 전혀 하지 않는다
// ("로직 유지 + 화면만 신설" 원칙 — S12/S14의 기존 `joinAnonymous`/
// `createDirect` 호출 로직은 전혀 변경하지 않는다).
//
// [문구 전환] 명세 3단계 문구를 타이머로 순환 노출한다(0~1.4s / 1.4~2.9s
// / 2.9~4.3s). 실제 서버 응답이 이보다 먼저 도착해도 최소 표시 시간
// (`_kMinDisplay` 2.0s)을 채울 때까지 결과 화면 전환을 지연해 로딩이
// 너무 짧게 깜빡이는 것을 방지한다(명세: "실제 서버 응답 기준으로
// 전환(타이머는 최소 표시 시간)").
//
// [S42 뒤로가기 확인] 로딩 중 뒤로가기(Android 백버튼/AppBar ←)를 누르면
// 바로 pop하지 않고 "분석을 멈출까요" 확인 시트를 띄운다 — 시트에서
// "멈추고 돌아가기"를 선택하면 실제로 이전 화면으로 돌아간다(서버 요청
// 자체를 취소할 수는 없지만, 이 화면만 벗어나고 결과는 버린다). "계속
// 기다리기"를 선택하면 진행을 유지한다.
// ═══════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';

const _kMinDisplay = Duration(milliseconds: 4300);

const _kSteps = [
  '두 사람의 사주를 분석하고 있습니다',
  '서로의 성향을 연결하고 있습니다',
  '선택한 궁합 분야를 해석하고 있습니다',
];

class GunghapCalculatingScreen extends StatefulWidget {
  const GunghapCalculatingScreen({
    super.key,
    required this.future,
    required this.onResult,
    this.aName,
    this.bName = '나',
  });

  /// 호출부(S12/S14)가 이미 시작한 제출 요청. 이 화면은 결과를
  /// 해석하지 않고 그대로 [onResult]에 전달하기만 한다.
  final Future<Map<String, dynamic>?> future;

  /// 최소 표시 시간([_kMinDisplay])을 채운 뒤 호출된다 — 호출부가 이
  /// 콜백 안에서 성공/실패에 따라 결과 화면으로 `pushReplacement`하거나
  /// 오류를 처리한다(이 화면 자신은 pop하지 않는다 — 호출부가
  /// pushReplacement로 이 화면을 대체한다).
  final void Function(Map<String, dynamic>? result) onResult;

  /// StarMap 좌측 별 라벨(초대자 이름 등). 우측은 기본 "나".
  final String? aName;
  final String bName;

  @override
  State<GunghapCalculatingScreen> createState() =>
      _GunghapCalculatingScreenState();
}

class _GunghapCalculatingScreenState extends State<GunghapCalculatingScreen> {
  int _step = 0;
  Timer? _stepTimer;
  bool _delivered = false;

  @override
  void initState() {
    super.initState();
    // [문구 순환] 0~1.4s=STEP1, 1.4~2.9s=STEP2, 2.9~4.3s=STEP3.
    _stepTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _step = 1);
      _stepTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _step = 2);
      });
    });
    _run();
  }

  Future<void> _run() async {
    final started = DateTime.now();
    final result = await widget.future;
    final elapsed = DateTime.now().difference(started);
    final remain = _kMinDisplay - elapsed;
    if (remain > Duration.zero) {
      await Future.delayed(remain);
    }
    if (!mounted || _delivered) return;
    _delivered = true;
    widget.onResult(result);
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<bool> _confirmStop() async {
    final stop = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: GHColors.scrim,
      builder: (_) => const _StopConfirmSheet(),
    );
    return stop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return GHScreen(
      appBar: GHAppBar(title: '궁합 분석 중', onBack: () async {
        if (await _confirmStop() && context.mounted) {
          Navigator.of(context).maybePop();
        }
      }),
      onWillPop: _confirmStop,
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          children: [
            SizedBox(
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const _PulseRing(),
                  StarMap(aName: widget.aName ?? '초대자', bName: widget.bName, big: true),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _ProgressDots(),
            const SizedBox(height: 20),
            Text(
              'READING · 0${_step + 1} / 03',
              style: GHText.mono(color: GHColors.gold),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Text(
                _kSteps[_step],
                key: ValueKey(_step),
                textAlign: TextAlign.center,
                style: GHText.ui(size: 17, weight: FontWeight.w700, color: GHColors.fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 중앙 StarMap 뒤에 깔리는 펄스 원(150px, 명세 「펄스 원 150」).
class _PulseRing extends StatefulWidget {
  const _PulseRing();
  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: GHMotion.pulse,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final t = _c.value;
      final scale = 0.85 + t * 0.3;
      final opacity = (1 - t).clamp(0.0, 1.0) * 0.35;
      return Transform.scale(
        scale: scale,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GHColors.gold.withValues(alpha: opacity), width: 1.4),
          ),
        ),
      );
    },
  );
}

/// 진행 점 3개(명세 「진행 점 3(현재 22폭)」) — 현재 단계 점만 22px로 늘어남.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots();
  @override
  Widget build(BuildContext context) {
    final step = context.findAncestorStateOfType<_GunghapCalculatingScreenState>()?._step ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: i == step ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i <= step ? GHColors.gold : GHColors.lineSoft,
            ),
          ),
        ],
      ],
    );
  }
}

/// [S42] 「분석을 멈출까요」 뒤로가기 확인 시트.
class _StopConfirmSheet extends StatelessWidget {
  const _StopConfirmSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        gradient: GHGradients.sheet,
        border: Border.all(color: GHColors.line),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(GHRadius.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: GHColors.gray.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '분석을 멈출까요',
            textAlign: TextAlign.center,
            style: GHText.ui(size: 19, weight: FontWeight.w800, color: GHColors.fg),
          ),
          const SizedBox(height: 10),
          Text(
            '입력한 정보는 그대로 남아 있어요.\n복주머니는 차감되지 않아요.',
            textAlign: TextAlign.center,
            style: GHText.ui(size: 13.5, color: GHColors.gray, height: 1.6),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: GHButton(
                  label: '멈추고 돌아가기',
                  variant: GHButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GHButton(
                  label: '계속 기다리기',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
