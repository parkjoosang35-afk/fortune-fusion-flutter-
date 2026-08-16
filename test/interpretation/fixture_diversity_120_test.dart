/// [정통사주 69종 개인화 해석 엔진 — A01/A03 100명 이상 검증, 0단계]
/// 120명 픽스처(`jeontong_sample_120.dart`) 자체의 다양성 사전 검증.
///
/// 사용자 지시 §1 "최소 100명 이상, 남녀/다양한 연령/출생년도/월/일간/
/// 시주/신강/신약/중화/재성강약/오행편중/오행균형/용신차이/대운흐름차이를
/// 골고루 포함"이 실제로 만족되는지, 뒤따르는 TEST1~3을 작성하기 전에
/// 먼저 확인한다. 이 테스트가 실패하면 픽스처 생성 공식(step 값)을
/// 조정해야 한다 — PHASE1~4 계산 로직이 아니라 "입력값 분산"만 바꾼다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final refDate = DateTime.utc(2026, 8, 13);

  test('120명 입력은 전원 서로 다른 (생년월일시,성별) 조합이다', () {
    final seen = <String>{};
    for (final input in kJeontongSample120) {
      seen.add('${input.birthDateTimeUtc.toIso8601String()}|${input.gender}');
    }
    expect(seen.length, equals(kJeontongSample120.length));
    expect(kJeontongSample120.length, greaterThanOrEqualTo(100));
  });

  test('120명 입력에 남/여가 골고루 섞여 있다', () {
    final m = kJeontongSample120.where((e) => e.gender == 'M').length;
    final f = kJeontongSample120.where((e) => e.gender == 'F').length;
    // ignore: avoid_print
    print('gender: M=$m, F=$f');
    expect(m, greaterThan(0));
    expect(f, greaterThan(0));
  });

  test('120명 계산 결과: 일간·신강신약·용신·오행편중이 다양하게 분포한다', () {
    final dayGans = <String, int>{};
    final strengthVerdicts = <String, int>{};
    final yongsinElements = <String, int>{};
    final imbalanced = <bool, int>{};

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final p = built.profile;

      final gan = p.dayPillar.stemHanja;
      dayGans[gan] = (dayGans[gan] ?? 0) + 1;

      final verdict = p.strength?.verdict ?? '(none)';
      strengthVerdicts[verdict] = (strengthVerdicts[verdict] ?? 0) + 1;

      final yongsin = p.yongsin?.yongsin ?? '(none)';
      yongsinElements[yongsin] = (yongsinElements[yongsin] ?? 0) + 1;

      final isImb = p.fiveElements?.isImbalanced ?? false;
      imbalanced[isImb] = (imbalanced[isImb] ?? 0) + 1;
    }

    // ignore: avoid_print
    print('일간 분포(${dayGans.length}종): $dayGans');
    // ignore: avoid_print
    print('신강신약 분포: $strengthVerdicts');
    // ignore: avoid_print
    print('용신 오행 분포: $yongsinElements');
    // ignore: avoid_print
    print('오행편중 여부 분포: $imbalanced');

    // 10천간 중 최소 절반 이상 등장해야 "일간이 다양하다"고 볼 수 있다.
    expect(dayGans.length, greaterThanOrEqualTo(5),
        reason: '일간 종류가 너무 적으면 입력 분산 공식을 재조정해야 함');

    // 신강/신약/중화 세 종류가 모두 나와야 한다.
    expect(strengthVerdicts.keys.toSet(),
        containsAll(<String>{'신강', '신약', '중화'}),
        reason: '신강/신약/중화가 모두 존재해야 §1 요구 충족');

    // 용신 오행도 여러 종류(목화토금수 중 다수)가 나와야 한다.
    expect(yongsinElements.length, greaterThanOrEqualTo(3),
        reason: '용신 오행이 지나치게 편중되면 개인화 검증 표본으로 부적합');

    // 오행 편중/균형 둘 다 존재해야 한다.
    expect(imbalanced.keys.toSet(), containsAll(<bool>{true, false}),
        reason: '오행편중/오행균형 사주가 모두 있어야 §1 요구 충족');
  });
}
