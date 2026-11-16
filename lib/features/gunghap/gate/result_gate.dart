// ═══════════════════════════════════════════════════════════════
// FILE: result_gate.dart
// [궁합지도 핸드오프 v4 반영] design_handoff_gunghap_map_v4
// `00_DEV_MAPPING.md` §5 S19~S20(결제 전 확인/부족) · S33~S41(생성 중
// 8단계 · 완료 · 실패 · 결제오류 · 취소 · 중복 · 게스트) + `flutter_starter/
// lib/gunghap/gate/result_gate.dart`(v3 참고 구현)를 **이 프로젝트의
// 실제 백엔드 계약**에 맞춰 재설계해 이식했다.
//
// [핵심 아키텍처 차이 — v4 참고코드와 다르게 구현한 이유]
// v4 참고코드는 `ReportApi.unlock()`이 jobId를 반환하고 `watch(jobId)`가
// {status, stage, refunded}를 실시간 스트리밍한다고 전제한다(서버가
// 비동기 job 큐를 돌린다는 가정). 그러나 이 프로젝트의 실제 서버
// (`admin_web/src/app/api/public/gunghap/results/[resultId]/unlock/
// route.ts`)를 직접 확인한 결과, unlock은 **단일 동기 POST 호출**이다
// — 1차 트랜잭션(멱등 확인 + 100P 차감)과 LLM 생성(트랜잭션 밖, 최대
// 35초×2회)을 전부 끝낸 뒤 완성된 결과를 한 번에 응답한다. job id도,
// 진행 단계를 조회하는 별도 API도 존재하지 않는다.
//
// 따라서 이 구현은:
//  - `ReportApi.status()`(사전 잔액/가격 조회) 없이, 호출부가 이미 들고
//    있는 `LuckPouchProvider.balance`와 `result['unlockCost']`로 즉시
//    [GConfirm]/[GShort]를 계산한다(`start()`가 동기적으로 끝난다).
//  - `ReportApi.unlock()`을 `GunghapProvider.unlock(resultId)` 단일
//    호출로 감싸고, 그 호출이 끝날 때까지 "생성 중" 8단계 애니메이션을
//    **로컬 타이머로 시뮬레이션**한다 — `guinji_loading_screen.dart`가
//    이미 쓰고 있는 선례("로컬 타이머 애니메이션 + 실제 API를 동시에
//    돌리고, 둘 중 더 늦게 끝나는 쪽을 기다렸다가 다음 상태로 넘어간다")
//    를 그대로 재사용한다. 서버가 진짜로 보낸 stage 신호가 아니라는
//    점이 v4와 다르지만, 사용자에게 "8단계로 진행 중"이라는 느낌을
//    주는 연출 목적은 동일하게 달성한다.
//  - 서버는 `unique([userId, resultId])` 제약 + 선확인으로 **스스로
//    멱등성을 보장**하므로(동일 결과를 다시 호출해도 재과금 없이
//    `alreadyUnlocked:true`), v4처럼 클라이언트가 `requestKey`를 만들어
//    서버에 보낼 필요가 없다. [GDuplicate]는 "같은 버튼을 두 번 빠르게
//    누르는" 클라이언트 레벨 중복 호출만 방지하면 충분하므로, 로컬
//    `_busy` 플래그만으로 흉내낸다(서버 응답이 아니라 UI 자체 방어).
//  - 서버는 LLM이 끝내 실패해도 **예외가 아니라 성공 응답**
//    (`refunded:true` 필드가 포함된 200 응답)을 보낸다 — v4의
//    `GFail`(실패+환불, 재시도 유도)은 이 서버 계약과 맞지 않는다.
//    대신 [GDone]에 `refunded` 플래그를 실어, 결과 화면이 이미 갖고
//    있는 `_RefundNoticeBanner`(동일 문구·동일 톤)가 그대로 안내하게
//    한다 — 새 배너를 만들지 않는다.
//  - [GGuest]는 게스트 결과 화면(`gunghap_guest_result_screen.dart`)에
//    애초에 잠금해제 버튼 자체가 없어(권한 설계상 당연 — 복주머니는
//    로그인 계정 소유) 이 게이트가 열릴 경로가 없다. v4 상태 목록에는
//    있으나 이 프로젝트에서는 사용하지 않는다(필요해지면 추가).
//  - 실제 네트워크/서버 오류(401/403/404/409/4xx/네트워크 단절)는 모두
//    [GPayError]로 단순화한다 — `GunghapProvider.errorCode`를 그대로
//    실어 화면이 세부 안내 문구를 고를 수 있게 한다.
// ═══════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';

