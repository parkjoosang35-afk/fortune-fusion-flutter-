import '../../guinji/domain/guinji_saju_adapter.dart';
import '../../home/domain/manseryeok/saju_profile.dart';

/// [궁합지도 Flutter 화면 개발 — §1①] 궁합지도(Gunghap) 전용 사주 입력
/// 어댑터.
///
/// [재사용 원칙 — §6 "기존 엔진의 검증된 기능을 분석하여 재사용한다"]
/// 백엔드 `admin_web/src/app/api/public/gunghap/invites/route.ts`는
/// 궁합지도 전용 검증기를 새로 만들지 않고, 귀인지도의
/// `isValidGuinjiSajuInput`(`guinji-relation-judger.ts`)을 그대로
/// import해서 재사용한다. 즉 백엔드 계약(`GuinjiSajuInput`) 자체가
/// 귀인지도와 궁합지도 양쪽에서 완전히 동일하다.
///
/// 따라서 Flutter 쪽도 새로운 사주→JSON 변환 로직을 작성하지 않고,
/// 이미 검증된 [guinjiSajuInputFromProfile]을 그대로 위임 호출한다
/// (정통사주 계산 엔진 자체를 변경하지 않는다는 금지사항과도 부합).
/// 이 파일은 오직 "궁합지도 네임스페이스 안에서 명시적으로 참조할 수
/// 있도록" 하는 얇은 재노출(re-export) 역할만 한다.
Map<String, dynamic> gunghapSajuInputFromProfile(SajuProfile profile) =>
    guinjiSajuInputFromProfile(profile);
