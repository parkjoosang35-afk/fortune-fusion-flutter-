// ============================================================
// [정통사주 부적게이트 - 세션 추적 + 축복 문구]
// 원본: 사용자 업로드 `부적게이트_핸드오프.zip`(TalismanGate.jsx, React)의
// Flutter 포팅. "운세 섹션 진입 → (부적게이트/인트로) → 정통사주 69종
// 목록"으로 이어지는 진입 흐름의 게이트 단계에서만 쓰인다. 카테고리 선택
// 이후의 만세력 계산 로딩([JeontongEightyLoadingScreen], 8초, 별개 화면)
// 과는 완전히 독립적이다 — 두 화면의 시간을 합산하지 않는다.
// AI 타로/관상/손금/상담 등 다른 운세 기능과는 전혀 무관하다.
//
// [원상복구 - 시간 스펙 정정] 이전에는 "만세력 로딩 5초 + 게이트 3초 =
// 총 8초"라는 합산 논리로 게이트를 3초/1.5초로 설정했었다. 이는 게이트가
// 결과 로딩 뒤에 붙어있다는 잘못된 배치를 전제로 한 계산이었다. 게이트가
// "운세 진입 직전"으로 옮겨진 뒤에는 두 화면이 서로 다른 시점에 독립적으로
// 동작하므로 합산할 이유가 없다. 확정된 스펙:
//   - 만세력 로딩([JeontongEightyLoadingScreen]) = 8초 (고정, 이 파일과 무관)
//   - 부적게이트(이 화면) = 5초 (첫 노출 기준)
//
// [개발자 확정 답변 반영]
// Q1: (재정정) 만세력 로딩 8초(불변, 별개 화면) / 부적게이트(인트로) 5초
//     (첫 노출) — 두 시간은 서로 다른 화면·다른 시점이므로 합산하지 않는다.
// Q2: 매번 노출하되, 같은 앱 세션(마지막 노출 후 30분 이내 재진입) 2번째
//     부터는 게이트 시간을 절반(2.5초)으로 단축한다.
// Q3: React 원본의 범용 12종 축복 문구를 §9(범용 문구 금지) 정책에 맞춰
//     신통방통 톤으로 재작성했다(사용자 확정 리스트, 값 변경 없이 그대로
//     반영).
// Q4: SKIP 버튼 제거(showSkip=false 상당) — 대신 "탭 1회당 -300ms 가속"
//     로직을 게이트 화면(jeontong_talisman_gate_screen.dart)에서 구현한다.
//     이 파일은 그 가속 폭(_tapAccelerationMs)의 단일 소스를 제공한다.
// ============================================================

/// 부적게이트 1회 노출에 걸리는 총 시간(밀리초) — 세션 내 노출 순서에 따라
/// 달라진다. [JeontongGateSession.markShownAndGetDurationMs]가 이 값을
/// 세션 상태와 함께 반환한다.
class JeontongGateSession {
  JeontongGateSession._();

  /// 세션 내 "처음" 노출로 간주하는 기준 — 마지막 노출로부터 이 시간이
  /// 지나면 다시 "처음"(5초)으로 취급한다.
  static const Duration _sessionWindow = Duration(minutes: 30);

  /// 첫 노출 시 게이트 총 시간(ms) — 5초(인트로 고정 스펙). 만세력 로딩
  /// (별개 화면, 8초)과는 합산 관계가 아니다.
  static const int firstShowDurationMs = 5000;

  /// 같은 세션 2번째부터의 게이트 총 시간(ms) — 리듬 유지를 위해 절반 단축.
  static const int repeatShowDurationMs = 2500;

  /// 부적 1회 탭당 카운트다운을 앞당기는 폭(ms). SKIP 버튼 대신 능동적
  /// 유저가 스스로 더 빨리 넘어갈 수 있게 하는 가속 장치.
  static const int tapAccelerationMs = 300;

  static DateTime? _lastShownAt;

  /// 이번 진입이 세션 내 "첫 노출"인지 계산해 적절한 총 시간을 반환하고,
  /// 노출 시각을 갱신한다. 화면의 [initState]에서 정확히 1회 호출한다.
  static int markShownAndGetDurationMs() {
    final now = DateTime.now();
    final last = _lastShownAt;
    final isFirst = last == null || now.difference(last) > _sessionWindow;
    _lastShownAt = now;
    return isFirst ? firstShowDurationMs : repeatShowDurationMs;
  }

  /// 테스트/디버그용 — 세션 상태를 초기화한다.
  static void resetForTest() {
    _lastShownAt = null;
  }
}

/// 부적을 탭할 때마다 무작위로 하나씩 표시되는 축복 문구 12종.
/// [§9 금지 문구 정책] 범용 문구("행운을 빕니다" 류)를 배제하고, 신통방통
/// 특유의 한자/사주 톤("기운", "형통", "재수" 등)으로 재작성했다(사용자
/// 최종 확정 리스트 — 값 변경 없이 그대로 반영).
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
