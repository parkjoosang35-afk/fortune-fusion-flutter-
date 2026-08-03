import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/open_pass_repository.dart';
import '../data/rewarded_ad_simulator.dart';
import '../domain/open_pass_models.dart';
import '../domain/open_pass_resolvers.dart';
import 'pass_provider.dart';

/// [열림패스 첨부/광고소스 연동] 광고 시청 → 실제 보상 지급 플로우 전체 결과.
class OpenPassRewardFlowResult {
  final bool success;
  final OpenPassRewardGrantModel? grant;
  final OpenPassRewardFailedModel? failedInfo;
  final String? errorMessage;

  const OpenPassRewardFlowResult._({
    required this.success,
    this.grant,
    this.failedInfo,
    this.errorMessage,
  });

  factory OpenPassRewardFlowResult.granted(OpenPassRewardGrantModel grant) =>
      OpenPassRewardFlowResult._(success: true, grant: grant);

  factory OpenPassRewardFlowResult.failed(
    OpenPassRewardFailedModel info,
  ) => OpenPassRewardFlowResult._(success: false, failedInfo: info);

  factory OpenPassRewardFlowResult.error(String message) =>
      OpenPassRewardFlowResult._(success: false, errorMessage: message);
}

/// [열림패스 첨부/광고소스 연동] 어드민이 등록한 첨부/광고소스 값을 실제
/// 화면 동작(배너 노출·광고 버튼 노출·시청·지급·실패 대응)으로 연결하는
/// 오케스트레이터.
///
/// 흐름: 상품 상세 조회(→ 광고소스 목록/우선순위/시청가능여부 확보) →
/// [OpenPassAdSourceResolver]로 시도할 소스 1개 선택 → [RewardedAdSimulator]
/// 로 시청 → 성공 시 `reward-complete`(실제 지급 + [PassProvider] 즉시 반영),
/// 실패/노필 시 `reward-failed`(대체 크리에이티브 조회)로 마무리한다.
///
/// ChangeNotifier가 아닌 상태 없는 서비스 클래스로 두고, 상태 갱신은
/// [PassProvider]가 전담한다(§15: 두 곳에서 같은 상태를 따로 들고 있지 않음).
class OpenPassRewardController {
  OpenPassRewardController({
    required OpenPassRepository repository,
    required PassProvider passProvider,
  }) : _repository = repository,
       _passProvider = passProvider;

  final OpenPassRepository _repository;
  final PassProvider _passProvider;

  final _rand = Random();

  String _newIdempotencyKey(int policyId, int adSourceId) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final salt = _rand.nextInt(1 << 32);
    return 'flutter-$policyId-$adSourceId-$ts-$salt';
  }

  /// 상품 상세(첨부 + 광고소스 + eligible 여부)를 최신으로 조회한다.
  /// 광고 버튼 노출 여부는 이 결과의 `product.adRewardEnabled` +
  /// `nextEligibleAdSource != null` 조합으로 판단한다(호출부는 재판단하지 않음).
  Future<OpenPassProductDetailModel?> loadDetail(int policyId) async {
    final result = await _repository.getProductDetail(policyId);
    if (!result.success) {
      debugPrint('[OpenPassRewardController] 상세 조회 실패: ${result.errorMessage}');
      return null;
    }
    return result.data;
  }

  /// 광고 시청 → 지급/실패 전체 흐름을 실행한다.
  /// [showAd]는 UI(다이얼로그)를 노출하는 콜백으로, 화면(BuildContext)에
  /// 의존하는 부분만 호출부에서 주입받아 이 컨트롤러는 context에 의존하지 않는다.
  Future<OpenPassRewardFlowResult> watchAdAndClaim({
    required int policyId,
    required List<OpenPassAdSourceBindingModel> adSources,
    required Future<RewardedAdOutcome> Function(
      OpenPassAdSourceBindingModel source,
    )
    showAd,
  }) async {
    final target = OpenPassAdSourceResolver.pickAttemptTarget(adSources);
    if (target == null) {
      return OpenPassRewardFlowResult.error('지금 이용 가능한 광고가 없습니다.');
    }

    if (!target.isUsable) {
      // 서버가 이미 불가 판정을 내린 상태(쿨다운/일일한도) — 광고를 재생하지
      // 않고 즉시 reward-failed로 사유를 기록하고 대체 크리에이티브를 받아온다.
      final failedResult = await _repository.rewardFailed(
        policyId: policyId,
        adSourceId: target.adSourceId,
        reason: 'ad_fail',
      );
      if (failedResult.success) {
        return OpenPassRewardFlowResult.failed(failedResult.data!);
      }
      return OpenPassRewardFlowResult.error(
        target.eligibilityReason ?? '지금은 광고를 시청할 수 없습니다.',
      );
    }

    final outcome = await showAd(target);

    if (outcome == RewardedAdOutcome.completed) {
      final idempotencyKey = _newIdempotencyKey(policyId, target.adSourceId);
      final grantResult = await _repository.rewardComplete(
        policyId: policyId,
        adSourceId: target.adSourceId,
        idempotencyKey: idempotencyKey,
      );
      if (grantResult.success) {
        _passProvider.applyOpenPassRewardGrant(grantResult.data!);
        return OpenPassRewardFlowResult.granted(grantResult.data!);
      }
      // 지급 거부(경합 상태로 쿨다운/한도에 걸린 경우 등) — 실패 플로우로 이어간다.
      final failedResult = await _repository.rewardFailed(
        policyId: policyId,
        adSourceId: target.adSourceId,
        reason: 'ad_fail',
      );
      if (failedResult.success) {
        return OpenPassRewardFlowResult.failed(failedResult.data!);
      }
      return OpenPassRewardFlowResult.error(
        grantResult.errorMessage ?? '보상 지급에 실패했습니다.',
      );
    }

    // [프리패스 테스트 인프라] §4/§9 — 스킵/노필/취소/타임아웃을 각각 다른
    // reason으로 서버에 남겨 로그·대체 크리에이티브 분기가 사유별로 구분되게 한다.
    final reason = switch (outcome) {
      RewardedAdOutcome.noFill => 'no_fill',
      RewardedAdOutcome.cancelled => 'cancel',
      RewardedAdOutcome.timeout => 'timeout',
      RewardedAdOutcome.skippedEarly => 'ad_fail',
      RewardedAdOutcome.completed => 'ad_fail', // 도달하지 않음(위에서 이미 처리)
    };
    final failedResult = await _repository.rewardFailed(
      policyId: policyId,
      adSourceId: target.adSourceId,
      reason: reason,
    );
    if (failedResult.success) {
      return OpenPassRewardFlowResult.failed(failedResult.data!);
    }
    return OpenPassRewardFlowResult.error(
      failedResult.errorMessage ?? '처리 중 오류가 발생했습니다.',
    );
  }
}