import '../application/gunghap_provider.dart';
import '../domain/gunghap_data.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';

sealed class Gate {
  const Gate();
}

/// 결제 전 확인 — 잔액 충분(§5 S19).
class GConfirm extends Gate {
  const GConfirm(this.balance, this.price);
  final int balance, price;
}

/// 복주머니 부족(§5 S20).
class GShort extends Gate {
  const GShort(this.balance, this.price);
  final int balance, price;
  int get lack => price - balance;
}

/// 차감 처리 중(§5 S35, 8단계 애니메이션 0단계 — "복주머니 사용").
class GProcessing extends Gate {
  const GProcessing();
}

/// 보고서 생성 중(§5 S33, 8단계 — 서버 stage가 아니라 로컬 타이머
/// 시뮬레이션. 1..8).
class GGenerating extends Gate {
  const GGenerating(this.stage);
  final int stage;
}

/// 완료(§5 S36). [refunded]가 true면 LLM 생성이 실패해 100P가 자동
/// 환불됐다는 뜻(서버가 이미 성공 응답으로 알려준 값 — 에러 아님).
class GDone extends Gate {
  const GDone({this.refunded = false});
  final bool refunded;
}

/// 결제/네트워크 오류(401/403/404/409/4xx/연결 실패 전부 포함).
class GPayError extends Gate {
  const GPayError([this.message, this.code]);
  final String? message;
  final String? code;
}

/// 사용자가 시트를 닫아 취소함(차감 없음).
class GCancelled extends Gate {
  const GCancelled();
}

/// 같은 버튼을 빠르게 두 번 눌러 중복 요청을 막은 경우(클라이언트
/// 레벨 방어 — 서버 멱등과는 별개).
class GDuplicate extends Gate {
  const GDuplicate();
}
// owned(이미 해금된 결과) → 이 시트를 열지 않고 바로 결과 화면에서
// 상세 보고서 섹션을 보여준다(`gunghap_result_screen.dart`가 `unlocked`
// 여부로 이미 분기하므로 start() 호출 자체가 필요 없다).

/// [v3 참고 구현과 달리] 서버가 진짜 job/stage를 스트리밍하지 않으므로
/// 이 컨트롤러는 `GunghapProvider.unlock()` 단일 호출 + 로컬 타이머
/// 연출을 조합한다. `ReportApi` 같은 별도 인터페이스를 두지 않고
/// [GunghapProvider]를 직접 참조한다(이미 이 Provider가 결제 흐름의
/// 유일한 진입점이므로 추상화를 한 겹 더 두는 것이 과설계).
class ResultGateController extends ValueNotifier<Gate?> {
  ResultGateController({
    required this.provider,
    required this.resultId,
    required this.balance,
    required this.price,
    required this.openReport,
    required this.openPouch,
  }) : super(null);

  final GunghapProvider provider;
  final String resultId;

  /// 시트를 열 때 호출부(`GunghapResultScreen`)가 이미 갖고 있는
  /// [LuckPouchProvider.balance]/`result['unlockCost']`를 그대로
  /// 전달한다 — 별도 "잔액 조회" API가 없으므로 이 값이 곧 status().
  final int balance;
  final int price;

  final VoidCallback openReport;
  final VoidCallback openPouch;

  bool _busy = false;

  /// [생성 중 8단계 연출] 서버 stage가 없으므로 [ghGenStages.length](8)
  /// 구간을 일정 간격으로 로컬에서 흘려보낸다. 실제 `provider.unlock()`
  /// 호출이 이보다 먼저 끝나도 최소 노출 시간을 보장해(너무 빨리
  /// 깜빡이지 않도록) 자연스러운 체감을 준다 — `guinji_loading_screen
  /// .dart`의 "애니메이션과 API 중 더 늦게 끝나는 쪽을 기다린다" 패턴과
  /// 동일한 설계.
  Timer? _stageTimer;
  int _stage = 0;

  /// true = 시트 표시 필요(owned가 아니면 항상 true — 별도 status API가
  /// 없으므로 이 컨트롤러는 항상 동기적으로 [GConfirm]/[GShort]를 먼저
  /// 보여준다. "이미 해금됨" 분기는 호출부가 `result['unlocked']`로
  /// 이 컨트롤러를 아예 만들지 않는 방식으로 처리한다).
  bool start() {
    if (_busy) {
      value = const GDuplicate();
      return true;
    }
    value = balance >= price ? GConfirm(balance, price) : GShort(balance, price);
    return true;
  }

