import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';

/// [로컬 영속성] 모든 단위/위젯 테스트 실행 전에 Hive를 실제로 초기화한다.
///
/// `package:test`는 `test/` 디렉토리에 `flutter_test_config.dart`가 있으면
/// 그 안의 `testExecutable`을 각 테스트 파일 실행을 감싸는 wrapper로 자동
/// 사용한다(개별 테스트 파일을 수정할 필요가 없다).
///
/// [배경] Hive를 사용하는 로컬 스토어 구현체들은 `Hive.openBox()`를
/// 호출하는데, 테스트 환경에서는 `Hive.initFlutter()`(Flutter 플러그인
/// 경로 조회 필요)를 호출할 수 없다. 대신 순수 Dart API인 `Hive.init(path)`에
/// OS 임시 디렉터리를 넘겨 초기화하면, 테스트에서도 실제 디스크 I/O를
/// 거치는 진짜 Hive box를 사용할 수 있다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
  await testMain();
}
