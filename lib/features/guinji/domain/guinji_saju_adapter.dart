import '../../home/domain/manseryeok/saju_profile.dart';

/// [귀인지도 실구현] Flutter [SajuProfile](정통사주 80종 신규 엔진 산출값)을
/// 백엔드 `GuinjiSajuInput`(admin_web `src/lib/guinji-relation-judger.ts`)
/// 계약과 정확히 일치하는 JSON(Map)으로 변환하는 순수 어댑터.
///
/// [백엔드 계약 — guinji-relation-judger.ts]
/// ```ts
/// export interface GuinjiSajuInput {
///   dayStemHanja: string;
///   stems: { year: string; month: string; day: string; hour: string };
///   branches: { year: string; month: string; day: string; hour: string };
///   fiveElementsCount: Record<string, number>; // 키: 목/화/토/금/수
///   sinsalIds: string[]; // 예: ['天乙貴人'] — 순수 한자만
/// }
/// ```
///
/// [형식 일치 근거]
/// - [SajuProfile.dayPillar.stemHanja]/[Pillar.stemHanja]/[Pillar.branchHanja]는
///   이미 순수 한자 1글자(예: '甲', '子')다 — 별도 변환 불필요.
/// - [SajuProfile.fiveElements.totalCount]는 천간+지지 단순 합산 오행 카운트로,
///   키가 이미 한글 '목'/'화'/'토'/'금'/'수'이다(fiveElements_profile.dart 참고)
///   — 백엔드 GAN_ELEMENT/ZHI_ELEMENT 고정표와 동일한 한글 키 체계.
/// - [SajuProfile.sinsal]의 각 [SinsalEntry.id]는 `sinsal_engine.dart` 내부에서
///   `f.split('(').first`로 이미 괄호+한글 표기가 제거된 순수 한자 형식이다
///   (예: '天乙貴人') — 백엔드 `sinsalIds: ['天乙貴人']`와 정확히 일치하므로
///   추가 변환 로직이 필요 없다.
Map<String, dynamic> guinjiSajuInputFromProfile(SajuProfile profile) {
  return {
    'dayStemHanja': profile.dayPillar.stemHanja,
    'stems': {
      'year': profile.yearPillar.stemHanja,
      'month': profile.monthPillar.stemHanja,
      'day': profile.dayPillar.stemHanja,
      'hour': profile.hourPillar.stemHanja,
    },
    'branches': {
      'year': profile.yearPillar.branchHanja,
      'month': profile.monthPillar.branchHanja,
      'day': profile.dayPillar.branchHanja,
      'hour': profile.hourPillar.branchHanja,
    },
    'fiveElementsCount': profile.fiveElements?.totalCount ?? const {},
    'sinsalIds': profile.sinsal?.map((e) => e.id).toList() ?? const [],
  };
}
