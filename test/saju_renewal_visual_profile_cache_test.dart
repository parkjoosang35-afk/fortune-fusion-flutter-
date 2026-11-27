import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/auth/domain/user_model.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_visual_adapter.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// [Task 10 항목3 검증] "앱에서 동일한 사주를 화면 이동 때마다 반복 계산하는
/// 부분은 기존 계산 로직을 변경하지 않고, 한 번 계산한 결과를 재사용하도록
/// 개선해 주세요."
///
/// [검증 범위 — 계산 로직 불변성] 이 테스트는 [SajuVisualAdapter.build]가
/// 계산한 "값"이 몇 번을 다시 계산해도 동일함을 전제로, 03→04→05→07에
/// 해당하는 각 화면이 실제로 호출하는 진입점
/// [SajuRenewalProvider.visualProfileFor]가
/// 1) 동일 출생정보로는 매번 **동일한 객체 인스턴스**(=캐시 히트, 재계산
///    없음)를 돌려주고,
/// 2) 출생정보가 달라지면 **새로 계산**하며,
/// 3) 로그아웃/새 분석 시작 시 캐시가 무효화됨을 보증한다.
///
/// [계산 로직 자체는 테스트하지 않음] 8글자/오행 등 실제 계산값의 정확성은
/// `jeontong_eighty_golden_test.dart` 등 기존 골든 테스트와 이번 교차검증
/// 테스트(`saju_cross_engine_validation_test.dart`)의 책임이다. 이 파일은
/// 오직 "몇 번 계산하는가"(호출 횟수/캐싱)만 검증한다.
void main() {
  UserModel user({
    String birthDate = '1990-05-15',
    String? birthTime = '14:30',
    bool isLunar = false,
    bool birthTimeUnknown = false,
    String gender = 'male',
  }) => UserModel(
    id: 'u1',
    nickname: '테스트',
    birthDate: birthDate,
    birthTime: birthTime,
    isLunar: isLunar,
    birthTimeUnknown: birthTimeUnknown,
    gender: gender,
    grade: 'normal',
  );

  test('동일 출생정보로 반복 호출해도 계산은 1회만 수행되고(동일 인스턴스 '
      '재사용) 02~07 화면이 받는 값은 모두 같다', () {
    final provider = SajuRenewalProvider(SajuRenewalApi());
    final u = user();

    final p1 = provider.visualProfileFor(u); // 화면③(계산중) 상당
    final p2 = provider.visualProfileFor(u); // 화면④(분석완료) 상당
    final p3 = provider.visualProfileFor(u); // 화면⑤(미리보기) 상당
    final p4 = provider.visualProfileFor(u); // 화면⑦(상세) 상당

    expect(p1, isNotNull);
    // [핵심 검증] 4번의 호출이 모두 "같은 객체"를 반환해야만 실제로
    // 재계산이 일어나지 않았다고 확신할 수 있다(값만 같고 매번 새
    // 객체라면 재계산이 일어난 것 — identical()로 엄격히 검증).
    expect(identical(p1, p2), isTrue, reason: '04 화면 진입 시 재계산되면 안 됨');
    expect(identical(p1, p3), isTrue, reason: '05 화면 진입 시 재계산되면 안 됨');
    expect(identical(p1, p4), isTrue, reason: '07 화면 진입 시 재계산되면 안 됨');
  });

  test('직접 SajuVisualAdapter.build()로 계산한 값과 Provider 캐시 경유 '
      '값이 완전히 동일하다(=캐싱 래퍼가 계산 로직을 바꾸지 않았음을 보증)', () {
    final provider = SajuRenewalProvider(SajuRenewalApi());
    final u = user();

    final viaProvider = provider.visualProfileFor(u);
    final direct = SajuVisualAdapter.build(
      kst: DateTime(1990, 5, 15, 14, 0),
      gender: 'male',
      isLunar: false,
      timeUnknown: false,
      referenceDate: DateTime.now(),
      isLeapMonth: false,
    );

    expect(viaProvider, isNotNull);
    for (var i = 0; i < 4; i++) {
      expect(viaProvider!.pillars[i]?.stemHanja, direct.pillars[i]?.stemHanja);
      expect(
        viaProvider.pillars[i]?.branchHanja,
        direct.pillars[i]?.branchHanja,
      );
    }
    expect(viaProvider!.elementsWeighted, direct.elementsWeighted);
    expect(viaProvider.balanceLevel, direct.balanceLevel);
  });

  test('출생정보(생년월일)가 달라지면 캐시를 쓰지 않고 다시 계산한다', () {
    final provider = SajuRenewalProvider(SajuRenewalApi());
    final p1 = provider.visualProfileFor(user(birthDate: '1990-05-15'));
    final p2 = provider.visualProfileFor(user(birthDate: '1985-01-01'));

    expect(p1, isNotNull);
    expect(p2, isNotNull);
    expect(identical(p1, p2), isFalse);
    // 실제로 다른 날짜이므로 일주(day pillar) 간지 조합 전체가 달라야
    // 한다(천간만 보면 우연히 같은 글자가 나올 수 있어 지지까지 함께
    // 비교한다 — 생년월일이 다른데 결과가 완전히 같다면 캐시 키 설계
    // 결함).
    final day1 = '${p1!.pillars[1]?.stemHanja}${p1.pillars[1]?.branchHanja}';
    final day2 = '${p2!.pillars[1]?.stemHanja}${p2.pillars[1]?.branchHanja}';
    expect(day1, isNot(day2));
  });

  test('출생시간이 다르면(시주에 영향) 캐시를 쓰지 않고 다시 계산한다', () {
    final provider = SajuRenewalProvider(SajuRenewalApi());
    final p1 = provider.visualProfileFor(user(birthTime: '02:00'));
    final p2 = provider.visualProfileFor(user(birthTime: '14:30'));

    expect(identical(p1, p2), isFalse);
  });

  test('clearOnLogout() 호출 후에는 캐시가 무효화되어 다시 계산한다(계정 '
      '격리 — 사용자A의 계산 결과가 사용자B에게 재사용되면 안 됨)', () {
    final provider = SajuRenewalProvider(SajuRenewalApi());
    final u = user();
    final p1 = provider.visualProfileFor(u);
    provider.clearOnLogout();
    final p2 = provider.visualProfileFor(u);

    expect(identical(p1, p2), isFalse);
  });

  test('startNewAnalysis() 호출 후에는 캐시가 무효화되어 다시 계산한다('
      '출생정보를 다시 입력하는 흐름이므로 이전 값이 남아있으면 안 됨)', () {
    final provider = SajuRenewalProvider(SajuRenewalApi());
    final u = user();
    final p1 = provider.visualProfileFor(u);
    provider.startNewAnalysis();
    final p2 = provider.visualProfileFor(u);

    expect(identical(p1, p2), isFalse);
  });

  test('출생정보가 없는 사용자는 null을 반환하고 예외를 던지지 않는다', () {
    final provider = SajuRenewalProvider(SajuRenewalApi());
    final u = UserModel(
      id: 'u2',
      nickname: '정보없음',
      birthDate: null,
      grade: 'normal',
    );
    expect(provider.visualProfileFor(u), isNull);
    expect(provider.visualProfileFor(null), isNull);
  });
}