  Future<void> pay() async {
    if (_busy) {
      value = const GDuplicate();
      return;
    }
    _busy = true;
    _stage = 0;
    value = const GProcessing();

    // [로컬 타이머 연출 시작] 8단계를 총 약 6.4초에 걸쳐 흘려보낸다
    // (실제 LLM 생성이 수십 초 걸릴 수 있으므로, 8단계를 다 돈 뒤에는
    // 마지막 단계에 머물며 실제 API 완료를 기다린다 — 끝없이 숫자만
    // 올라가는 거짓 진행을 보여주지 않기 위함).
    const stageInterval = Duration(milliseconds: 800);
    _stageTimer = Timer.periodic(stageInterval, (timer) {
      if (_stage < ghGenStages.length) {
        _stage++;
        if (value is GProcessing || value is GGenerating) {
          value = GGenerating(_stage);
        }
      } else {
        timer.cancel();
      }
    });

    final ok = await provider.unlock(resultId);
    _stageTimer?.cancel();
    _busy = false;

    if (!ok) {
      value = GPayError(provider.error, provider.errorCode);
      return;
    }

    final refunded = provider.result?['refunded'] == true;
    value = GDone(refunded: refunded);
  }

  void cancel() => value = const GCancelled();

  bool get dismissible => value is! GProcessing && value is! GGenerating;

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }
}

/// `if (gate.start()) await showGHGateSheet(context, gate, me: ownerName,
/// partner: guestName, sub: subName ?? '궁합');`
Future<void> showGHGateSheet(
  BuildContext context,
  ResultGateController gate, {
  required String me,
  required String partner,
  required String sub,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: GHColors.scrim,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) => ValueListenableBuilder<Gate?>(
      valueListenable: gate,
      builder: (ctx, s, _) => PopScope(
        canPop: gate.dismissible,
        child: _GateSheet(state: s, gate: gate, me: me, partner: partner, sub: sub),
      ),
    ),
  );
}

class _GateSheet extends StatelessWidget {
  const _GateSheet({
    required this.state,
    required this.gate,
    required this.me,
    required this.partner,
    required this.sub,
  });
  final Gate? state;
  final ResultGateController gate;
  final String me, partner, sub;

