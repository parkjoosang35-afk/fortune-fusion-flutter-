// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_invite_screen.dart
// [신통방통 궁합지도 개발 지시서 §2②] 궁합지도 초대 화면.
//
// [절대 금지] 이 화면은 상대방(게스트)의 생년월일을 입력받는 어떠한
// 필드도 포함하지 않는다. 초대장은 오직 초대자(로그인 회원) 본인의
// 저장된 프로필 생년월일로만 생성된다([GunghapProvider.createInviteForUser]
// 참고) — "초대 발송자가 상대방의 생년월일을 미리 알고 있어야 하는 구조로
// 만들지 마세요" 지시사항 준수.
//
// [direct vs invite CTA] 홈 화면의 두 버튼(method='direct'|'invite')은
// 모두 이 화면으로 수렴한다(동일 초대 생성 로직 재사용, 중복 구현 없음).
// 차이는 오직 초대 생성 "이후" 동작뿐이다:
//   - direct: 생성 후 이 화면에 그대로 머물며 수동으로 공유 방법을 고른다.
//   - invite: 생성 직후 자동으로 카카오톡 공유 시트를 띄운다(Step 1 완료 직후
//     "카카오톡 공유 단계로 이동"하라는 지시사항 그대로).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../application/gunghap_provider.dart';
import '../domain/gunghap_data.dart';
import '../share/gunghap_share_kakao.dart' show shareGunghapInvite;
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';
import 'gunghap_result_screen.dart';

class GunghapInviteScreen extends StatefulWidget {
  const GunghapInviteScreen({
    super.key,
    required this.method,
    this.majorId,
    this.subName,
  });

  /// 'direct' | 'invite' — 생성 이후 동작만 다르다(§1 참고).
  final String method;
  final String? majorId;
  final String? subName;

  @override
  State<GunghapInviteScreen> createState() => _GunghapInviteScreenState();
}

class _GunghapInviteScreenState extends State<GunghapInviteScreen> {
  bool _creating = false;
  bool _checkingStatus = false;

  GHMajor? get _major =>
      widget.majorId == null ? null : ghMajorById(widget.majorId);

  Future<void> _createInvite() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      // [로그인 게이트] 이 화면은 입력 폼이 없어(본인 프로필만 사용) 복귀용
      // draft 저장이 불필요하다 — 로그인 후 사용자가 다시 "초대장 만들기"를
      // 누르면 된다(guinji_input_screen.dart의 PendingGuinjiMapEntryStore
      // 패턴과 달리 이 화면은 보존할 입력값 자체가 없음).
      Navigator.of(context).pushNamed('/login');
      return;
    }
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _creating = true);
    final provider = context.read<GunghapProvider>();
    final ok = await provider.createInviteForUser(user);
    if (!mounted) return;
    setState(() => _creating = false);

    if (!ok) {
      // [긴급 검수 지시 §4] API 연결 실패(NETWORK_ERROR)는 "서비스 연결이
      // 원활하지 않습니다" 문구로 구분 노출하고, 재시도 버튼을 제공해
      // 사용자가 화면에 그대로 머물지 않도록 한다.
      final isNetworkError = provider.errorCode == 'NETWORK_ERROR';
      AppToast.show(
        context,
        isNetworkError
            ? (provider.error ?? '서비스 연결이 원활하지 않습니다.')
            : (provider.error ?? '초대장을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        isError: true,
        onRetry: _createInvite,
      );
      return;
    }

    if (widget.method == 'invite') {
      // [invite CTA] 생성 직후 자동으로 카카오톡 공유 단계로 이동한다.
      if (!mounted) return;
      await shareGunghapInvite(
        context,
        provider.inviteToken,
        ownerName: user.nickname,
      );
    }
  }

  Future<void> _checkStatus() async {
    final provider = context.read<GunghapProvider>();
    final token = provider.inviteToken;
    if (token == null) return;
    setState(() => _checkingStatus = true);
    final data = await provider.fetchInviteToken(token);
    if (!mounted) return;
    setState(() => _checkingStatus = false);

    if (data == null) {
      final isNetworkError = provider.errorCode == 'NETWORK_ERROR';
      AppToast.show(
        context,
        isNetworkError
            ? (provider.error ?? '서비스 연결이 원활하지 않습니다.')
            : (provider.error ?? '초대 현황을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        isError: true,
        onRetry: _checkStatus,
      );
      return;
    }
    final joined = data['joined'] == true;
    final resultId = data['resultId'] as String?;
    if (!joined || resultId == null) {
      AppToast.show(context, '아직 상대방이 참여하지 않았어요. 초대장을 공유해 주세요.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GunghapResultScreen(resultId: resultId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();
    final created = provider.inviteToken != null;
    final major = _major;

    return GHScreen(
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(
        title: '궁합 초대장',
        onBack: () => Navigator.of(context).pop(),
      ),
      footer: created
          ? GHButton(
              label: _checkingStatus ? '확인하는 중…' : '참여 현황 확인하기',
              variant: GHButtonVariant.secondary,
              onPressed: _checkingStatus ? null : _checkStatus,
            )
          : GHButton(
              label: _creating ? '초대장을 만드는 중…' : '내 사주로 초대장 만들기',
              onPressed: _creating ? null : _createInvite,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GHSteps(step: 2),
          GHTitle(
            mono: 'STEP 02 · MY STAR',
            title: '내 사주로\n초대장을 만들어요',
            sub: major == null
                ? '초대장을 받은 사람이 자신의 생년월일만 입력하면\n두 사람의 궁합이 바로 나와요.'
                : '${major.name}${widget.subName != null ? ' · ${widget.subName}' : ''}\n'
                      '초대장을 받은 사람이 자신의 생년월일만 입력하면 궁합이 나와요.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: StarMap(
                aName: '나',
                bName: created ? '초대받은 사람' : '?',
                draw: created,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GHColors.lineSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '상대방의 생년월일은 입력하지 않아요. 초대장을 받은\n'
                    '사람이 직접, 로그인 없이 자신의 사주 정보를 입력해요.',
                    style: GHText.ui(
                      size: 12,
                      height: 1.6,
                      color: GHColors.gray,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (created) ...[
            const SizedBox(height: 22),
            GHSectionHead(mono: 'SHARE', title: '초대장 공유하기'),
            GHButton(
              label: '카카오톡으로 공유하기',
              variant: GHButtonVariant.kakao,
              leading: const Text('💬', style: TextStyle(fontSize: 15)),
              onPressed: () => shareGunghapInvite(
                context,
                provider.inviteToken,
                ownerName: context.read<AuthProvider>().currentUser?.nickname,
              ),
            ),
            const SizedBox(height: 8),
            GHButton(
              label: '다른 방법으로 공유하기',
              variant: GHButtonVariant.secondary,
              onPressed: () => shareGunghapInvite(
                context,
                provider.inviteToken,
                ownerName: context.read<AuthProvider>().currentUser?.nickname,
              ),
            ),
          ],
          if (!created && !context.read<AuthProvider>().isLoggedIn) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                '초대장 생성은 로그인 후 이용할 수 있어요.',
                style: GHText.ui(size: 12, color: GHColors.gray),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
