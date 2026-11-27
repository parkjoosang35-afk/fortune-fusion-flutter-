import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../mypage/presentation/theme/mypage_minimal_theme.dart';
import '../application/bokju_coupon_provider.dart';
import 'bokju_coupon_resolve_screen.dart';
import 'bokju_coupon_scan_screen.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S05] "쿠폰 등록" 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S05 쿠폰 등록" 스펙에 따른
/// **직접 입력을 기본으로** 하는 신규 화면이다(§3-2 매핑표: "지갑 > 쿠폰
/// 등록하기(QR 스캔 → 카메라 오류 시 직접 입력)" → "S03 강조 카드 ② → S05
/// — 직접 입력을 기본으로, QR은 보조 버튼"). 기존 플로우는 QR 스캔이
/// 기본이고 카메라 실패 시에만 텍스트 입력([BokjuCouponEntryScreen])으로
/// 폴백했지만, 이 화면은 순서를 뒤집어 코드 입력창을 전면에 두고 QR 스캔은
/// "◫ QR 코드로 스캔하기" 보조 버튼으로 내린다.
///
/// [로직은 그대로] 입력받은 코드로 실제 조회/등록을 수행하는 로직은 기존
/// [BokjuCouponProvider]/[BokjuCouponRepository]를 그대로 재사용한다 —
/// `resolve(token)` → `redeem()` 2단계 흐름과 서버 응답 처리(멱등키, 지갑
/// 재조회 등)는 한 줄도 바꾸지 않았다. 다만 README §S05는 "입력 즉시
/// 등록"(미리보기 화면 생략) UX를 요구하므로, 이 화면 자체에서
/// `loadPreview()` → `redeem()`을 순차 호출해 기존 2단계 화면
/// ([BokjuCouponResolveScreen]의 미리보기 카드 + "등록하기" 버튼)을 거치지
/// 않고 바로 결과를 반환한다(QR 스캔 경로는 기존과 동일하게
/// [BokjuCouponResolveScreen] 미리보기를 거친다 — 스캔한 쿠폰은 사용자가
/// 등록 전에 캠페인명/지급액을 확인할 기회가 이미 README §3-2에서 유지되는
/// "QR은 보조 버튼" 흐름의 일부이기 때문).
class BokjuCouponEntryMinimalScreen extends StatefulWidget {
  const BokjuCouponEntryMinimalScreen({super.key});

  @override
  State<BokjuCouponEntryMinimalScreen> createState() =>
      _BokjuCouponEntryMinimalScreenState();
}

