import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_version_repository.dart';

/// [DEV-2026-001 작업3-5-2 재발방지체계] 앱 강제 업데이트 게이트.
///
/// [동작] 앱 부팅 후(SplashScreen 부트스트랩과는 독립적으로) 최초 1회
/// `GET /api/public/app-version`을 호출해 현재 실행 중인 versionCode가
/// 서버의 minVersionCode보다 낮으면, 닫을 수 없는(barrierDismissible:
/// false, back 버튼 무시) 팝업으로 서비스 이용을 차단하고 "업데이트"
/// 버튼만 제공한다.
///
/// [실패 안전(fail-open) 원칙] 버전 체크 API 호출이 실패(네트워크 문제,
/// 서버 일시 장애 등)하면 강제 업데이트를 발동하지 않는다 — 버전 체크
/// 자체의 장애가 전체 서비스를 마비시키면 안 된다는 것이 지시서의
/// 재발방지 취지와도 부합한다(캐시/배포 문제가 서비스 전체를 막았던
/// 이번 사건과 동일한 실수를 반복하지 않기 위함).
///
/// [Web 플랫폼 제외] Flutter Web은 Android APK 배포 채널과 무관하게
/// 항상 최신 소스로 즉시 재배포되므로(4-1/4-2/4-3에서 이미 캐시차단+
/// 버전가시화 완료) 이 게이트의 대상이 아니다. kIsWeb이면 즉시 통과.
class ForceUpdateGate extends StatefulWidget {
  const ForceUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  final _repo = AppVersionRepository();

  @override
  void initState() {
    super.initState();
    // build()보다 먼저 다이얼로그를 열 수 없으므로 첫 프레임 콜백에서 체크.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVersion());
  }

  Future<void> _checkVersion() async {
    // Web은 강제 업데이트 대상이 아님 (위 클래스 docstring 참고).
    if (kIsWeb) return;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(info.buildNumber) ?? 0;

      final result = await _repo.checkVersion();
      if (!mounted) return;

      if (result.success && result.data != null) {
        final policy = result.data!;
        if (policy.isForceUpdateRequired(currentVersionCode)) {
          _showForceUpdateDialog(policy);
        }
      }
      // 체크 실패 또는 최신 버전이면 아무 것도 하지 않고 그대로 통과
      // (fail-open) — 이 위젯은 항상 child를 그대로 렌더링하고, 필요할
      // 때만 다이얼로그를 그 위에 얹는 방식이라 별도 상태 전환이 없다.
    } catch (e) {
      debugPrint('[ForceUpdateGate] [_checkVersion] 예외(fail-open으로 통과) -> $e');
    }
  }

  void _showForceUpdateDialog(AppVersionPolicy policy) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        // [강제 차단] 뒤로가기로 팝업을 우회할 수 없게 한다.
        canPop: false,
        child: AlertDialog(
          title: const Text('업데이트가 필요합니다'),
          content: Text(
            (policy.notice != null && policy.notice!.isNotEmpty)
                ? policy.notice!
                : '더 안정적인 서비스 이용을 위해 최신 버전으로 업데이트해주세요.\n'
                      '이 버전은 더 이상 지원되지 않습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final uri = Uri.tryParse(policy.updateUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('업데이트'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [체크가 끝나기 전에는 앱 콘텐츠를 잠깐 빈 화면으로 둔다] SplashScreen
    // 자체 스켈레톤/애니메이션과 경쟁하지 않도록, 여기서는 별도 로딩 UI를
    // 그리지 않고 단순히 child를 먼저 렌더링한다 — 체크는 매우 빠르게
    // (보통 수백ms 이내) 끝나고, fail-open이므로 체감상 지연이 거의 없다.
    // 강제 업데이트 대상일 때만 다이얼로그가 child 위에 얹혀 서비스를
    // 차단한다(_checked는 다이얼로그를 띄우지 않을 때만 true가 됨).
    return widget.child;
  }
}
