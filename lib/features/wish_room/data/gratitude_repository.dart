import '../domain/gratitude_models.dart';

/// 감사 도장(GratitudeSeal) Repository 인터페이스 — bokjumeoni-plan §03
/// SERVER API `GET /gratitude/sealable`, `POST /gratitude/seal`,
/// `GET /gratitude/received` 3개 엔드포인트에 대응한다.
///
/// [아키텍처 패턴] `shop_repository.dart`(ShopRepository/ApiShopRepository)와
/// 동일한 인터페이스+구현체 분리 패턴을 따른다. 현재는 [ApiGratitudeRepository]
/// 단일 구현체만 존재한다(Mock 없음 — 서버 API가 이미 완성되어 있으므로).
abstract class GratitudeRepository {
  /// 내가 아직 답례 도장을 찍지 않은, 24시간 이내의 받은 sendPouch 후보 목록.
  Future<List<GratitudeSealableCandidate>> fetchSealable();

  /// 내가 받은(recipient) 감사 도장 목록(최신순).
  Future<List<GratitudeSeal>> fetchReceived();

  /// [sourcePouchId]에 답례 도장을 찍는다. 성공 시 생성된 [GratitudeSeal]을
  /// 반환한다(senderGrantedAmount 포함). 실패 시 [GratitudeException]을 던진다.
  Future<GratitudeSeal> seal(int sourcePouchId);
}
