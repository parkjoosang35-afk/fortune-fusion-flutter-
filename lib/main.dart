import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'features/home/domain/saju_fortune_rules.dart';
import 'features/home/domain/saju_interpreter.dart';

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
  // [정통사주 실계산 활성화 - 미션 2] 만세력 해석 룰 DB(일간/십신/오행 +
  // 세운/월운/일운/개운아이템/궁합)를 앱 부팅 시점에 fire-and-forget으로
  // 미리 로드해 둔다. await 하지 않는 이유: 이 로드가 끝나기 전에
  // JeontongReportBuilder.build()가 호출돼도 기존 폴백(결정론적 시드
  // 기반) 경로로 안전하게 동작하므로 앱 시작을 블로킹할 필요가 없다 —
  // 로드가 끝나는 즉시(보통 앱 시작 후 수백ms 이내) 이후 호출부터 자동으로
  // 실계산 경로로 전환된다(jeontong_eighty_report_builder.dart 참고).
  SajuRules.preload();
  SajuFortuneRules.preload();
  runApp(const App());
}
