import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_unified_style.dart';
import '../domain/open_pass_models.dart';

/// 리워드 광고 시청 결과.
enum RewardedAdOutcome {
  /// 끝까지 시청 완료 — 보상 지급 대상.
  completed,

  /// 재생 중 사용자가 닫음(스킵) — 실패로 처리.
  skippedEarly,

  /// 광고 자체가 없음(no-fill) — 실패로 처리하되 사유를 구분한다.
  noFill,

  /// [프리패스 테스트 인프라] §4 — 사용자가 광고를 중도에 취소함(스킵과는
  /// 별도 사유로 서버/로그에 남겨 §9 로그 구분·§8 취소 시나리오 테스트를
  /// 가능하게 한다).
  cancelled,

  /// [프리패스 테스트 인프라] §4 — 광고 로드/재생이 제한 시간 내 끝나지
  /// 않아 타임아웃 처리됨(네트워크 지연 등 실패 유형 구분용).
  timeout,
}

/// [열림패스 첨부/광고소스 연동] 리워드 광고 시청 어댑터.
///
/// admin_web에서 광고소스를 등록할 때 `testModeEnabled`를 켜두면(현재
/// 시드 데이터 전부 true) 실제 광고 SDK 호출 없이 이 시뮬레이터가
/// 대신 노출된다. 운영 전환 시에는 [source.sourceType]
/// (admob_rewarded/applovin_rewarded/…)별로 실제 AdMob/AppLovin SDK
/// 어댑터를 연결하는 지점이며, 그 실제 SDK 연동은 이번 작업 범위 밖이다
/// (§14 — 별도 SDK 통합 작업으로 분리, 최종 보고서에 확장 지점으로 기록).
///
/// [프리패스 테스트 인프라] §4 — `source.isMock`(sourceType이
/// `mock_rewarded_*`)인 경우, 관리자가 등록한 [source.simulatedDurationSeconds]
/// 와 [source.failMode] 값에 따라 시청 결과가 **결정적으로(deterministic)**
/// 정해진다. 즉 관리자가 "실패 광고소스"를 연결해두면 앱에서는 항상
/// 실패로, "성공 광고소스"를 연결해두면 항상 성공으로 재현되어 §2/§13의
/// "실제 지급 흐름을 끝까지 테스트 가능"한 요구사항을 만족시킨다.
///
/// 일반(비-mock) 광고소스는 기존과 동일하게 사용자가 직접 "보상 받기"
/// 버튼을 눌러야 완료 처리된다(수동 시청 시뮬레이션 유지).
class RewardedAdSimulator {
  const RewardedAdSimulator._();

  static Future<RewardedAdOutcome> show(
    BuildContext context, {
    required OpenPassAdSourceBindingModel source,
    int watchSeconds = 5,
  }) async {
    final result = await showDialog<RewardedAdOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RewardedAdDialog(
        source: source,
        watchSeconds: source.isMock
            ? (source.simulatedDurationSeconds ?? 3).clamp(1, 60)
            : watchSeconds,
      ),
    );
    return result ?? RewardedAdOutcome.skippedEarly;
  }
}

/// mock_rewarded_* sourceType별로 시청 종료 시 어떤 [RewardedAdOutcome]으로
/// 귀결되어야 하는지 결정한다. admin_web `isMockAdSourceType()` /
/// `AD_SOURCE_TYPES` 목록과 1:1로 대응한다.
RewardedAdOutcome? _mockOutcomeFor(String sourceType) {
  switch (sourceType) {
    case 'mock_rewarded_success':
      return RewardedAdOutcome.completed;
    case 'mock_rewarded_fail':
      return RewardedAdOutcome.skippedEarly;
    case 'mock_rewarded_no_fill':
      return RewardedAdOutcome.noFill;
    case 'mock_rewarded_cancel':
      return RewardedAdOutcome.cancelled;
    case 'mock_rewarded_timeout':
      return RewardedAdOutcome.timeout;
    default:
      return null;
  }
}

class _RewardedAdDialog extends StatefulWidget {
  const _RewardedAdDialog({required this.source, required this.watchSeconds});

  final OpenPassAdSourceBindingModel source;
  final int watchSeconds;

  @override
  State<_RewardedAdDialog> createState() => _RewardedAdDialogState();
}

class _RewardedAdDialogState extends State<_RewardedAdDialog> {
  late int _remaining;
  bool _finished = false;
  bool _autoResolved = false;

