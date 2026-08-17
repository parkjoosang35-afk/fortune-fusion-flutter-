import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_token_store.dart';
import '../../auth/application/auth_provider.dart';
import '../data/jeontong_profile_store.dart';
import 'jeontong_input.dart';

/// [신통방통 2단계 - 로컬 → 서버 1회성 마이그레이션]
///
/// 기존에(서버 UserProfile 통합 이전 또는 로그인 이전) 로컬(SharedPreferences)
/// [JeontongProfileStore]에 저장해두었던 사주 입력값을, 로그인한 회원의 서버
/// UserProfile로 1회 옮긴다.
///
/// [지켜야 할 조건 — 사용자 지시 원문 그대로]
/// - 로그인 사용자만 대상.
/// - 서버 UserProfile에 운세 정보(birthDate)가 비어 있을 때만 이전한다.
/// - 이미 서버 데이터가 있으면 절대 덮어쓰지 않는다.
/// - 비로그인 fallbackUserId=1 데이터는 특정 회원의 데이터로 간주하지
///   않으므로 자동으로 이전하지 않는다 — 이를 위해
///   [AuthTokenStore.getCurrentUserId]가 fallbackUserId를 반환하면(=진짜
///   로그인 사용자 ID를 알 수 없는 상태) 즉시 중단한다. 다른 화면들이 쓰는
///   `cachedUserIdOrNull ?? fallbackUserId` 널 병합 패턴을 여기서는 쓰지
///   않는 이유도 이것이다 — 널 병합으로 fallback이 섞여 들어가면 "누구의
///   데이터인지 모르는 값"을 실제 로그인 사용자의 것처럼 다루게 될 위험이
///   있다. [AuthTokenStore.getCurrentUserId]는 SharedPreferences에 영속된
///   실제 로그인 시 저장된 userId까지 확인하므로, 콜드부트(세션 복원) 직후
///   에도 안전하게 "진짜 로그인 사용자인지"를 판별할 수 있다.
/// - 이전 성공/스킵/실패 여부를 [JeontongProfileMigrationOutcome]으로 명확히
///   구분해 반환한다(성공 여부 확인 가능 요건).
/// - 로컬 데이터는 이 함수가 절대 삭제하지 않는다([JeontongProfileStore.clear]
///   호출 없음) — 마이그레이션 후에도 로컬은 당분간 폴백 캐시로 유지된다.
///
/// [PHASE1~4/계산엔진 무관] 이 함수는 이미 존재하는 값을 그대로 옮기기만
/// 한다. 새로운 계산 로직이 없으며, 기존 [AuthProvider.updateProfile]
/// (→ [AuthRepository.updateProfile] → PATCH `/api/public/auth/profile`)을
/// 그대로 재사용한다 — PHASE1~4 계산 파이프라인은 전혀 호출하지 않는다.
enum JeontongProfileMigrationOutcome {
  /// 실제로 로컬 → 서버 이전이 수행되어 성공했다.
  migrated,

  /// 로그인 사용자가 아니다(비로그인 또는 진짜 로그인 userId를 확인할 수 없음).
  skippedNotLoggedIn,

  /// 서버 UserProfile에 이미 운세 정보(birthDate)가 있어 덮어쓰지 않았다.
  skippedServerAlreadyHasData,

  /// 로컬([JeontongProfileStore])에 이전할 데이터가 없었다.
  skippedNoLocalData,

  /// 서버 업데이트([AuthProvider.updateProfile]) 호출이 실패했다.
  failed,
}

@immutable
class JeontongProfileMigrationResult {
  const JeontongProfileMigrationResult(this.outcome, {this.detail});

  final JeontongProfileMigrationOutcome outcome;

  /// 디버깅/로그용 부가 설명(선택). 사용자에게 노출하지 않는다.
  final String? detail;

  bool get isMigrated => outcome == JeontongProfileMigrationOutcome.migrated;

  @override
  String toString() =>
      'JeontongProfileMigrationResult(outcome: $outcome, detail: $detail)';
}

