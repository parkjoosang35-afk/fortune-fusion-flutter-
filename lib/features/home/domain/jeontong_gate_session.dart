// ============================================================
// [부적게이트 · TalismanGate] tapToEnter 스펙 상수 + 축복 문구
//
// mode="tapToEnter": 부적을 [tapsRequired]번 탭하면 [revealDelayMs] 뒤
// onEnter가 발화되어 정통사주 69종 목록으로 이동한다. 카운트다운/자동진입은
// 쓰지 않는다.
// ============================================================

class JeontongGateSession {
  JeontongGateSession._();

  /// 부적을 몇 번 탭해야 진입하는지.
  static const int tapsRequired = 5;

  /// tapsRequired번째 탭 이후 onEnter가 발화되기까지의 지연(ms).
  static const int revealDelayMs = 1600;
}

/// 부적을 탭할 때마다 무작위로 하나씩 표시되는 축복 문구 12종.
const List<String> kJeontongGateBlessings = [
  '재물의 문이 열립니다',
  '귀인이 걸음을 함께 합니다',
  '오래 품은 소원이 움직입니다',
  '길한 기운이 스며듭니다',
  '만사가 형통하는 날입니다',
  '복이 조용히 내려앉습니다',
  '막힌 곳이 트입니다',
  '합격의 기운이 감돕니다',
  '인연의 실이 이어집니다',
  '재수가 크게 통합니다',
  '가정에 평안이 머뭅니다',
  '지혜의 빛이 밝아옵니다',
];
