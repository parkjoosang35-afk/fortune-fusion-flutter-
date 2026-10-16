import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_core_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';

/// [Task 10 항목1/2 — 로컬 엔진 ↔ 서버(FACT) 엔진 교차검증]
///
/// "앱 내부 엔진과 서버 엔진에 동일한 생년월일시를 입력하여 사주 원국,
/// 오행 등 핵심 계산 결과가 정확히 일치하는지 교차검증 테스트를 만들어
/// 주세요." / "계산 결과가 다르면 임의로 수정하지 말고, 어떤 항목에서
/// 왜 다른지 원인을 찾아 보고해 주세요."
///
/// [이 테스트가 실제로 하는 일]
/// - 로컬: `ManseryeokCoreEngine.calculatePillars()` (PHASE1, `lunar`
///   패키지 기반) — 02/03/04/05/07 화면이 쓰는 것과 동일한 함수.
/// - 서버: 샌드박스에 떠 있는 라이브 FACT 엔진
///   `POST http://127.0.0.1:8000/saju/v3/facts` (관리자 웹
///   `saju-engine-client.ts`가 운영에서 호출하는 것과 동일한 엔드포인트).
/// - 둘에 "완전히 동일한" 생년월일시를 넣고 연/월/일/시 4주(八字)의
///   천간·지지를 1글자 단위로 비교한다.
///
/// [절대 원칙 — 결과가 다르면 수정하지 않고 "왜 다른지"만 기록한다]
/// 심층 조사 결과, 로컬 엔진과 서버 엔진은 설계 당시부터 이미 분기된
/// 두 지점이 있다(아래 각 그룹 주석 참고). 이 테스트는 그 분기 지점을
/// **숨기지 않고 그대로 드러내는** 것이 목적이므로, "서로 다른 결과가
/// 나오는 입력"에 대해서는 테스트가 실패하는 대신 그 결과를 그대로
/// 캡처해 원인 주석과 함께 `expect`로 "왜 다른지"를 문서화한다(= 거짓
/// 통과를 만들지 않는다. docs "실패를 Mock으로 숨기지 않는다" 원칙).
///
/// [서버 미기동 시 자동 skip] 이 테스트는 외부(사실은 같은 샌드박스
/// 내부) 네트워크 서비스에 의존한다. CI/다른 환경에서 서버가 떠있지
/// 않으면 테스트 자체를 깨뜨리지 않고 명확히 skip 처리한다 — "실패를
/// 숨기는 것"과 "환경이 달라 검증 불가함을 명시하는 것"은 다르다.
void main() {
  const serverBase = 'http://127.0.0.1:8000';
  const freePassToken = 'STB-internal-crossvalidation-00000000000000';

  Future<Map<String, dynamic>?> fetchServerFacts({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required String gender,
    required bool isLunar,
    String zihourPolicy = 'traditional',
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final req = await client.postUrl(
        Uri.parse('$serverBase/saju/v3/facts'),
      );
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('X-Free-Pass', freePassToken);
      req.write(
        jsonEncode({
          'year': year,
          'month': month,
          'day': day,
          'hour': hour,
          'minute': minute,
          'gender': gender,
          'is_lunar': isLunar,
          'zihour_policy': zihourPolicy,
        }),
      );
      final res = await req.close().timeout(const Duration(seconds: 5));
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) return null;
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  ManseryeokCoreResult localPillars({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
  }) {
    return ManseryeokCoreEngine.calculatePillars(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      calendarType: CalendarInputType.solar,
    );
  }

  group('[정상 범위] 서버 기본 보정이 로컬과 사실상 차이를 만들지 않는 '
      '입력 — 여기서는 일치해야 한다', () {
    // [선정 근거] 진태양시(-32분) 보정은 "시(時) 경계"를 넘나들 때만
    // 결과에 영향을 준다(2시간 단위 시지 블록의 중간 시각이면 -32분을
    // 적용해도 같은 시지 블록 안에 머문다). 아래는 정시(0분)로 입력해
    // 그 경계 위험을 피한 안전한 샘플들이다. 자시(23:00~00:59) 부근도
    // 피했다(자시 정책 기본값 자체가 로컬·서버 간 다르므로 — 아래
    // group 참고).
    for (final c in [
      (1990, 5, 15, 14, '성인 평시간대(14시 정각)'),
      (2000, 1, 1, 10, 'Y2K 당일 오전'),
      (1985, 8, 20, 6, '아침 6시(묘시 중반)'),
    ]) {
      test('${c.$1}-${c.$2}-${c.$3} ${c.$4}시 — ${c.$5}', () async {
        final server = await fetchServerFacts(
          year: c.$1,
          month: c.$2,
          day: c.$3,
          hour: c.$4,
          minute: 0,
          gender: 'male',
          isLunar: false,
        );
        if (server == null) {
          markTestSkipped('서버(127.0.0.1:8000)에 연결할 수 없어 교차검증을 '
              '건너뜀 — 이 샌드박스에서는 FACT 엔진이 떠있을 때만 실행된다.');
          return;
        }
        final local = localPillars(
          year: c.$1,
          month: c.$2,
          day: c.$3,
          hour: c.$4,
          minute: 0,
        );
        final sp = server['pillars'] as Map<String, dynamic>;
        expect(
          local.yearPillar.stemHanja,
          sp['year']['gan'],
          reason: '년주 천간',
        );
        expect(
          local.yearPillar.branchHanja,
          sp['year']['zhi'],
          reason: '년주 지지',
        );
        expect(
          local.monthPillar.stemHanja,
          sp['month']['gan'],
          reason: '월주 천간',
        );
        expect(
          local.monthPillar.branchHanja,
          sp['month']['zhi'],
          reason: '월주 지지',
        );
        expect(
          local.dayPillar.stemHanja,
          sp['day']['gan'],
          reason: '일주 천간',
        );
        expect(
          local.dayPillar.branchHanja,
          sp['day']['zhi'],
          reason: '일주 지지',
        );
        expect(
          local.hourPillar.stemHanja,
          sp['hour']['gan'],
          reason: '시주 천간',
        );
        expect(
          local.hourPillar.branchHanja,
          sp['hour']['zhi'],
          reason: '시주 지지',
        );
      });
    }
  });

  group('[원인 확인 — 진태양시(眞太陽時) 보정 차이] 서버는 기본값 '
      'true_solar=True로 서울 경도(126.98°) 기준 -32분을 적용하지만, '
      '로컬 ManseryeokCoreEngine은 이 보정을 아예 적용하지 않는다 '
      '(manseryeok_policy.dart 자체 문서: "이번 Phase 1에서는 적용하지 '
      '않는다"). 시(時) 경계 부근 입력에서 시주가 달라지는 것이 "버그"가 '
      '아니라 "설계상 알려진 차이"임을 여기서 재현해 문서화한다', () {
    test('1990-05-15 13:15 — 시지 경계 부근(서버 -32분 보정 시 12:43 → '
        '오전 11~13시 블록 경계를 넘어갈 수 있음)', () async {
      final server = await fetchServerFacts(
        year: 1990,
        month: 5,
        day: 15,
        hour: 13,
        minute: 15,
        gender: 'male',
        isLunar: false,
      );
      if (server == null) {
        markTestSkipped('서버 미기동 — 교차검증 환경에서만 실행됨');
        return;
      }
      final local = localPillars(year: 1990, month: 5, day: 15, hour: 13, minute: 15);
      final sp = server['pillars'] as Map<String, dynamic>;
      final serverHour = '${sp['hour']['gan']}${sp['hour']['zhi']}';
      final localHour = '${local.hourPillar.stemHanja}${local.hourPillar.branchHanja}';
      // [중요] 여기서는 "같아야 한다"고 assert하지 않는다 — 실제로
      // 다르다는 사실 자체가 조사 결과이며, 이 테스트의 가치는 그
      // 차이를 재현 가능한 형태로 고정해 향후 회귀 감시에 쓰는 데 있다.
      // (현재 재현값: 서버=壬午, 로컬=癸未 — 진태양시 보정 유무 때문)
      expect(
        serverHour != localHour,
        isTrue,
        reason:
            '[알려진 원인] 서버 true_solar 보정(-32분, saju_facts.py '
            'apply_true_solar)이 시지 경계를 넘겨 시주를 바꾸지만 로컬 '
            'ManseryeokCoreEngine은 보정을 적용하지 않는다. 서버=$serverHour, '
            '로컬=$localHour. 두 값이 같아지면(=서버가 true_solar 기본값을'
            ' 바꿨거나 로컬이 보정을 추가한 경우) 이 assert가 깨지므로 '
            '설계가 바뀐 시점을 즉시 감지할 수 있다.',
      );
    });
  });

  group('[원인 확인 — 자시(子時) 정책 기본값 차이] 서버 '
      'calculate_saju()의 기본값은 zihour_policy="traditional"→'
      'setSect(1)(23:00~23:59를 다음날로 산입)이고, 로컬 '
      'ZiHourPolicy의 프로젝트 기본값은 lateZiSameDay(=sect2, 당일 '
      '산입)다. 이 차이는 일주(day pillar)까지 바꿀 수 있다', () {
    test('1990-05-15 23:50 — 야자시(晚子時) 경계', () async {
      final server = await fetchServerFacts(
        year: 1990,
        month: 5,
        day: 15,
        hour: 23,
        minute: 50,
        gender: 'male',
        isLunar: false,
        zihourPolicy: 'traditional', // 서버 기본값(= setSect(1))
      );
      if (server == null) {
        markTestSkipped('서버 미기동 — 교차검증 환경에서만 실행됨');
        return;
      }
      // 로컬 프로젝트 기본 정책(lateZiSameDay=sect2)으로 계산.
      final local = ManseryeokCoreEngine.calculatePillars(
        year: 1990,
        month: 5,
        day: 15,
        hour: 23,
        minute: 50,
        calendarType: CalendarInputType.solar,
        ziHourPolicy: ZiHourPolicy.lateZiSameDay,
      );
      final sp = server['pillars'] as Map<String, dynamic>;
      final serverDay = '${sp['day']['gan']}${sp['day']['zhi']}';
      final localDay = '${local.dayPillar.stemHanja}${local.dayPillar.branchHanja}';
      expect(
        serverDay != localDay,
        isTrue,
        reason:
            '[알려진 원인] 서버 기본 자시 정책(traditional=sect1, 야자시를 '
            '다음날로 산입)과 로컬 프로젝트 기본값(lateZiSameDay=sect2, '
            '당일 산입)이 다르다. 서버=$serverDay, 로컬=$localDay. 로컬 '
            '엔진에 ZiHourPolicy.lateZiNextDay(sect1)를 명시적으로 넘기면 '
            '서버와 같은 값이 나오는지는 별도로 확인 가능(아래 테스트 참고).',
      );

      // [보충 확인] 로컬 정책을 서버와 동일한 sect1로 바꿔 넘기면
      // 실제로 서버와 같은 결과가 나오는지 — "자시 정책 차이"가 원인의
      // 전부임을 한번 더 교차 확인한다(다른 숨은 차이가 없는지 검증).
      final localSect1 = ManseryeokCoreEngine.calculatePillars(
        year: 1990,
        month: 5,
        day: 15,
        hour: 23,
        minute: 50,
        calendarType: CalendarInputType.solar,
        ziHourPolicy: ZiHourPolicy.lateZiNextDay,
      );
      final localSect1Day =
          '${localSect1.dayPillar.stemHanja}${localSect1.dayPillar.branchHanja}';
      expect(
        localSect1Day,
        serverDay,
        reason:
            '로컬 엔진에 서버와 동일한 자시 정책(sect1=lateZiNextDay)을 '
            '명시하면 서버와 일주가 일치해야 한다 — 일치하지 않으면 '
            '자시 정책 외의 추가 분기 원인이 있다는 뜻이므로 재조사가 '
            '필요하다.',
      );
    });
  });
}
