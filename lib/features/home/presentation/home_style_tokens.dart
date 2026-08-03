/// [서브 디자인 통일 확산 프롬프트] 홈 전용 토큰 → 앱 전역 공용 토큰 승격.
///
/// 이 파일에 정의되어 있던 `HomeColors`/`HomeText`/`HomeTokens`는
/// `core/theme/app_unified_style.dart`의 `UnifiedColors`/`UnifiedText`/
/// `UnifiedTokens`로 승격되어 앱 전역(운세/커뮤니티/복주머니/마이/결과 페이지)
/// 서브 화면에서 공용으로 재사용된다. `home_screen.dart`가 기존 이름
/// (`HomeColors` 등)을 그대로 참조하고 있어 회귀 없이 전환하기 위해 이 파일은
/// 값을 직접 정의하지 않고 새 공용 파일을 그대로 가리키는 타입 별칭만 남긴다.
///
/// 신규/서브 화면 코드는 이 파일을 참조하지 말고 항상
/// `core/theme/app_unified_style.dart`의 `UnifiedColors`/`UnifiedText`/
/// `UnifiedTokens`를 직접 import해서 사용한다.
library;

import '../../../core/theme/app_unified_style.dart';

typedef HomeColors = UnifiedColors;
typedef HomeText = UnifiedText;
typedef HomeTokens = UnifiedTokens;