  @override
  Widget build(BuildContext context) {
    final s = state;
    void close() {
      if (gate.dismissible) Navigator.pop(context);
    }

    late Widget body;
    late List<Widget> actions;
    switch (s) {
      case GConfirm(:final balance, :final price):
        body = _confirm(balance, price);
        actions = [
          GHButton(
            label: '복주머니 사용하고 상세 보고서 보기',
            leading: const Text('❖'),
            onPressed: gate.pay,
          ),
          GHButton(
            label: '다음에 볼게요',
            variant: GHButtonVariant.text,
            onPressed: gate.cancel,
          ),
        ];
      case GShort(:final balance, :final price):
        body = Column(
          children: [
            _info('❖', GHColors.rose, '복주머니가 부족합니다.', '조금만 더 모으면 상세 보고서를 열 수 있어요.'),
            const SizedBox(height: 14),
            _PricePanel(balance: balance, price: price),
          ],
        );
        actions = [
          GHButton(
            label: '복주머니 충전하기',
            leading: const Text('❖'),
            onPressed: () {
              Navigator.pop(context);
              gate.openPouch();
            },
          ),
          GHButton(
            label: '돌아가기',
            variant: GHButtonVariant.secondary,
            size: GHButtonSizeT.md,
            onPressed: close,
          ),
        ];
      case GProcessing():
        body = Column(
          children: [
            _info(
              '❖',
              GHColors.accent,
              '복주머니를 사용하고 있어요',
              '잠시만 기다려 주세요. 창을 닫아도 처리는 계속돼요.',
              spin: true,
            ),
            _Stages(current: 0, sub: sub),
          ],
        );
        actions = [const GHButton(label: '처리 중이에요', onPressed: null)];
      case GGenerating(:final stage):
        body = Column(
          children: [
            _info(
              '✦',
              GHColors.violet,
              '상세 보고서를 그리고 있어요',
              '8단계로 두 사람의 사주를 풀어 선택한 궁합만의 보고서로 엮고 있어요.',
              spin: true,
            ),
            _Stages(current: stage, sub: sub),
          ],
        );
        actions = [const GHButton(label: '보고서를 그리는 중…', onPressed: null)];
      case GDone(:final refunded):
        body = Column(
          children: [
            _info(
              '✓',
              GHColors.mint,
              '상세 보고서가 완성됐어요',
              refunded
                  ? '해석 생성이 원활하지 않아 복주머니는 자동으로 돌려드렸어요.\n참고용 해석을 바로 확인할 수 있어요.'
                  : '내 궁합에 저장돼 언제든 다시 볼 수 있어요.',
            ),
          ],
        );
        actions = [
          GHButton(
            label: '상세 보고서 펼치기',
            onPressed: () {
              Navigator.pop(context);
              gate.openReport();
            },
          ),
        ];
      case GPayError(:final message):
        body = _info(
          '◇',
          GHColors.rose,
          '복주머니를 사용하지 못했어요',
          message ?? '연결 상태를 확인하고 다시 시도해 주세요.',
        );
        actions = [
          GHButton(label: '다시 시도하기', onPressed: gate.pay),
          GHButton(
            label: '돌아가기',
            variant: GHButtonVariant.secondary,
            size: GHButtonSizeT.md,
            onPressed: close,
          ),
        ];
      case GCancelled():
        body = _info('✕', GHColors.muted, '사용을 취소했어요', '복주머니는 차감되지 않았어요.');
        actions = [
          GHButton(label: '확인', variant: GHButtonVariant.secondary, onPressed: close),
        ];
      case GDuplicate():
        body = _info(
          '⇆',
          GHColors.accent,
          '이미 처리 중인 요청이 있어요',
          '같은 보고서를 두 번 열지 않도록 막아 두었어요. 처리가 끝나면 자동으로 열려요.',
        );
        actions = [
          GHButton(label: '확인', variant: GHButtonVariant.secondary, onPressed: close),
        ];
      case null:
        body = const SizedBox(height: 120);
        actions = const [];
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .86),
      child: Container(
        decoration: BoxDecoration(
          gradient: GHGradients.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(GHRadius.sheet)),
          border: const Border(top: BorderSide(color: GHColors.line, width: GHBorder.width)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: GHColors.lineSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (s is GConfirm)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '결제 전 확인',
                        style: GHText.body(size: 17, weight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: close,
                      icon: const Text(
                        '✕',
                        style: TextStyle(fontSize: 16, color: GHColors.fg),
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: body,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirm(int balance, int price) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: GHGradients.primary,
          borderRadius: BorderRadius.circular(GHRadius.tier),
        ),
        child: Text(
          '✦ 상세 보고서',
          style: GHText.body(size: 12, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
      const SizedBox(height: 8),
      Text('상세 궁합 보고서', style: GHText.sheetTitle(size: 19)),
      const SizedBox(height: 4),
      Text(
        '$me ✦ $partner · $sub',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GHText.body(size: 13, color: GHColors.muted),
      ),
      const SizedBox(height: 14),
      _PricePanel(balance: balance, price: price),
      const SizedBox(height: 14),
      Text(
        '$sub 보고서에 담기는 내용',
        style: GHText.caption(color: GHColors.accent).copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 3.6,
        children: [
          for (final r in ghReportSections(sub))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: GHColors.fieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(r.no, style: GHText.hanja(size: 10, color: GHColors.accent)),
                  ),
                  Expanded(
                    child: Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GHText.body(size: 12).copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GHColors.lineSoft, width: GHBorder.width),
        ),
        child: Text(
          '· 버튼을 누르면 복주머니가 차감되고 보고서가 만들어져요.\n'
          '· 보고서를 만들지 못하면 복주머니는 자동으로 돌려드려요.\n'
          '· 한 번 연 보고서는 내 궁합에서 다시 볼 때 차감되지 않아요.',
          style: GHText.caption().copyWith(height: 1.65),
        ),
      ),
    ],
  );

  Widget _info(String glyph, Color tone, String title, String desc, {bool spin = false}) => Column(
    children: [
      const SizedBox(height: 8),
      Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone.withValues(alpha: .08),
          border: Border.all(color: tone.withValues(alpha: .45), width: GHBorder.width),
        ),
        child: _GlyphOrSpinner(glyph: glyph, tone: tone, spin: spin),
      ),
      const SizedBox(height: 14),
      Text(title, textAlign: TextAlign.center, style: GHText.sheetTitle(size: 20)),
      const SizedBox(height: 8),
      Text(
        desc,
        textAlign: TextAlign.center,
        style: GHText.body(size: 13.5, color: GHColors.muted).copyWith(height: 1.65),
      ),
    ],
  );
}

/// [spin=true] 회전 연출 — v4 원본 주석("RotationTransition 1회전/2.4s")을
/// 실제 구현으로 포팅.
class _GlyphOrSpinner extends StatefulWidget {
  const _GlyphOrSpinner({required this.glyph, required this.tone, required this.spin});
  final String glyph;
  final Color tone;
  final bool spin;
  @override
  State<_GlyphOrSpinner> createState() => _GlyphOrSpinnerState();
}

class _GlyphOrSpinnerState extends State<_GlyphOrSpinner> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  @override
  void initState() {
    super.initState();
    if (widget.spin) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(widget.glyph, style: TextStyle(fontSize: 30, color: widget.tone));
    if (_c == null) return text;
    return RotationTransition(turns: _c!, child: text);
  }
}

