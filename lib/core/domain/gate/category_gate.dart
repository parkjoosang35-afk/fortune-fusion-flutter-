import '../../../features/home/domain/fortune_matrix.dart';
import '../access/access_checker.dart';
import 'category_usage_store.dart';

/// [운섹션 87 카테고리 통합] PassGate 단일 판정 레이어.
///
/// 기존 [AccessChecker]/[PassProvider]가 이미 "열림패스가 활성 상태인가"를
/// 담당하고 있으므로, 이 클래스는 새로운 자산/서버 호출을 추가하지 않고
/// 그 위에 "87개 카테고리 각각의 무료 정책([GateResult])"만 얹는 얇은
/// 판정 레이어다. 처음부터 새 아키텍처(Riverpod/go_router 등)를 도입하지
/// 않고, 기존 Provider 기반 구조에 자연스럽게 얹는 것이 목표다.
///
/// 판정 흐름(모든 카테고리 공통):
/// 1. [FortuneCategoryEntry.gate]가 [GateResult.openFree]면 항상 허용.
/// 2. 열림패스가 이미 활성 상태([AccessChecker.isOpenPassActive])면
///    정책과 무관하게 항상 허용(패스 이용 중에는 모든 운세를 열람 가능).
/// 3. [GateResult.freeOncePerDay] — 오늘 아직 안 봤으면 허용 + 열람 기록.
/// 4. [GateResult.lockedFreeFirst] — 평생 처음이면 허용 + 열람 기록.
/// 5. [GateResult.paidOnlyPassGate] 또는 이미 무료 소진 — 차단, 프리패스
///    발급 유도 바텀시트로 연결.
class CategoryGateDecision {
  const CategoryGateDecision({
    required this.allowed,
    required this.result,
    this.reasonLabel,
  });

  /// 지금 즉시 콘텐츠를 열람해도 되는지.
  final bool allowed;

  /// 판정에 사용된 최종 게이트 결과 유형.
  final GateResult result;

  /// 잠긴 경우 사용자에게 보여줄 담백한 이유 문구(선택).
  final String? reasonLabel;
}

class CategoryGate {
  CategoryGate._();

  /// [entry]에 대한 게이트 판정. [access]는 현재 열림패스 활성 여부를
  /// 조회하기 위해 주입한다(서버 재검증 없이 기존 [AccessChecker] 스냅샷을
  /// 그대로 신뢰 — 다른 카테고리 진입 로직과 동일한 원칙).
  static Future<CategoryGateDecision> decide(
    FortuneCategoryEntry entry,
    AccessChecker access,
  ) async {
    if (entry.gate == GateResult.openFree) {
      return const CategoryGateDecision(
        allowed: true,
        result: GateResult.openFree,
      );
    }

    if (access.isOpenPassActive()) {
      return const CategoryGateDecision(
        allowed: true,
        result: GateResult.granted,
      );
    }

    switch (entry.gate) {
      case GateResult.freeOncePerDay:
        final usedToday = await CategoryUsageStore.viewedToday(entry.id);
        if (!usedToday) {
          await CategoryUsageStore.markViewed(entry.id);
          return const CategoryGateDecision(
            allowed: true,
            result: GateResult.freeOncePerDay,
          );
        }
        return const CategoryGateDecision(
          allowed: false,
          result: GateResult.freeOncePerDay,
          reasonLabel: '오늘 무료 열람은 이미 사용했어요. 프리패스로 계속 볼 수 있어요.',
        );

      case GateResult.lockedFreeFirst:
        final usedEver = await CategoryUsageStore.viewedEver(entry.id);
        if (!usedEver) {
          await CategoryUsageStore.markViewed(entry.id);
          return const CategoryGateDecision(
            allowed: true,
            result: GateResult.lockedFreeFirst,
          );
        }
        return const CategoryGateDecision(
          allowed: false,
          result: GateResult.lockedFreeFirst,
          reasonLabel: '첫 무료 열람은 이미 사용했어요. 프리패스로 다시 볼 수 있어요.',
        );

      case GateResult.paidOnlyPassGate:
      case GateResult.cooldown:
        return const CategoryGateDecision(
          allowed: false,
          result: GateResult.paidOnlyPassGate,
          reasonLabel: '프리패스로 열람할 수 있는 콘텐츠예요.',
        );

      case GateResult.openFree:
      case GateResult.granted:
        // 위에서 이미 처리됨(도달하지 않음) — 안전망.
        return const CategoryGateDecision(
          allowed: true,
          result: GateResult.openFree,
        );
    }
  }
}
