import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_navigator_key.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../mypage/presentation/settings_screen.dart';
import '../../../result_access/domain/result_access_model.dart';
import '../../../result_access/presentation/result_access_gate_sheet.dart';
import '../../application/shrine_v3_provider.dart';
import '../../domain/pending_shrine_order.dart';
import '../../domain/talisman_item.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/talisman_thumb.dart';
import '../widgets/talisman_zoom_overlay.dart';
import 'shrine_v3_ask_screen.dart';

/// [비로그인 "민세레나에게 부탁하기" 복귀] 로그인/회원가입 완료 직후
/// 호출한다(귀인지도 `replayPendingGuinjiJoin()`/복주머니 쿠폰
/// `replayPendingBokjuCoupon()`과 동일한 타이밍 전략 — login_screen.dart/
/// signup_screen.dart/signup_choice_screen.dart의 성공 분기에서 호출).
/// 저장된 값이 없으면(= 일반 로그인) 아무 동작도 하지 않는다.
void replayPendingShrineOrder() {
  final pending = PendingShrineOrderStore.consume();
  if (pending == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navState = appNavigatorKey.currentState;
    if (navState == null) return;
    navState.push(
      MaterialPageRoute(
        builder: (_) => ShrineV3DetailScreen(
          talismanId: pending.talismanId,
          restoredWish: pending.wish,
        ),
      ),
    );
  });
}

/// 신당(THE SHRINE) v3 — 05 상세 · 소망 입력. 부적 설명 6섹션(의미/효능/
/// 추천대상/효력기간/사용방법/함께하면 좋은 기원) + 소망 입력(40자) +
/// 회원정보 확인 + "민세레나에게 부탁하기" CTA.
///
/// [사용자 확정 요구사항 #2] 이 화면이 하는 일은 "부적을 고르고 소망을
/// 적는 것"뿐이다 — 요금제/가격 계산은 전혀 하지 않는다. CTA를 누르면
/// 기존 [showResultAccessGateSheet](결과보기와 완전히 동일한 게이트)를
/// `contentType: 'shrine_bujeok'`로 호출하고, 그 결제가 확정된 뒤에만
/// [ShrineV3Provider.createOrder]를 호출해 07 부탁 연출로 넘어간다.
class ShrineV3DetailScreen extends StatefulWidget {
  const ShrineV3DetailScreen({
    super.key,
    required this.talismanId,
    this.restoredWish,
  });

  final String talismanId;

  /// [비로그인 복귀] 로그인 왕복 전에 입력해뒀던 소망을 그대로 복원해
  /// 보여주기 위한 값. 일반 진입 시(모든 기존 호출부)에는 null이라 기존
  /// 동작과 100% 동일하다.
  final String? restoredWish;

  @override
  State<ShrineV3DetailScreen> createState() => _ShrineV3DetailScreenState();
}

class _ShrineV3DetailScreenState extends State<ShrineV3DetailScreen> {
  late final _wishController = TextEditingController(
    text: widget.restoredWish ?? '',
  );
  bool _submitting = false;

  @override
  void dispose() {
    _wishController.dispose();
    super.dispose();
  }

  TalismanItem? _findTalisman(ShrineV3Provider provider) {
    for (final t in provider.catalog) {
      if (t.id == widget.talismanId) return t;
    }
    return null;
  }

  Future<void> _submit(TalismanItem k) async {
    final wish = _wishController.text.trim();
    if (wish.isEmpty) {
      AppToast.show(context, '부적에 담을 소망을 적어주세요.', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      // [비로그인 "민세레나에게 부탁하기" → 로그인창 미전환 버그 수정]
      // 과거에는 토스트만 띄우고 끝(return)이라 로그인 화면으로 전혀
      // 이동하지 않았다 — 비로그인 사용자는 이 버튼을 아무리 눌러도
      // 아무 일도 일어나지 않는 것처럼 보였다. 앱 전역의 검증된
      // "비로그인 복귀" 패턴(귀인지도/복주머니쿠폰/프리패스/결과보기
      // 게이트와 완전히 동일)을 그대로 이식한다: 지금 고른 부적+입력한
      // 소망을 저장해두고 로그인 화면으로 이동, 로그인 성공 시
      // replayPendingShrineOrder()가 이 화면으로 자동 복귀시킨다.
      PendingShrineOrderStore.save(k.id, wish);
      final goLogin = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: ShrineV3Colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: ShrineV3Colors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  '민세레나에게 부탁하려면\n로그인이 필요합니다',
                  textAlign: TextAlign.center,
                  style: ShrineV3TextStyles.title.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  '로그인하면 지금 고른 부적과 소망이\n그대로 이어져요.',
                  textAlign: TextAlign.center,
                  style: ShrineV3TextStyles.ui.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShrineV3Colors.seal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('로그인 / 회원가입'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('나중에'),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (goLogin == true) {
        Navigator.of(context).pushNamed('/login');
      } else {
        // 로그인하지 않기로 했으면 저장해둔 복귀 요청도 함께 취소한다.
        PendingShrineOrderStore.clear();
      }
      return;
    }
    if (user.realName == null ||
        user.realName!.isEmpty ||
        user.birthDate == null) {
      final goSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('회원 정보 확인이 필요합니다'),
          content: const Text('신당 부적을 받으려면 먼저 마이페이지에서 실명과 생년월일을 입력해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('정보 입력하러 가기'),
            ),
          ],
        ),
      );
      if (goSettings == true && mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }
      return;
    }

