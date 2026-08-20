// ============================================================
// [정통사주 부적게이트 - 세션 추적 + 축복 문구]
// 원본: 사용자 업로드 `부적게이트_핸드오프.zip`(TalismanGate.jsx, React)의
// Flutter 포팅. "69종중에 하나를 골라 사주보기 → 로딩 → (부적게이트) →
// 결과"로 이어지는 정통사주 전용 흐름의 마지막 게이트 단계에서만 쓰인다.
// AI 타로/관상/손금/상담 등 다른 운세 기능과는 전혀 무관하다.
//
// [개발자 확정 답변 반영]
// Q1: 만세력 로딩 5초(계산 신뢰감 유지) + 부적게이트 3초 = 총 8초(기존과
//     동일한 총 대기시간). 계산 완료 신뢰감은 로딩 화면이 전담하므로
//     게이트는 로딩을 "대체"하지 않고 그 뒤에 "순차 추가"된다.
// Q2: 매번 노출하되, 같은 앱 세션(마지막 노출 후 30분 이내 재진입) 2번째
//     부터는 게이트 시간만 1.5초로 단축한다. 만세력 로딩은 항상 5초 고정
//     (실계산 신뢰감이므로 단축 대상이 아님 — 이 파일과 무관).
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
  /// 지나면 다시 "처음"(3초)으로 취급한다.
  static const Duration _sessionWindow = Duration(minutes: 30);

  /// 첫 노출 시 게이트 총 시간(ms) — 만세력 로딩 5초 + 이 3초 = 8초로,
  /// 기존 로딩 단독 8초와 총 대기시간이 동일하다.
  static const int firstShowDurationMs = 3000;

  /// 같은 세션 2번째부터의 게이트 총 시간(ms) — 리듬 유지를 위해 단축.
  static const int repeatShowDurationMs = 1500;

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
