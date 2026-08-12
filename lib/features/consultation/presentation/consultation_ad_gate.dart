import 'package:flutter/material.dart';
import '../../pass/data/rewarded_ad_simulator.dart';
import '../application/consultation_provider.dart';

/// [AI 상담 채팅 실연동] 세션 시작(§`ConsultationProvider.startSession`/
/// `changeType`) 호출 결과가 [ConsultationStartOutcome.needsAdReward]이면
/// 리워드 광고 시청 게이트를 띄우고, 시청 완료 시
/// `completeAdReward` → `startSession(type, adRewardLogId: ...)` 순으로
/// 재시도해 세션 생성을 완결시키는 공통 플로우.
///
/// `ConsultationTypeScreen`(최초 진입/유형 변경)과
/// `DailyFortuneResultScreen`(고민상담 버튼)에서 동일하게 재사용된다
/// (§15: 광고게이트 플로우를 화면마다 따로 구현하지 않는다).
///
/// [changeMode]가 true면 1차 시도에 `provider.changeType(type)`을 사용한다
/// (기존 세션이 있는 유형 변경 UX 유지). 광고 시청이 필요한 경우의 최종
/// 재시도는 `changeType`이 `adRewardLogId` 파라미터를 받지 않으므로 항상
/// `provider.startSession(type, adRewardLogId: ...)`을 직접 호출한다 —
/// 내부적으로 `changeType`도 결국 메시지/수집정보 초기화 후 `startSession`을
/// 호출하는 것과 동일한 결과를 낸다.
///
/// 반환값:
/// - `true`: 세션이 정상적으로 시작됨(광고 시청 불필요, 또는 시청 후 재시도 성공)
/// - `false`: 세션 시작 실패(서버 오류/시청 가능한 광고 없음/시청 실패·취소 등) —
///   이미 [SnackBar]로 사용자에게 안내했으므로 호출부는 화면 이동만 취소하면 된다.
Future<bool> runConsultationAdGateAndStart(
  BuildContext context,
  ConsultationProvider provider,
  String type, {
  bool changeMode = false,
}) async {
  final outcome = changeMode
      ? await provider.changeType(type)
      : await provider.startSession(type);

  if (outcome == ConsultationStartOutcome.started) {
    return true;
  }

  if (outcome == ConsultationStartOutcome.error) {
    if (context.mounted) {
      _showError(
        context,
        provider.lastErrorMessage ?? '상담 세션을 시작하지 못했어요. 잠시 후 다시 시도해주세요.',
      );
    }
    return false;
  }

  // outcome == ConsultationStartOutcome.needsAdReward
  // 오늘 첫 세션인데 광고 시청 완료 기록이 없어 서버가 거부한 경우 —
  // 광고 시청 게이트를 띄운 뒤 성공 시 세션 생성을 재시도한다.
  final sources = await provider.fetchAdSources();
  final usable = sources.where((s) => s.isUsable).toList();
  if (usable.isEmpty) {
    if (context.mounted) {
      _showError(context, '지금은 시청 가능한 광고가 없어요. 잠시 후 다시 시도해주세요.');
    }
    return false;
  }

  final adSource = usable.first;
  if (!context.mounted) return false;
  final adOutcome = await RewardedAdSimulator.show(
    context,
    source: adSource.toBindingModel(),
  );

  if (adOutcome != RewardedAdOutcome.completed) {
    if (context.mounted) {
      _showError(context, '광고 시청이 완료되지 않아 상담을 시작할 수 없어요.');
    }
    return false;
  }

  final adRewardLogId = await provider.completeAdReward(adSource.adSourceId);
  if (adRewardLogId == null) {
    if (context.mounted) {
      _showError(
        context,
        provider.lastErrorMessage ?? '광고 시청 기록 처리에 실패했어요. 다시 시도해주세요.',
      );
    }
    return false;
  }

  final retryOutcome = await provider.startSession(
    type,
    adRewardLogId: adRewardLogId,
  );
  if (retryOutcome != ConsultationStartOutcome.started) {
    if (context.mounted) {
      _showError(
        context,
        provider.lastErrorMessage ?? '상담 세션을 시작하지 못했어요. 잠시 후 다시 시도해주세요.',
      );
    }
    return false;
  }
  return true;
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