/// 가격 패널(00_DEV_MAPPING.md §4 PricePanel).
class _PricePanel extends StatelessWidget {
  const _PricePanel({required this.balance, required this.price});
  final int balance, price;
  @override
  Widget build(BuildContext context) {
    final short = balance < price;
    Widget row(String l, String v, {Color? c, bool top = true}) => Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        border: top ? const Border(top: BorderSide(color: GHColors.lineSoft, width: GHBorder.width)) : null,
      ),
      child: Row(
        children: [
          Expanded(child: Text(l, style: GHText.body(size: 13.5, color: GHColors.muted))),
          Text(v, style: GHText.body(size: 14, weight: FontWeight.w700, color: c ?? GHColors.fg)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GHColors.line, width: GHBorder.width),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: GHColors.fieldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('❖', style: TextStyle(color: GHColors.violet, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('상세 보고서 1회 열람', style: GHText.body(size: 14, weight: FontWeight.w700)),
              ),
              Text(
                '복주머니 $price개',
                style: GHText.body(size: 14, weight: FontWeight.w800, color: GHColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          row('보유한 복주머니', '$balance개'),
          short
              ? row('부족한 복주머니', '${price - balance}개', c: GHColors.rose)
              : row('사용 후 남는 복주머니', '${balance - price}개'),
        ],
      ),
    );
  }
}

/// 8단계 진행(STAGE 0n/08 · 퍼센트 · 4px 바 · 목록). [current]는 서버
/// stage가 아니라 [ResultGateController]의 로컬 타이머 값이다.
class _Stages extends StatelessWidget {
  const _Stages({required this.current, required this.sub});
  final int current; // 0 = processing(1단계 진행 중) · 1..8
  final String sub;
  @override
  Widget build(BuildContext context) {
    final pct = (current.clamp(0, 8) / 8 * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STAGE ${(current + 1).clamp(1, 8).toString().padLeft(2, '0')} / 08',
                style: GHText.mono(size: 9.5),
              ),
              const Spacer(),
              Text('$pct%', style: GHText.body(size: 15, weight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 4,
              backgroundColor: GHColors.lineSoft.withValues(alpha: .5),
              color: GHColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GHColors.lineSoft, width: GHBorder.width),
            ),
            child: Column(
              children: [
                for (var i = 0; i < ghGenStages.length; i++)
                  Builder(
                    builder: (_) {
                      final st = i < current ? 'done' : i == current ? 'now' : 'wait';
                      final (k, t, d) = ghGenStages[i];
                      return Opacity(
                        opacity: st == 'wait' ? .55 : 1,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 40),
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            border: i == 0
                                ? null
                                : const Border(top: BorderSide(color: GHColors.lineSoft, width: GHBorder.width)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: st == 'done' ? GHColors.mint : null,
                                  border: st == 'done'
                                      ? null
                                      : Border.all(color: st == 'now' ? GHColors.accent : GHColors.lineSoft),
                                ),
                                child: st == 'done'
                                    ? const Text('✓', style: TextStyle(fontSize: 11, color: Colors.white))
                                    : st == 'now'
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: GHColors.accent),
                                      )
                                    : Text('${i + 1}', style: GHText.mono(size: 9, color: GHColors.muted)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      k == 'topic' ? '$sub 3축 풀이' : t,
                                      style: GHText.body(
                                        size: 13,
                                        weight: st == 'now' ? FontWeight.w700 : FontWeight.w500,
                                        color: st == 'now' ? GHColors.accent : GHColors.fg,
                                      ),
                                    ),
                                    if (st == 'now') Text(d, style: GHText.caption()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
