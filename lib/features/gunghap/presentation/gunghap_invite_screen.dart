// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_invite_screen.dart
// [귀인지도 궁합지도 개발 지시서 §2②] 궁합지도 초대 화면.
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
//
// [v4 핸드오프 반영 — S11] 00_DEV_MAPPING.md §5 S11 명세 중 "보내는
// 사람·나" 프로필 카드와 "받는 사람·상대방" 점선 카드를 추가한다.
// 생년월일 표시 포맷은 guinji_onboarding_screen.dart의 _formatBirthDate/
// _hourToJijiLabel 패턴을 재사용했다(검증된 기존 로직 재사용 원칙).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../saju_renewal/screens/birth_input_screen.dart';
import '../application/gunghap_provider.dart';
import '../domain/gunghap_data.dart';
import '../share/gunghap_share_kakao.dart'
    show shareGunghapInvite, copyGunghapInviteLink, buildGunghapInviteLink, GunghapShareTarget;
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

  /// [2026-11 궁합 주제 반영 지시서 — Section 1] 카카오 공유 메시지에
  /// 쓸 주제 표시 문구. 주제 미선택 시 null(기존 일반 문구 사용).
  String? get _topicLabel {
    final major = _major;
    if (major == null) return null;
    final subName = widget.subName;
    return subName == null || subName.isEmpty
        ? major.name
        : '${major.name} · $subName';
  }

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
    final ok = await provider.createInviteForUser(
      user,
      majorId: widget.majorId,
      subName: widget.subName,
    );
    if (!mounted) return;
    setState(() => _creating = false);

    if (!ok) {
      // [v4 핸드오프 반영 — S10 삭제 결정] 회원가입 시 이미 생년월일/시간/
      // 성별을 1회 수집하므로, 로그인 회원이라면 정상적으로는 이 경로를
      // 타지 않는다. 혹시 과거 가입자 등 프로필이 비어 있는 예외 상황이면
      // 궁합 플로우 안에 새 입력 화면을 끼워 넣지 않고, 기존 마이페이지
      // 수정 화면(BirthInputScreen(isEditMode:true))으로 안내한다 —
      // "이미 프로필 입력했는데 또 입력"을 막기 위한 설계(어뷰징 방지).
      if (provider.errorCode == 'PROFILE_INCOMPLETE') {
        AppToast.show(
          context,
          provider.error ?? '사주 정보가 없어 궁합을 계산할 수 없어요. 프로필을 먼저 완성해 주세요.',
          isError: true,
          onRetry: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BirthInputScreen(isEditMode: true),
            ),
          ),
          retryLabel: '프로필 완성하기',
        );
        return;
      }
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
        topicLabel: _topicLabel,
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

  /// [v4 핸드오프 S11] "子" 등 12지지 한자 → 시진 라벨.
  /// guinji_onboarding_screen.dart의 동일 함수를 그대로 재사용(단순
  /// 표시용 — 계산 엔진에는 영향 없음).
  static const _jijiHanja = [
    '子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥', //
  ];

  String _hourToJijiLabel(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return '';
    final hour = int.tryParse(parts[0]);
    if (hour == null) return '';
    final index = ((hour + 1) ~/ 2) % 12;
    return _jijiHanja[index];
  }

  String _formatMyBirthLine(UserModel user) {
    final birthDate = user.birthDate;
    if (birthDate == null || birthDate.isEmpty) return '생년월일 미등록';
    final parts = birthDate.split('-');
    final dateLabel = parts.length == 3
        ? '${parts[0]}.${parts[1]}.${parts[2]}'
        : birthDate;
    final calendarLabel = user.isLunar ? '음력' : '양력';
    final timeLabel = (user.birthTimeUnknown || user.birthTime == null)
        ? '시간 모름'
        : '${_hourToJijiLabel(user.birthTime!)}시';
    final genderLabel = user.gender == 'male' ? '남성' : '여성';
    return '$dateLabel $calendarLabel · $timeLabel · $genderLabel';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();
    final created = provider.inviteToken != null;
    final major = _major;
    final auth = context.watch<AuthProvider>();
    final me = auth.currentUser;

    // [v4 핸드오프 S11/S13] 생성 전(폼)과 생성 후(공유)는 명세상 전혀 다른
    // 레이아웃을 쓰므로 build()를 분리한다.
    return created
        ? _buildShareScreen(context, provider, me)
        : _buildFormScreen(context, major, me);
  }

  /// [v4 핸드오프 S11] 초대장 생성 전 — 내 프로필 확인 + 상대방 안내.
  Widget _buildFormScreen(BuildContext context, GHMajor? major, UserModel? me) {
    return GHScreen(
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(
        title: '상대방 정보',
        onBack: () => Navigator.of(context).pop(),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GHButton(
            label: _creating ? '초대장을 만드는 중…' : '✉ 초대장 만들기',
            onPressed: _creating ? null : _createInvite,
          ),
          const SizedBox(height: 8),
          Text(
            '카카오톡 · 문자 · 링크로 보낼 수 있어요',
            style: GHText.ui(size: 11.5, color: GHColors.gray),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GHSteps(step: 2, total: 3, labels: ['분야', '상대', '분석']),
          GHTitle(
            mono: 'STEP 03 · THEIR STAR',
            title: '상대방에게\n초대장을 보내 볼까요',
            sub: '생년월일을 몰라도 괜찮아요. 상대방이 직접 입력해요.',
          ),
          // [v4 핸드오프 S11] "보내는 사람 · 나" 카드 — 이미 회원가입 시
          // 저장된 프로필을 그대로 보여주기만 한다(재입력 없음).
          GHMono('보내는 사람 · 나', color: GHColors.gray),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GHColors.card,
              borderRadius: BorderRadius.circular(GHRadius.cardSm),
              border: Border.all(color: GHColors.lineSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: GHGradients.primary,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '★',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            me?.nickname ?? '나',
                            style: GHText.cardTitle(size: 14.5),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: GHColors.mint.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '회원 정보',
                              style: GHText.ui(size: 10, weight: FontWeight.w700, color: GHColors.mint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        me == null ? '로그인이 필요해요' : _formatMyBirthLine(me),
                        style: GHText.ui(size: 12, color: GHColors.gray),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BirthInputScreen(isEditMode: true),
                    ),
                  ),
                  child: Text('수정', style: GHText.ui(size: 12.5, weight: FontWeight.w700, color: GHColors.accent)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // [v4 핸드오프 S11] "받는 사람 · 상대방" 점선 카드 — 상대방
          // 생년월일은 절대 여기서 입력받지 않는다(§ 파일 헤더 절대 금지 원칙).
          GHMono('받는 사람 · 상대방', color: GHColors.gray),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GHRadius.cardSm),
              border: Border.all(color: GHColors.lineSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GHColors.fieldBg,
                    border: Border.all(color: GHColors.lineSoft),
                  ),
                  alignment: Alignment.center,
                  child: Text('?', style: GHText.cardTitle(size: 18, color: GHColors.gray)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('상대방이 직접 입력해요', style: GHText.cardTitle(size: 14.5)),
                      const SizedBox(height: 3),
                      Text(
                        '생년월일을 몰라도 초대장을 보낼 수 있어요',
                        style: GHText.ui(size: 12, color: GHColors.gray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.subName != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('함께 볼 궁합', style: GHText.ui(size: 13, color: GHColors.gray)),
                Text(
                  widget.subName!,
                  style: GHText.ui(size: 13.5, weight: FontWeight.w700, color: GHColors.accent),
                ),
              ],
            ),
          ],
          if (!context.read<AuthProvider>().isLoggedIn) ...[
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

  /// [v4 핸드오프 S13] 초대장 생성 후 — 공유/메시지/참여현황.
  Widget _buildShareScreen(
    BuildContext context,
    GunghapProvider provider,
    UserModel? me,
  ) {
    final link = provider.inviteToken == null
        ? ''
        : buildGunghapInviteLink(provider.inviteToken!);
    final messagePreview = _topicLabel == null
        ? '${me?.nickname ?? '친구'} 님이 궁합지도 초대장을 보냈어요.\n'
              '"나와 당신의 궁합이 궁금하지 않으세요?"\n'
              '생년월일만 입력하면 바로 확인할 수 있어요.\n$link'
        : '${me?.nickname ?? '친구'} 님이 "${_topicLabel!}" 궁합지도 초대장을 보냈어요.\n'
              '"나와 당신의 궁합이 궁금하지 않으세요?"\n'
              '생년월일만 입력하면 바로 확인할 수 있어요.\n$link';

    return GHScreen(
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(
        title: '궁합 초대장',
        onBack: () => Navigator.of(context).pop(),
      ),
      // [S13 명세] Footer 3분할: 카카오톡 · 문자 · 링크 복사.
      footer: Row(
        children: [
          Expanded(
            child: GHButton(
              label: '카카오톡',
              variant: GHButtonVariant.kakao,
              size: GHButtonSizeT.sm,
              onPressed: () => shareGunghapInvite(
                context,
                provider.inviteToken,
                ownerName: me?.nickname,
                topicLabel: _topicLabel,
                target: GunghapShareTarget.kakao,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GHButton(
              label: '✉ 문자',
              variant: GHButtonVariant.secondary,
              size: GHButtonSizeT.sm,
              onPressed: () => shareGunghapInvite(
                context,
                provider.inviteToken,
                ownerName: me?.nickname,
                topicLabel: _topicLabel,
                target: GunghapShareTarget.sms,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GHButton(
              label: '⧉ 링크 복사',
              variant: GHButtonVariant.secondary,
              size: GHButtonSizeT.sm,
              onPressed: () => copyGunghapInviteLink(
                context,
                provider.inviteToken,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GHSteps(step: 2, total: 3, labels: ['분야', '상대', '분석']),
          // [S13 명세] 초대장 카드(폭 280 상당 — 화면 폭에 맞춰 중앙 정렬).
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GHColors.card,
                  borderRadius: BorderRadius.circular(GHRadius.card),
                  border: Border.all(color: GHColors.lineSoft),
                  boxShadow: GHShadow.card,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: StarMap(aName: '나', bName: '?', draw: false),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우리의 인연은\n얼마나 특별할까요?',
                      textAlign: TextAlign.center,
                      style: GHText.cardTitle(size: 15.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      me?.nickname ?? '나',
                      style: GHText.ui(size: 12.5, color: GHColors.gray),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: GHColors.accent.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '나와 궁합 확인하기',
                        style: GHText.ui(size: 12.5, weight: FontWeight.w700, color: GHColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_topicLabel != null) ...[
                GHChip(label: _topicLabel!, active: true, onTap: () {}),
                const SizedBox(width: 8),
              ],
              GHChip(label: '유효기간 7일', active: false, onTap: () {}),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GHMono('MESSAGE', color: GHColors.gray),
              GestureDetector(
                onTap: () => copyGunghapInviteLink(
                  context,
                  provider.inviteToken,
                  fullMessage: true,
                  ownerName: me?.nickname,
                  topicLabel: _topicLabel,
                ),
                child: Text(
                  '⧉ 메시지 복사',
                  style: GHText.ui(size: 12.5, weight: FontWeight.w700, color: GHColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('초대 메시지', style: GHText.cardTitle(size: 15.5)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => copyGunghapInviteLink(
              context,
              provider.inviteToken,
              fullMessage: true,
              ownerName: me?.nickname,
              topicLabel: _topicLabel,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GHColors.fieldBg,
                borderRadius: BorderRadius.circular(GHRadius.cardSm),
              ),
              child: Text(
                messagePreview,
                style: GHText.ui(size: 12.5, height: 1.6, color: GHColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // [S13 명세] 참여 현황 확인하기 버튼(54, 흰, 1.5px line, r16).
          GestureDetector(
            onTap: _checkingStatus ? null : _checkStatus,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: GHColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GHColors.lineSoft, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GHColors.mint,
                      boxShadow: [
                        BoxShadow(
                          color: GHColors.mint.withValues(alpha: .35),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _checkingStatus ? '확인하는 중…' : '참여 현황 확인하기',
                          style: GHText.ui(size: 14, weight: FontWeight.w700),
                        ),
                        Text(
                          '응답 대기 · 상대방이 입력하면 알림으로 알려 드려요',
                          style: GHText.ui(size: 12, color: GHColors.gray),
                        ),
                      ],
                    ),
                  ),
                  Text('›', style: GHText.ui(size: 16, color: GHColors.gray)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
