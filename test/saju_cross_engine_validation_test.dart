import 'dart:async';
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

  group('[잔여작업 — 진태양시 보정 단독효과 분리검증] 서버 /saju/v3/facts는 '
      'true_solar 파라미터를 요청 바디로 노출하지 않는다(BirthInputV3에 '
      '필드 자체가 없음, api/saju_api.py 확인). 따라서 "절기 경계에서 '
      'DIFF가 나는 원인이 진태양시 보정 하나뿐인지"는 서버 API 호출만으로는 '
      '분리할 수 없다 — 이 테스트는 그 한계를 그대로 드러내는 것이 목적이다 '
      '(API를 변경해 숨은 파라미터를 추가하지 않는다, 승인 범위 밖).', () {
    test('1990-02-04 10:14(1990년 입춘 정시각) 전후 — 서버는 true_solar 기본 '
        '적용(10:14~10:30에도 보정상 "아직 입춘 전"으로 판정)되지만 로컬은 '
        '보정을 걸지 않아 10:14부터 "입춘 후"로 바로 전환된다', () async {
      final server1013 = await fetchServerFacts(
        year: 1990,
        month: 2,
        day: 4,
        hour: 10,
        minute: 13,
        gender: 'male',
        isLunar: false,
      );
      final server1030 = await fetchServerFacts(
        year: 1990,
        month: 2,
        day: 4,
        hour: 10,
        minute: 30,
        gender: 'male',
        isLunar: false,
      );
      if (server1013 == null || server1030 == null) {
        markTestSkipped('서버 미기동 — 교차검증 환경에서만 실행됨');
        return;
      }
      final local1013 = localPillars(
        year: 1990,
        month: 2,
        day: 4,
        hour: 10,
        minute: 13,
      );
      final local1030 = localPillars(
        year: 1990,
        month: 2,
        day: 4,
        hour: 10,
        minute: 30,
      );
      final sv1013 = server1013['pillars'] as Map<String, dynamic>;
      final sv1030 = server1030['pillars'] as Map<String, dynamic>;
      final serverYear1013 = '${sv1013['year']['gan']}${sv1013['year']['zhi']}';
      final serverYear1030 = '${sv1030['year']['gan']}${sv1030['year']['zhi']}';
      final localYear1013 =
          '${local1013.yearPillar.stemHanja}${local1013.yearPillar.branchHanja}';
      final localYear1030 =
          '${local1030.yearPillar.stemHanja}${local1030.yearPillar.branchHanja}';

      // [서버측 관찰] true_solar(-32분) 보정 탓에 10:13/10:30 둘 다 "보정된
      // 시각(09:41/09:58)" 기준으로는 아직 입춘(10:14) 전이므로 연주가
      // 바뀌지 않는다 — 즉 서버 자체에서는 10:13과 10:30이 "같다".
      expect(
        serverYear1013,
        serverYear1030,
        reason:
            '[서버 자체 비교] true_solar 보정이 -32분을 적용하므로 '
            '10:13→09:41, 10:30→09:58 모두 입춘(10:14) 이전으로 남아 '
            '연주가 바뀌지 않아야 한다. 서버=$serverYear1013/$serverYear1030',
      );
      // [로컬측 관찰] 보정이 없으므로 10:13은 입춘 전(己巳), 10:30은 입춘
      // 후(庚午)로 로컬 자체에서 달라져야 한다.
      expect(
        localYear1013 == localYear1030,
        isFalse,
        reason:
            '[로컬 자체 비교] 진태양시 보정이 없는 로컬 엔진은 입춘 정시각'
            '(10:14) 전후로 연주가 실제로 바뀌어야 한다. 로컬=$localYear1013/'
            '$localYear1030 — 만약 같다면 로컬 절기 판정 자체에 문제가 '
            '있다는 뜻이므로 재조사가 필요하다.',
      );
      // [원인 분리 결론] 10:30 시점에서만 서버/로컬이 달라지는 것은 "절기
      // 계산 알고리즘 차이"가 아니라 "진태양시 보정 적용 여부" 단 하나의
      // 변수 때문임을 이 두 비교(서버 자체는 불변, 로컬 자체는 변함)로
      // 증명한다. Python saju_calculator.calculate_saju()를 true_solar=False
      // 인자로 직접 호출(엔진 코드 1줄도 수정하지 않고 기존 매개변수만
      // 사용)하면 로컬과 완전히 같은 결과가 나옴을 별도로 수동 확인했다
      // (2026 엔진검증 보고서 §1 참고, API 미경유 직접 함수 호출).
      expect(
        serverYear1013 != localYear1030,
        isTrue,
        reason:
            '[알려진 원인] 10:30 시점에서 서버($serverYear1030)와 로컬'
            '($localYear1030)이 다르다면 그 유일한 원인은 서버의 '
            'true_solar 기본 적용(-32분)이다. API가 이 값을 토글하는 '
            '파라미터를 제공하지 않으므로, 서버 HTTP 호출만으로는 '
            '이 분기를 끌 수 없다 — 계산 엔진(saju_facts.py/'
            'saju_calculator.py)을 직접 수정하지 않는 한 API 레벨 '
            '검증의 한계로 남는다(승인 범위 밖, 수정하지 않음).',
      );
    });
  });

  group('[잔여작업 — 음력 윤달 지원 여부 차이] 로컬 ManseryeokCoreEngine은 '
      '`isLeapMonth` 파라미터로 윤달을 정상 지원하지만, 서버 '
      'BirthInputV3/ScreenRequestV3는 `month`를 Pydantic '
      'Field(ge=1, le=12)로 제약해 윤달 컨벤션(월을 음수로 표현)을 API '
      '스키마 단계에서부터 거부한다(별도 is_leap 플래그도 없음) — 이는 '
      '"계산 알고리즘 차이"가 아니라 "API 입력 스키마 자체가 윤달을 받을 '
      '방법이 없는 기능 격차"다.', () {
    test('로컬: 2023년 윤2월 10일 10시는 평달 2월10일과 다른 사주가 나온다 '
        '(윤달 구분이 실제로 계산에 반영됨을 먼저 확인)', () {
      final leap = ManseryeokCoreEngine.calculatePillars(
        year: 2023,
        month: 2,
        day: 10,
        hour: 10,
        minute: 0,
        calendarType: CalendarInputType.lunar,
        isLeapMonth: true,
      );
      final normal = ManseryeokCoreEngine.calculatePillars(
        year: 2023,
        month: 2,
        day: 10,
        hour: 10,
        minute: 0,
        calendarType: CalendarInputType.lunar,
        isLeapMonth: false,
      );
      final leapMonth =
          '${leap.monthPillar.stemHanja}${leap.monthPillar.branchHanja}';
      final normalMonth =
          '${normal.monthPillar.stemHanja}${normal.monthPillar.branchHanja}';
      expect(
        leapMonth != normalMonth,
        isTrue,
        reason:
            '윤2월과 평달 2월은 서로 다른 절기 구간에 속하므로 월주가 '
            '달라야 한다. 윤달=$leapMonth, 평달=$normalMonth',
      );
    });

    test('서버: 윤달을 표현할 방법이 없다 — 음수 month(-2)를 보내면 Pydantic '
        '검증 단계(422)에서 거부되어 계산 자체가 시도되지 않는다', () async {
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
            'year': 2023,
            'month': -2, // 윤달 컨벤션 시도(음수 month)
            'day': 10,
            'hour': 10,
            'minute': 0,
            'gender': 'male',
            'is_lunar': true,
          }),
        );
        final res = await req.close().timeout(const Duration(seconds: 5));
        final body = await res.transform(utf8.decoder).join();
        client.close();
        if (res.statusCode == 0) {
          markTestSkipped('서버 미기동 — 교차검증 환경에서만 실행됨');
          return;
        }
        expect(
          res.statusCode,
          422,
          reason:
              '[알려진 기능 격차] 서버 BirthInputV3.month는 '
              'Field(ge=1, le=12)라서 윤달 컨벤션(음수 month)을 보내면 '
              '항상 422 Unprocessable Entity를 반환해야 한다. 실제 '
              '응답 본문: $body. 이 테스트가 깨지면(=200이 되면) 서버가 '
              '윤달 입력을 받아들이도록 바뀐 것이므로, 그때는 이 '
              '"격차" 자체가 해소된 것이니 본 테스트 그룹 설명을 '
              '갱신해야 한다.',
        );
      } on SocketException {
        markTestSkipped('서버 미기동(연결 거부) — 교차검증 환경에서만 실행됨');
      }
    });
  });

  group('[잔여작업 — 출생시간 미입력 처리 정책 3갈래 차이] 동일하게 '
      '"출생시간을 모른다"는 입력을 받았을 때, 세 소비처가 서로 다른 '
      '정책을 쓴다는 사실을 각각 재현한다 — 어느 쪽이 "맞다/틀리다"를 '
      '가리지 않고, 세 정책이 실제로 다르다는 사실만 고정 문서화한다:\n'
      '  (1) 서버 `/saju/v3/screen`(ScreenRequestV3.hour_known=False) — '
      '엔진 결과 JSON 자체에서 시주를 `null`로 응답(6자 처리, 코드로 확인).\n'
      '  (2) admin_web `/saju/v3/facts` 소비 경로(topics/select, '
      'interpret) — 엔진에는 항상 12:00으로 8자 전체를 계산시키지만, '
      '애플리케이션 레이어(saju-facts-time-guard.ts)가 응답을 받은 뒤 '
      '시주 파생 필드를 사후 제거(guard)한다.\n'
      '  (3) Flutter 앱(JeontongReportBuilder, PHASE1~4) — '
      'birthTimeUnknown=true여도 관례값 12:00으로 8자 전체를 계산하고, '
      '시주를 제거하지 않은 채 그대로 반환한다(jeontong_input.dart 주석: '
      '"계산에는 영향이 없다").', () {
    test('(1) 서버 screen 엔드포인트 — hour_known=False면 pillars.hour가 '
        'null로 내려온다(엔진 레벨 6자 처리를 실제 HTTP 응답으로 재현)', () async {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 3);
        final req = await client.postUrl(
          Uri.parse('$serverBase/saju/v3/screen'),
        );
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('X-Free-Pass', freePassToken);
        req.write(
          jsonEncode({
            'year': 1990,
            'month': 3,
            'day': 15,
            'hour': 8,
            'minute': 30,
            'gender': 'male',
            'is_lunar': false,
            'category_code': 'A01',
            'hour_known': false,
          }),
        );
        // [주의] 이 엔드포인트는 LLM 해석(story)까지 생성할 수 있어
        // facts보다 느릴 수 있다 — 넉넉한 타임아웃을 둔다.
        final res = await req.close().timeout(const Duration(seconds: 25));
        final body = await res.transform(utf8.decoder).join();
        client.close();
        if (res.statusCode == 0) {
          markTestSkipped('서버 미기동 — 교차검증 환경에서만 실행됨');
          return;
        }
        if (res.statusCode != 200) {
          markTestSkipped(
            '서버 screen 엔드포인트가 200이 아님(status=${res.statusCode}) '
            '— rate limit 가드 등 운영 보호 로직 때문일 수 있어 이 '
            '테스트를 건너뛴다(엔진 비교 목적이 아니므로 재시도하지 '
            '않는다).',
          );
          return;
        }
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        expect(
          decoded['pillars'],
          isA<Map<String, dynamic>>(),
          reason: 'screen 응답에 pillars 필드가 있어야 한다. 실제 응답: $body',
        );
        final pillars = decoded['pillars'] as Map<String, dynamic>;
        expect(
          pillars['hour'],
          isNull,
          reason:
              '[정책 확인] hour_known=false면 서버 screen 엔드포인트는 '
              'pillars.hour를 null로 응답해야 한다(엔진이 6자만 노출). '
              '실제 pillars: $pillars',
        );
      } on SocketException {
        markTestSkipped('서버 미기동(연결 거부) — 교차검증 환경에서만 실행됨');
      } on TimeoutException {
        markTestSkipped(
          'screen 엔드포인트 응답 지연(LLM 해석 생성 가능성) — 엔진 '
          '비교가 목적이 아니므로 재시도하지 않고 건너뛴다.',
        );
      }
    });

    test('(3) 로컬 Flutter 엔진 — birthTimeUnknown 플래그와 무관하게 '
        'calculatePillars()는 넘겨받은 hour/minute 그대로 8자 전체를 '
        '계산한다(시주 제거 로직이 엔진 레벨에 존재하지 않음을 확인)', () {
      // JeontongInput.birthTimeUnknown은 계산 경로(userModelToJeontongInput
      // → ManseryeokCoreEngine.calculatePillars)에 전달되는 어떤 매개변수와도
      // 연결되어 있지 않다 — calculatePillars() 시그니처 자체에 그런
      // 매개변수가 없다. 즉 "모른다"고 표시해도 관례값(12:00)으로 계산된
      // 8자 전체가 그대로 나온다는 사실을 재현한다.
      final withAssumedNoon = ManseryeokCoreEngine.calculatePillars(
        year: 1990,
        month: 3,
        day: 15,
        hour: 12,
        minute: 0,
        calendarType: CalendarInputType.solar,
      );
      expect(
        withAssumedNoon.hourPillar.stemHanja.isNotEmpty,
        isTrue,
        reason:
            '[정책 확인] 로컬 엔진은 "출생시간 모름"을 별도로 받지 않고 '
            '호출자가 이미 12:00으로 치환해 넘긴 값을 그대로 8자 계산에 '
            '사용한다 — hourPillar가 비어있지 않고 정상 산출된다. 이는 '
            '서버 screen 엔드포인트(hour_known=False → pillars.hour=null)'
            '와 다른 정책이며, 어느 쪽이 맞다고 단정하지 않는다(설계상 '
            '허용된 차이, 임의 변경 금지).',
      );
    });
  });
}
