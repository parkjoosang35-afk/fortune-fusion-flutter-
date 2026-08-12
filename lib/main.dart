import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

/// [로컬 영속성] 앱 실행 시 실제 기기 documents 디렉터리를 기준으로
/// Hive를 초기화한다. Hive를 사용하는 로컬 스토어 모듈이 `Hive.openBox()`를
/// 호출하기 전에 반드시 이 초기화가 먼저 끝나 있어야 한다.
///
/// 순수 Dart 테스트 환경에서는 이 위젯 플러그인 기반 초기화를 쓸 수
/// 없으므로, 대신 `test/flutter_test_config.dart`에서 `Hive.init(경로)`로
/// 별도 초기화한다(Flutter 플러그인 경로 조회가 필요 없는 순수 Dart API).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const App());
}