class _BokjuCouponEntryMinimalScreenState
    extends State<BokjuCouponEntryMinimalScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 화면 재진입 시 이전 흐름(QR 스캔 경로 등)이 남긴 상태를 비운다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BokjuCouponProvider>().reset();
    });
    _controller.addListener(() {
      // CTA 활성/비활성(6자 이상)만 반영하면 되므로 setState만 호출한다.
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().length >= 6 && !_submitting;

  // URL 형태로 붙여넣었을 수도 있으니 마지막 path segment만 취한다
  // (기존 [BokjuCouponEntryScreen]._submit()과 동일한 방어 로직).
  String _extractToken(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return trimmed;
  }

  // README §S05: CTA "등록하기" — 6자 이상 입력해야 활성. 입력 즉시
  // resolve → redeem 순으로 호출해 바로 결과(성공/실패)를 반환한다.
  Future<void> _submit() async {
    if (!_canSubmit) return;
    final token = _extractToken(_controller.text);
    final provider = context.read<BokjuCouponProvider>();

    setState(() => _submitting = true);
    await provider.loadPreview(token);
    if (!mounted) return;

    if (provider.status == BokjuCouponFlowStatus.error) {
      setState(() => _submitting = false);
      _showErrorToast(provider.errorCode, provider.errorMessage);
      return;
    }

    final preview = provider.preview;
    if (preview == null || !preview.redeemable) {
      setState(() => _submitting = false);
      _showErrorToast(null, preview?.reasonIfNot ?? '쿠폰 코드를 다시 확인해 주세요.');
      return;
    }

    final ok = await provider.redeem();
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      _showErrorToast(provider.errorCode, provider.errorMessage);
      return;
    }

    final result = provider.result;
    if (result == null) return;
    // README §S05: 성공 → 토스트 "복주머니 N개가 담겼어요" + 뒤로가기 +
    // 잔액 갱신(redeem() 내부에서 이미 WalletProvider.load() 호출됨).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('복주머니 ${result.grantedAmount}개가 담겼어요')),
    );
    Navigator.of(context).pop();
  }

  // README §S05: 실패 → 토스트 "쿠폰 코드를 다시 확인해 주세요"
  // (USED: "이미 사용한 쿠폰이에요", EXPIRED: "기간이 지난 쿠폰이에요").
  void _showErrorToast(String? code, String? fallback) {
    final message = switch (code) {
      'ALREADY_USED' || 'COUPON_ALREADY_USED' => '이미 사용한 쿠폰이에요',
      'EXPIRED' => '기간이 지난 쿠폰이에요',
      _ => fallback ?? '쿠폰 코드를 다시 확인해 주세요',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openQrScan() async {
    // README §3-2: "QR은 보조 버튼". 기존 QR 스캔 화면을 그대로 재사용한다
    // (카메라 권한 오류 시 토스트로 안내하는 로직도 기존 그대로 — 아래
    // BokjuCouponScanScreen 참고). 스캔 성공 시 해당 화면이 이미
    // BokjuCouponResolveScreen으로 교체 이동하므로, 이 화면은 그 결과를
    // 기다리지 않고 그대로 둔다(스캔 플로우는 독립적으로 완결됨).
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BokjuCouponScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MyPageSpacing.subX,
                  6,
                  MyPageSpacing.subX,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // README §S05: 히어로 타이틀 26px/800/-0.03em 2줄.
                    const Text(
                      '받은 쿠폰 코드를\n적어 주세요',
                      style: MyPageTextStyles.display,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '등록하면 복주머니가 바로 담겨요',
                      style: MyPageTextStyles.body,
                    ),
                    const SizedBox(height: 36),
                    _buildCodeField(),
                    const SizedBox(height: 16),
                    _buildQrButton(),
                    const SizedBox(height: 28),
                    _buildNotice(),
                  ],
                ),
              ),
            ),
            _buildDock(),
          ],
        ),
      ),
    );
  }

  // README "서브화면 공통 셸" 상단바: padding 52 12 10, grid 44 1fr 44.
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 40,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: MyPageColors.ink,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '쿠폰 등록',
              textAlign: TextAlign.center,
              style: MyPageTextStyles.header,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // README §S05: 입력은 밑줄형 1.5px. 포커스 시 --mp-red. IBM Plex Mono
  // 20px, 대문자, letter-spacing .3em, 최대 12자, placeholder SINTONG2026.
  Widget _buildCodeField() {
    return AnimatedBuilder(
      animation: _focusNode,
      builder: (context, child) {
        final focused = _focusNode.hasFocus;
        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: focused ? MyPageColors.red : MyPageColors.hair,
                width: 1.5,
              ),
            ),
          ),
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            maxLength: 12,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_UpperCaseTextFormatter()],
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
              fontFamily: MyPageFonts.mono,
              fontWeight: FontWeight.w500,
              fontSize: 20,
              letterSpacing: 6,
              color: MyPageColors.ink,
            ),
            decoration: const InputDecoration(
              hintText: 'SINTONG2026',
              hintStyle: TextStyle(
                fontFamily: MyPageFonts.mono,
                fontWeight: FontWeight.w500,
                fontSize: 20,
                letterSpacing: 6,
                color: MyPageColors.ink3,
              ),
              border: InputBorder.none,
              isDense: true,
              counterText: '',
            ),
          ),
        );
      },
    );
  }

  // README §S05: 보조 버튼 "◫ QR 코드로 스캔하기" (ghost, 1px hair).
  Widget _buildQrButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _openQrScan,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: MyPageColors.hair, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MyPageRadius.btn),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner_rounded,
              size: 18,
              color: MyPageColors.ink2,
            ),
            const SizedBox(width: 8),
            Text(
              'QR 코드로 스캔하기',
              style: MyPageTextStyles.row.copyWith(
                color: MyPageColors.ink2,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // README §S05: 안내 "쿠폰은 계정당 한 번만 쓸 수 있어요 / 유효기간이
  // 지난 쿠폰은 등록되지 않아요" (좌측 1px dashed). S02/S04의 공용
  // dashed 위젯은 상자 전체 테두리용이라, 여기서는 좌측 변만 필요해
  // 간단한 CustomPaint 대신 Border(left: dashed 느낌의 점선을 대체하는
  // DottedLine 위젯이 없으므로) 얇은 실선 + 낮은 opacity로 근사한다.
  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: MyPageColors.hair, width: 1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('쿠폰은 계정당 한 번만 쓸 수 있어요', style: MyPageTextStyles.caption),
          SizedBox(height: 4),
          Text('유효기간이 지난 쿠폰은 등록되지 않아요', style: MyPageTextStyles.caption),
        ],
      ),
    );
  }

  // README "서브화면 공통 셸" Dock: padding 20 22 34, CTA 폭 100%,
  // padding 16, radius 16, bg --mp-red, shadow --mp-sh-cta. 비활성:
  // bg rgba(42,31,20,.12), fg --mp-ink-3, 그림자 없음.
  Widget _buildDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            MyPageColors.paper,
            MyPageColors.paper.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: MyPageColors.red,
            disabledBackgroundColor: const Color(0x1F2A1F14),
            foregroundColor: const Color(0xFFFBF1DE),
            disabledForegroundColor: MyPageColors.ink3,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ).copyWith(
            shadowColor: WidgetStateProperty.resolveWith(
              (states) => Colors.transparent,
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFFBF1DE)),
                  ),
                )
              : const Text(
                  '등록하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

/// 입력을 항상 대문자로 강제한다(README §S05: "대문자" 표기).
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
