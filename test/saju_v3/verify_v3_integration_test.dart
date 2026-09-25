// [검증 스크립트 - 완료 보고서 근거] 실서버(localhost:8000) 대상 Option 2 재작성
// 클라이언트(SajuV3Api)의 검증 기준 1~4 확인용. flutter_test 하네스로 실행해
// dart:ui 의존성 문제 없이 flutter_app 패키지 코드를 그대로 사용한다.
//
// 실행: flutter test test/saju_v3/verify_v3_integration_test.dart
// 사전조건: 로컬 8000포트에 saju_engine이 기동 중이어야 한다(개발 검증 전용,
// 이 파일은 프로덕션 코드에 포함되지 않으며 baseUrl은 테스트 내부에서만 사용).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/fortune/saju_v3/data/saju_v3_api.dart';
import 'package:flutter_app/features/fortune/saju_v3/domain/birth_input.dart';

const token = 'STB-1234567890123456789012345678901234567890';

void main() {
  test('검증기준 2·3·4 - 실서버 대조 (localhost:8000, 개발 전용)', () async {
    final api = SajuV3Api(
      baseUrl: 'http://localhost:8000',
      freePassProvider: () => token,
    );

    // ── 검증기준 2: 박주상 샘플 facts 대조 ──
    const birth = BirthInput(
      name: '박주상',
      year: 1972,
      month: 2,
      day: 13,
      hour: 2,
      minute: 0,
      gender: 'male',
      isLunar: false,
    );
    final facts = await api.getSajuV3Facts(birth);
    // ignore: avoid_print
    print('=== 검증기준2: facts ===');
    // ignore: avoid_print
    print('연주: ${facts.year.gan}${facts.year.zhi} (${facts.year.kr})');
    // ignore: avoid_print
    print('월주: ${facts.month.gan}${facts.month.zhi} (${facts.month.kr})');
    // ignore: avoid_print
    print('일주: ${facts.day.gan}${facts.day.zhi} (${facts.day.kr})');
    // ignore: avoid_print
    print('시주: ${facts.hour.gan}${facts.hour.zhi} (${facts.hour.kr})');
    // ignore: avoid_print
    print('신강약: ${facts.strength.verdict} ${facts.strength.score}점');

    final expectedPillars = ['壬子', '壬寅', '甲戌', '乙丑'];
    final actualPillars = [
      '${facts.year.gan}${facts.year.zhi}',
      '${facts.month.gan}${facts.month.zhi}',
      '${facts.day.gan}${facts.day.zhi}',
      '${facts.hour.gan}${facts.hour.zhi}',
    ];
    expect(actualPillars, expectedPillars, reason: '팔자(4주) 일치');
    expect(facts.strength.score, 77, reason: '신강 77점 일치');

    // ── 검증기준 3: 69종 화면 실계산값 표시 (A03 예시) ──
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('=== 검증기준3: categories69 (A03) ===');
    final all69 = await api.getSajuV3Categories69(birth);
    final a03 = all69.items['A03'];
    expect(a03, isNotNull, reason: 'A03 카테고리 결과 존재');
    expect(a03!.hasError, isFalse, reason: 'A03 실계산 성공(스텁 아님)');
    expect(a03.data, isNotEmpty, reason: 'A03 data 비어있지 않음(실계산값)');
    // ignore: avoid_print
    print('A03 코드: ${a03.code}, 이름: ${a03.name}');
    // ignore: avoid_print
    print('A03 data (일부): ${jsonEncode(a03.data).substring(0, 200)}');
    // ignore: avoid_print
    print('총 카테고리 수: ${all69.items.length}, 오류 수: ${all69.errorCount}');
    expect(all69.items.length, 69, reason: '69종 전체 반환');
    expect(all69.errorCount, 0, reason: '스텁/오류 0건');

    // ── /saju/v3/interpret 확인 (3차 회신에서 신규 구현된 라우트) ──
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('=== /saju/v3/interpret 확인 ===');
    final interpret = await api.getSajuV3Interpret(birth, categoryCode: 'B01');
    // ignore: avoid_print
    print('source: ${interpret.source}, isFallback: ${interpret.isFallback}');
    // ignore: avoid_print
    print('headline: ${interpret.headline}');
    expect(interpret.source, 'rule_fallback', reason: 'LLM 미연결 - 룰 폴백 정상');
    expect(interpret.isFallback, isTrue);
    expect(interpret.headline, isNotEmpty);

    // ── 검증기준 4: 서버 미기동 상태에서 크래시 없이 오류만 표시 ──
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('=== 검증기준4: 서버 다운 시 안전 처리 ===');
    final downApi = SajuV3Api(
      baseUrl: 'http://localhost:19999', // 존재하지 않는 포트(서버 다운 시뮬레이션)
      freePassProvider: () => token,
      timeout: const Duration(seconds: 3),
    );
    Object? caught;
    try {
      await downApi.getCategoriesV3();
    } catch (e) {
      caught = e;
    }
    expect(
      caught,
      isA<SajuV3ApiException>(),
      reason: '서버 다운 시 SajuV3ApiException으로만 표면화되어야 함(크래시 없음)',
    );
    // ignore: avoid_print
    print('정상: SajuV3ApiException 캐치됨 -> $caught');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