/// 로컬 [JeontongProfileStore] → 서버 UserProfile 1회성 마이그레이션을
/// 시도한다. 여러 번 호출해도 안전하다(멱등) — 이미 서버에 데이터가 있으면
/// 매번 [JeontongProfileMigrationOutcome.skippedServerAlreadyHasData]만
/// 반환하고 아무 것도 바꾸지 않는다.
Future<JeontongProfileMigrationResult> migrateLocalJeontongProfileToServer(
  AuthProvider authProvider,
) async {
  if (!authProvider.isLoggedIn) {
    return const JeontongProfileMigrationResult(
      JeontongProfileMigrationOutcome.skippedNotLoggedIn,
      detail: '비로그인 상태',
    );
  }

  final user = authProvider.currentUser;
  if (user == null) {
    return const JeontongProfileMigrationResult(
      JeontongProfileMigrationOutcome.skippedNotLoggedIn,
      detail: 'currentUser == null',
    );
  }

  // 서버 UserProfile에 이미 생년월일이 있으면(=이미 채워진 상태) 절대
  // 덮어쓰지 않는다.
  if (user.birthDate != null && user.birthDate!.isNotEmpty) {
    return const JeontongProfileMigrationResult(
      JeontongProfileMigrationOutcome.skippedServerAlreadyHasData,
    );
  }

  // [비로그인 fallbackUserId=1 데이터 자동 이전 방지] SharedPreferences에
  // 영속된 실제 로그인 userId까지 확인한다. 이 값이 fallbackUserId와 같다면
  // "이 세션에서 진짜 로그인 사용자의 userId를 확인할 수 없다"는 뜻이므로,
  // 절대 fallback 로컬 데이터를 이 회원의 것으로 간주하지 않고 중단한다.
  final resolvedUserId = await AuthTokenStore.getCurrentUserId();
  if (resolvedUserId == AuthTokenStore.fallbackUserId) {
    return const JeontongProfileMigrationResult(
      JeontongProfileMigrationOutcome.skippedNotLoggedIn,
      detail: '실제 로그인 userId를 확인할 수 없어(fallbackUserId) 이전하지 않음',
    );
  }

  final JeontongInput? local = await jeontongProfileStore.get(
    resolvedUserId.toString(),
  );
  if (local == null) {
    return const JeontongProfileMigrationResult(
      JeontongProfileMigrationOutcome.skippedNoLocalData,
    );
  }

  final birthDateStr =
      '${local.birthDateTimeLocal.year}-'
      '${local.birthDateTimeLocal.month.toString().padLeft(2, '0')}-'
      '${local.birthDateTimeLocal.day.toString().padLeft(2, '0')}';
  // 출생시간을 모른다고 표시된 로컬 데이터는 서버에도 시간을 별도로 전송하지
  // 않는다(관례값 12:00은 계산 시점에 항상 적용되므로 서버 birth_time을
  // null로 두어도 계산 결과에는 영향이 없다 — user_profile_to_jeontong_adapter.dart
  // 와 동일한 규약).
  final birthTimeStr = local.birthTimeUnknown
      ? null
      : '${local.birthDateTimeLocal.hour.toString().padLeft(2, '0')}:'
            '${local.birthDateTimeLocal.minute.toString().padLeft(2, '0')}';

  final ok = await authProvider.updateProfile(
    birthDate: birthDateStr,
    birthTime: birthTimeStr,
    isLunar: local.isLunar,
    isLeapMonth: local.effectiveIsLeapMonth,
    birthTimeUnknown: local.birthTimeUnknown,
    gender: local.gender,
  );

  if (!ok) {
    return const JeontongProfileMigrationResult(
      JeontongProfileMigrationOutcome.failed,
    );
  }

  // [로컬 데이터 즉시 삭제 금지] jeontongProfileStore.clear()를 호출하지
  // 않는다 — 로컬은 당분간 폴백 캐시로 유지한다(사용자 지시 원문).
  return const JeontongProfileMigrationResult(
    JeontongProfileMigrationOutcome.migrated,
  );
}