  bool get _isMock => widget.source.isMock;
  RewardedAdOutcome? get _mockOutcome =>
      _mockOutcomeFor(widget.source.sourceType);

  @override
  void initState() {
    super.initState();
    _remaining = widget.watchSeconds;
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining > 0 ? _remaining - 1 : 0;
        if (_remaining == 0) _finished = true;
      });
      if (_remaining > 0) {
        _tick();
      } else {
        _resolveIfMock();
      }
    });
  }

  /// [프리패스 테스트 인프라] §4 — mock 광고소스는 진행바가 끝나는 즉시
  /// sourceType이 지정한 결과로 자동 종료된다(사용자 클릭 불필요 —
  /// "실제 지급 흐름을 끝까지 테스트 가능"하도록 결정적 동작 보장).
  void _resolveIfMock() {
    if (!_isMock || _autoResolved || !mounted) return;
    final outcome = _mockOutcome;
    if (outcome == null) return;
    _autoResolved = true;
    // 사용자가 결과 화면을 인지할 수 있도록 짧은 지연 후 닫는다.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.of(context).pop(outcome);
    });
  }

  String get _mockResultLabel {
    switch (_mockOutcome) {
      case RewardedAdOutcome.completed:
        return '테스트 성공 — 보상 지급 처리 중…';
      case RewardedAdOutcome.skippedEarly:
        return '테스트 실패 — 광고 재생 실패로 처리됩니다';
      case RewardedAdOutcome.noFill:
        return '테스트 노필 — 표시할 광고가 없습니다';
      case RewardedAdOutcome.cancelled:
        return '테스트 취소 — 중도 취소로 처리됩니다';
      case RewardedAdOutcome.timeout:
        return '테스트 타임아웃 — 응답 지연으로 처리됩니다';
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return Dialog(
      backgroundColor: UnifiedColors.black,
      insetPadding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      child: SizedBox(
        height: 380,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smart_display_rounded,
                    color: UnifiedColors.neon,
                    size: 64,
                  ),
                  const SizedBox(height: UnifiedTokens.spaceMd),
                  Text(
                    _isMock ? '테스트 리워드 광고 재생 중' : '리워드 광고 재생 중',
                    style: UnifiedText.bodyStrong(color: Colors.white),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceXs),
                  Text(
                    source.networkName ?? source.sourceName,
                    style: UnifiedText.caption(color: const Color(0xFFB8B8B8)),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceLg),
                  if (_isMock) ...[
                    // [프리패스 테스트 인프라] §10 — 진행바 형태로 시청 경과를
                    // 시각화(관리자가 지정한 simulatedDurationSeconds 기준).
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: widget.watchSeconds == 0
                            ? 1
                            : 1 - (_remaining / widget.watchSeconds),
                        backgroundColor: const Color(0xFF2A2A2A),
                        color: UnifiedColors.neon,
                      ),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceMd),
                    Text(
                      _finished ? _mockResultLabel : '$_remaining초 남음 (테스트 광고)',
                      textAlign: TextAlign.center,
                      style: UnifiedText.caption(color: UnifiedColors.neon),
                    ),
                  ] else if (!_finished)
                    Text(
                      '$_remaining초 후 보상 받기 활성화',
                      style: UnifiedText.caption(color: UnifiedColors.neon),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(RewardedAdOutcome.completed),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UnifiedColors.neon,
                        foregroundColor: UnifiedColors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            UnifiedTokens.radiusPill,
                          ),
                        ),
                      ),
                      child: const Text('보상 받기'),
                    ),
                ],
              ),
            ),
            Positioned(
              top: UnifiedTokens.spaceSm,
              right: UnifiedTokens.spaceSm,
              child: IconButton(
                onPressed: _finished
                    ? null
                    : () => Navigator.of(context).pop(
                        // 재생 도중 닫기는 "중도 취소"로 구분한다(§4/§8 취소
                        // 시나리오와 실제 사용자 행동을 동일하게 취급).
                        RewardedAdOutcome.cancelled,
                      ),
                icon: Icon(
                  Icons.close_rounded,
                  color: _finished
                      ? Colors.transparent
                      : const Color(0xFFB8B8B8),
                ),
              ),
            ),
            if (kDebugMode && !_isMock)
              Positioned(
                bottom: UnifiedTokens.spaceSm,
                left: 0,
                right: 0,
                child: Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(RewardedAdOutcome.noFill),
                    child: Text(
                      '[QA] 노필(광고없음) 시뮬레이션',
                      style: UnifiedText.caption(
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
