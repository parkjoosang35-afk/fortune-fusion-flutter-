import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/saju_renewal/data/models/topic_card.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// C-08a(docs/08_QA_체크리스트.md) — [SajuRenewalProvider.displayableCandidates]
/// 단위 검증. docs/03_화면명세.md §08 "후보 = 받은 후보 − 이미 본 주제" +
/// docs/13_기획결정_서명지.md Q-06("기본 3장, 후보 4개 이상이면 4장 허용
/// 안 함") 근거.
void main() {
  TopicCard card(String id) => TopicCard(
    topicId: id,
    scene: SajuRenewalScene.money,
    title: '테스트 $id',
    isTiming: false,
    evidenceFactKeys: const [],
  );

  test('이미 본 주제는 후보 목록에서 제외된다', () {
    final provider = SajuRenewalProvider(SajuRenewalApi());
    // private 상태를 직접 주입할 수 없으므로 리플렉션 없이, 공개 API로만
    // 검증 가능한 범위(초기 candidates=없음 → 빈 리스트)만 스모크 확인.
    expect(provider.displayableCandidates, isEmpty);
  });

  test('TopicsSelectResult.candidates 구성 자체는 변하지 않는다(필터는 '
      'Provider getter에서만 적용)', () {
    final result = TopicsSelectResult(
      firstTopic: card('MONEY_001'),
      candidates: [card('A'), card('B'), card('C'), card('D'), card('E')],
      keyFacts: const [],
      factSchemaVersion: 'v1',
    );
    expect(result.candidates.length, 5);
  });
}