    setState(() => _submitting = true);

    // [결제 게이트 — 결과보기와 완전히 동일한 구조 재사용] 05→07 전환에만
    // 결제가 발생한다(06 추천받기는 완전 무료 — 서버 호출조차 하지 않는다).
    final beginResult = await showResultAccessGateSheet(
      context,
      contentType: 'shrine_bujeok',
      categoryKey: k.category,
      contentTitle: k.name,
      returnRoute: '/shrine',
    );
    if (!mounted) {
      return;
    }
    if (beginResult == null) {
      setState(() => _submitting = false);
      return;
    }

    final order = await context.read<ShrineV3Provider>().createOrder(
      talismanSlug: k.id,
      wish: wish,
      paymentMethod: beginResult.paymentMethod.code,
      transactionId: beginResult.transactionId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (order == null) {
      final err = context.read<ShrineV3Provider>().error ?? '부적을 짓지 못했습니다.';
      AppToast.show(context, err, isError: true);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ShrineV3AskScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShrineV3Provider>();
    final k = _findTalisman(provider);

    if (k == null) {
      return Scaffold(
        backgroundColor: ShrineV3Colors.paper,
        appBar: AppBar(backgroundColor: ShrineV3Colors.paper),
        body: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const Center(child: Text('부적 정보를 찾을 수 없습니다.')),
      );
    }

    final tint = kShrineCategoryTints[k.category] ?? ShrineV3Colors.seal;
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: ShrineV3Colors.paper,
      appBar: AppBar(
        backgroundColor: ShrineV3Colors.paper,
        foregroundColor: ShrineV3Colors.ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => showTalismanZoomOverlay(context, talisman: k),
                    child: TalismanThumb(
                      talisman: k,
                      width: 92,
                      useThumb: false,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${k.hanja} · ${k.name}',
                      style: TextStyle(
                        color: tint,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    k.name,
                    style: ShrineV3TextStyles.title.copyWith(fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ShrineV3Colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ShrineV3Colors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (k.sub != null) ...[
                    Center(
                      child: Text(
                        k.sub!,
                        textAlign: TextAlign.center,
                        style: ShrineV3TextStyles.body.copyWith(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _section('意', '부적의 의미', k.meaning),
                  _listSection('效', '효능 · 기능', k.effects),
                  _listSection('人', '추천 대상', k.recommendFor),
                  _section('期', '효력 기간', k.validityTerm),
                  _orderedSection('用', '사용 방법', k.usage),
                  _chipSection('祈', '함께 하면 좋은 기원', k.goesWith),
                  const SizedBox(height: 4),
                  Text(
                    '부적은 창작 연출물이며 효험을 보증하지 않아요.',
                    style: ShrineV3TextStyles.ui.copyWith(
                      fontSize: 11,
                      color: ShrineV3Colors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '부적에 담을 소망',
                  style: ShrineV3TextStyles.body.copyWith(fontSize: 14),
                ),
                ValueListenableBuilder(
                  valueListenable: _wishController,
                  builder: (context, value, _) => Text(
                    '${value.text.length} / $kShrineWishMaxLength',
                    style: ShrineV3TextStyles.ui.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _wishController,
              maxLength: kShrineWishMaxLength,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '예) 올해 안에 좋은 사람을 만나기를',
                filled: true,
                fillColor: ShrineV3Colors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ShrineV3Colors.line),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ShrineV3Colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShrineV3Colors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.realName ?? '회원 정보 미등록',
                          style: ShrineV3TextStyles.body.copyWith(fontSize: 13),
                        ),
                        Text(
                          user?.birthDate != null
                              ? '${user!.birthDate} · 사주 연동'
                              : '실명 · 생년월일 입력이 필요해요',
                          style: ShrineV3TextStyles.ui.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    user?.realName != null
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: user?.realName != null
                        ? ShrineV3Colors.jade
                        : ShrineV3Colors.seal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _submit(k),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShrineV3Colors.seal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('민세레나에게 부탁하기 ›'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '프리패스 · 복주머니 · 광고 중 하나로 열 수 있어요',
                style: ShrineV3TextStyles.ui.copyWith(
                  fontSize: 11,
                  color: ShrineV3Colors.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String icon, String title) => Row(
    children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ShrineV3Colors.seal,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          icon,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      const SizedBox(width: 8),
      Text(title, style: ShrineV3TextStyles.body.copyWith(fontSize: 14)),
    ],
  );

  Widget _section(String icon, String title, String body) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(icon, title),
        const SizedBox(height: 6),
        Text(body, style: ShrineV3TextStyles.ui.copyWith(fontSize: 13)),
      ],
    ),
  );

  Widget _listSection(String icon, String title, List<String> items) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(icon, title),
        const SizedBox(height: 6),
        ...items.map(
          (x) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '· $x',
              style: ShrineV3TextStyles.ui.copyWith(fontSize: 13),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _orderedSection(String icon, String title, List<String> items) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(icon, title),
            const SizedBox(height: 6),
            ...items.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${e.key + 1}. ${e.value}',
                  style: ShrineV3TextStyles.ui.copyWith(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _chipSection(String icon, String title, List<String> items) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(icon, title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (x) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: ShrineV3Colors.paperDark,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(x, style: const TextStyle(fontSize: 11.5)),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}
