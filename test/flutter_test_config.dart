import 'dart:async';

/// [Stage2 결함수정 — 결함-H01-01] 과거 Hive 기반 로컬 스토어를 염두에 두고
/// 테스트 실행 전 `Hive.init()`을 수행하는 wrapper였으나, 실제로는 어떤 로컬
/// 스토어 구현체도 Hive를 사용하지 않아(모든 로컬 저장은 SharedPreferences)
/// 죽은 초기화 코드였다. Hive 의존성 자체를 제거(main.dart/pubspec.yaml 동시
/// 수정)하면서 이 파일도 함께 정리했다. `flutter_test_config.dart`는
/// `test/` 하위 모든 테스트 실행을 감싸는 wrapper 훅으로 계속 유지하되,
/// 현재는 별도 사전 초기화가 필요 없으므로 testMain을 그대로 호출한다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
