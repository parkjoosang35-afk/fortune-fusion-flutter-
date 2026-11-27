import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/env_config.dart';

/// [운영 서버 오접속 재발 방지 — 디버그 전용 서버주소 표시]
///
/// [배경] 빌드 시 `--dart-define=ADMIN_API_BASE_URL=...`을 빠뜨려 로컬
/// 테스트인데도 모르는 사이 운영 서버(sintong.kr)로 붙는 사고가 이미
/// 두 번 발생했다. 캡처 화면 한 장만 보고도 "이게 로컬인지 운영인지"를
/// 바로 알 수 있도록, 지금 앱이 실제로 접속 중인 [EnvConfig.adminApiBaseUrl]을
/// 화면 구석에 작게 표시한다.
///
/// **디버그 빌드에서만 보인다.** `kReleaseMode`(release/profile 빌드)에서는
/// `SizedBox.shrink()`를 반환해 완전히 비노출 — 운영/배포 화면에는 절대
/// 섞여 들어가지 않는다(`build_local.sh`의 기본 release 빌드도 포함해,
/// 일반 `flutter build web --release`로 만든 결과물에는 나타나지 않는다.
/// `build_local.sh --debug`로 디버그 빌드했을 때만 보인다).
///
/// 사용법: [App]의 `MaterialApp.builder`에서 전체 화면 트리 맨 위에
/// `Stack`으로 얹어 모든 라우트/팝업에서 항상 보이게 한다.
class DebugBackendBadge extends StatelessWidget {
  const DebugBackendBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // 릴리즈(및 프로파일) 빌드에서는 완전히 숨긴다 — 운영 화면에 절대 노출 금지.
    if (kReleaseMode) return const SizedBox.shrink();

    final url = EnvConfig.adminApiBaseUrl;
    final isLocal = url.contains('localhost') || url.contains('127.0.0.1');

    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: IgnorePointer(
          child: Container(
            margin: const EdgeInsets.only(top: 4, right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: (isLocal ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C))
                  .withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isLocal ? '🖥 LOCAL · $url' : '☁️ PROD · $url',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
