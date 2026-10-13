import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/pass/domain/pass_model.dart';
import 'package:flutter_app/features/pass/domain/open_pass_models.dart';
import 'package:flutter_app/core/domain/assets/open_pass_state.dart';

void main() {
  test('횟수제 응답은 잔여 횟수를 보존하고 시간 대신 횟수를 표시한다', () {
    final model = PassStatusModel.fromJson({'isActive': true, 'remainingCount': 3, 'hasLegacyUnlimited': false, 'expiresAt': DateTime.now().add(const Duration(days: 36500)).toIso8601String()});
    final state = OpenPassState.fromModel(model);
    expect(model.remainingCount, 3);
    expect(state.isActive, isTrue);
    expect(state.remainingLabel, '3회 남음');
    expect(state.remaining, Duration.zero);
  });
  test('0회는 미래 만료시각이어도 활성으로 표시하지 않는다', () {
    final model = PassStatusModel(isActive: true, remainingCount: 0, expiresAt: DateTime.now().add(const Duration(days: 36500)));
    expect(OpenPassState.fromModel(model).isActive, isFalse);
  });
  test('만료된 횟수제 이용권은 활성으로 표시하지 않는다', () {
    final model = PassStatusModel(isActive: true, remainingCount: 2, expiresAt: DateTime.now().subtract(const Duration(seconds: 1)));
    expect(OpenPassState.fromModel(model).isActive, isFalse);
  });
  test('이전 서버 시간제 응답은 하위호환한다', () {
    final model = PassStatusModel.fromJson({'isActive': true, 'remainingSec': 3600});
    expect(model.remainingCount, isNull);
    expect(OpenPassState.fromModel(model).remainingLabel, '1시간 0분 남음');
  });
  test('기존 시간제와 횟수제 동시 보유를 구분한다', () {
    final model = PassStatusModel.fromJson({'isActive': true, 'remainingCount': 2, 'hasLegacyUnlimited': true, 'remainingSec': 3600});
    expect(OpenPassState.fromModel(model).remainingLabel, '기존 시간제 이용권 보유 · 2회 남음');
  });
  test('보상 응답의 잔여 횟수를 누락하지 않는다', () {
    final grant = OpenPassRewardGrantModel.fromJson({'userPassId': 1, 'policyId': 2, 'expiresAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(), 'remainingCount': 4});
    expect(grant.remainingCount, 4);
  });
  test('비활성 응답은 이용권 없음으로 표시한다', () {
    expect(OpenPassState.fromModel(PassStatusModel.fromJson({'isActive': false, 'remainingCount': 0})).isActive, isFalse);
  });
}
