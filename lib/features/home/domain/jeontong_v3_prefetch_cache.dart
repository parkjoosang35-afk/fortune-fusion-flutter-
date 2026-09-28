// [정통사주 69종 리딩 지연 개선 — P0 이중 로딩 제거] 로딩화면
// (JeontongEightyLoadingScreen)이 사주를 계산하는 동안 saju_v3 API 3종
// (/report·/interpret·/narrative)을 미리 시작해 두고, 결과화면
// (JeontongEightyResultScreen)이 같은 진행 중인 Future를 그대로 이어받게
// 하기 위한 in-flight 공유 캐시.
//
// [문제 — 실측 확인] 기존에는 로딩화면(고정 8초 애니메이션, 순수 로컬
// 계산만 warm)이 끝난 뒤에야 결과화면이 처음으로 saju_v3 네트워크 호출을
// 시작했다. 그 결과 사용자는 "로딩화면 8초" → "결과화면 진입 후 또
// 회색 스켈레톤(최대 60초)"이라는 이중 대기를 겪었다(69종 리딩 지연
// 개선 지시서 GAP-01과 실측 일치).
//
// [해결 원칙 — 재계산 없음, 새 엔진 없음] 이미 존재하는 SajuV3Api 호출
// 3개를 "언제 시작하느냐"만 앞당긴다. 계산 로직/서버/모델은 전혀 바꾸지
// 않는다 — 순수하게 "로딩화면 진입 시점에 미리 요청을 쏘아 둔다"는
// 타이밍 최적화다. 결과화면은 이 캐시에 이미 진행 중인 Future가 있으면
// 그것을 그대로 await하고, 없으면(예: 로딩화면을 건너뛴 딥링크 진입 등)
// 기존과 동일하게 그 자리에서 새로 시작한다 — 회귀 없음.
//
// [캐시 수명 — 짧고 좁게] 이 캐시는 "동일 카테고리로의 즉시 이어달리기"
// 만을 위한 것이므로 TTL을 짧게(2분) 두고, 화면 전환이 끝나 소비되면
// 즉시 제거한다(consume). 여러 카테고리를 미리 준비해 두는 범용 캐시가
// 아니다.
import 'dart:async';

import '../../fortune/saju_v3/data/saju_v3_api.dart';
import '../../fortune/saju_v3/domain/birth_input.dart';
import '../../fortune/saju_v3/domain/interpretation_result.dart';
import '../../fortune/saju_v3/domain/narrative_result.dart';
import '../../fortune/saju_v3/domain/saju_report.dart';

class JeontongV3PrefetchBundle {
  JeontongV3PrefetchBundle({
    required this.report,
    required this.interpret,
    required this.narrative,
  });

  final Future<SajuReportResult> report;
  final Future<InterpretationResult> interpret;
  final Future<NarrativeResult> narrative;
}

class _Entry {
  _Entry(this.bundle, this.expiresAt);
  final JeontongV3PrefetchBundle bundle;
  final DateTime expiresAt;
}

/// [싱글턴 — 화면 간 공유] 로딩화면과 결과화면이 서로 다른 State 객체이므로
/// (Navigator.pushReplacementNamed로 화면 자체가 교체됨) 전역 인스턴스로
/// 캐시를 공유한다. 기존 [jeontongReportCache](legacy 로컬 계산 캐시)와
/// 동일한 파일 레벨 싱글턴 패턴을 그대로 따른다.
class JeontongV3PrefetchCache {
  JeontongV3PrefetchCache({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  static const Duration _ttl = Duration(minutes: 2);

  final Map<String, _Entry> _entries = {};

  String _key(String categoryId, BirthInput b) =>
      '${categoryId}_${b.year}${b.month}${b.day}${b.hour}${b.minute}${b.gender}${b.isLunar}';

  /// [로딩화면에서 호출] 아직 이 카테고리에 대한 진행 중인 요청이 없을
  /// 때만 saju_v3 API 3종을 새로 시작해 캐시에 넣는다. 이미 있으면(예:
  /// 같은 화면이 재빌드되어 initState가 또 불렸을 가능성 방어) 기존
  /// 것을 그대로 반환한다 — 중복 네트워크 호출 방지. 반환값은 로딩화면이
  /// 자체적으로 "최소 대기 시간 vs 실제 응답 완료" 중 더 늦은 시점까지
  /// 기다리는 타이밍 게이트에도 그대로 쓰인다(같은 Future 인스턴스).
  JeontongV3PrefetchBundle start({
    required SajuV3Api api,
    required String categoryId,
    required BirthInput birth,
    required String question,
  }) {
    final key = _key(categoryId, birth);
    final existing = _entries[key];
    if (existing != null && _now().isBefore(existing.expiresAt)) {
      return existing.bundle;
    }

    final bundle = JeontongV3PrefetchBundle(
      report: api.getSajuV3Report(birth, question: question),
      interpret: api.getSajuV3Interpret(birth, categoryCode: categoryId),
      narrative: api.getSajuV3Narrative(
        birth,
        categoryCode: categoryId,
        question: question,
      ),
    );
    _entries[key] = _Entry(bundle, _now().add(_ttl));
    return bundle;
  }

  /// [결과화면에서 호출] 로딩화면이 미리 시작해 둔 Future 묶음을 그대로
  /// 가져온다(소비 — 한 번 가져가면 캐시에서 제거해, 같은 화면을 다시
  /// 열었을 때 이미 완료된 낡은 Future를 재사용하지 않게 한다). 없으면
  /// null — 호출부가 기존과 동일하게 새로 요청을 시작한다(회귀 없음).
  JeontongV3PrefetchBundle? consume(String categoryId, BirthInput birth) {
    final key = _key(categoryId, birth);
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (_now().isAfter(entry.expiresAt)) return null;
    return entry.bundle;
  }
}

final jeontongV3PrefetchCache = JeontongV3PrefetchCache();
