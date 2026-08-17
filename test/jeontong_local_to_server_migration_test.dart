import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/home/domain/jeontong_local_to_server_migration.dart';

/// [신통방통 2단계 - 로컬 → 서버 1회성 마이그레이션] 회귀 테스트.
///
/// 실제 HTTP 호출(AuthRepository.updateProfile 등)은 이 단위 테스트
/// 범위 밖이다(네트워크 의존 배제) — 여기서는 함수 진입 시점의 "조건 판단"
/// 이 사용자 지시를 정확히 지키는지만 검증한다:
/// - 비로그인이면 무조건 skippedNotLoggedIn(서버 호출 자체를 하지 않음).
void main() {
  group('migrateLocalJeontongProfileToServer', () {
    test('비로그인 상태(AuthProvider.isLoggedIn=false)면 즉시 skippedNotLoggedIn을'
        ' 반환하고 서버를 호출하지 않는다', () async {
      final authProvider = AuthProvider(AuthRepository());
      expect(authProvider.isLoggedIn, isFalse);

      final result = await migrateLocalJeontongProfileToServer(authProvider);

      expect(
        result.outcome,
        JeontongProfileMigrationOutcome.skippedNotLoggedIn,
      );
      expect(result.isMigrated, isFalse);
    });
  });
}
