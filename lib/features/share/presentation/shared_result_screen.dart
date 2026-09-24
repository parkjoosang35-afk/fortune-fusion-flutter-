import 'package:flutter/material.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_error_state.dart';
import '../data/share_api_service.dart';
import '../domain/share_result_model.dart';

/// [결과 공유 기능] `/r/{shareId}` 딥링크(앱 설치 상태에서 App Links로
/// 직접 열렸거나, `GuinjiDeepLinkHandler`가 커스텀 스킴/https 링크를
/// 수신해 push한 경우) 도착 시 보여주는 화면.
///
/// [admin_web `/r/[id]` SSR 페이지와의 관계] 앱이 설치되지 않은 사용자는
/// admin_web의 `shared-result-view.tsx`(OG 태그 포함 SSR 웹페이지)를 보고,
/// 앱이 설치된 사용자는 이 화면으로 직접 도착한다 — 동일한
/// `GET /api/public/share/{shareId}` API를 호출해 동일한 데이터를 표시
/// 한다(웹/앱 양쪽에서 일관된 콘텐츠).
///
/// [비로그인 접근 허용] 이 화면은 로그인 여부와 무관하게 열람 가능하다
/// (shareId 자체가 유일한 접근 통제 수단 — NFR-03). 탈퇴/로그아웃 상태의
/// 사용자도 카카오톡으로 받은 링크를 눌러 앱이 열리면 정상적으로 결과를
/// 볼 수 있어야 한다.
class SharedResultScreen extends StatefulWidget {
  const SharedResultScreen({super.key, required this.shareId});

  final String shareId;

  @override
  State<SharedResultScreen> createState() => _SharedResultScreenState();
}

class _SharedResultScreenState extends State<SharedResultScreen> {
  final ShareApiService _api = ShareApiService();

  bool _loading = true;
  String? _error;
  SharedResultDto? _shared;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.fetchSharedResult(widget.shareId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success && result.data != null) {
        _shared = result.data;
      } else {
        _error = result.errorMessage ?? '공유된 결과를 찾을 수 없어요.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('공유된 결과', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? AppErrorState(message: _error!, onRetry: _load)
            : _buildResult(context, _shared!),
      ),
    );
  }

  Widget _buildResult(BuildContext context, SharedResultDto shared) {
    final payload = shared.payload ?? const {};
    final highlights = (payload['highlights'] as List?)
        ?.map((e) => e.toString())
        .toList();
    return ListView(
      padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
      children: [
        Text(_typeLabel(shared.resultType), style: UnifiedText.caption()),
        const SizedBox(height: UnifiedTokens.spaceXs),
        Text(shared.title, style: UnifiedText.titleLarge()),
        const SizedBox(height: UnifiedTokens.spaceMd),
        Container(
          padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
          decoration: BoxDecoration(
            color: UnifiedColors.cardAllMenu,
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
          ),
          child: Text(shared.description, style: UnifiedText.body()),
        ),
        if (highlights != null && highlights.isNotEmpty) ...[
          const SizedBox(height: UnifiedTokens.spaceMd),
          ...highlights.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceSm),
              child: Text(h, style: UnifiedText.body()),
            ),
          ),
        ],
        const SizedBox(height: UnifiedTokens.spaceXl),
        if (shared.ownerNickname != null)
          Text(
            '${shared.ownerNickname}님이 공유했어요',
            style: UnifiedText.caption(),
          ),
        const SizedBox(height: UnifiedTokens.spaceLg),
        Center(
          child: TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
            child: const Text('신통방통 홈으로 가기'),
          ),
        ),
      ],
    );
  }

  String _typeLabel(ShareResultType type) {
    switch (type) {
      case ShareResultType.fortune:
        return '오늘의 운세';
      case ShareResultType.tarot:
        return '타로';
      case ShareResultType.face:
        return '관상';
      case ShareResultType.palm:
        return '손금';
      case ShareResultType.wish:
        return '소원방';
    }
  }
}
