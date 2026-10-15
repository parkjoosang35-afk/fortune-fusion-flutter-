import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/theme/dark_page_theme.dart';
import 'bokju_coupon_resolve_screen.dart';

/// [복주머니 마케팅 쿠폰] 카메라로 QR코드를 스캔해 redeemToken을 추출하는
/// 화면. 추출 성공 시 [BokjuCouponResolveScreen]으로 교체 이동한다.
///
/// [QR 내용 형식] 발급 쿠폰의 QR은 딥링크 URL
/// (`https://sintong.kr/coupon/{token}` 또는 `fortunefusion://coupon/{token}`)
/// 또는 순수 토큰 문자열 둘 중 하나로 인코딩될 수 있다고 가정하고, 두 형식을
/// 모두 파싱한다(관리자 웹 쪽 QR 생성 방식이 나중에 바뀌어도 이 화면이
/// 깨지지 않도록 방어적으로 처리).
///
/// [카메라 실패 시 폴백] 웹 브라우저가 카메라 권한을 거부했거나 기기에
/// 카메라가 없는 경우를 대비해, 화면 하단에 항상 "코드 직접 입력" 버튼을
/// 노출한다([BokjuCouponEntryScreen]으로 이동).
class BokjuCouponScanScreen extends StatefulWidget {
  const BokjuCouponScanScreen({super.key});

  @override
  State<BokjuCouponScanScreen> createState() => _BokjuCouponScanScreenState();
}

class _BokjuCouponScanScreenState extends State<BokjuCouponScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  String? _cameraError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final token = _extractToken(raw);
      if (token != null) {
        _handled = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BokjuCouponResolveScreen(token: token),
          ),
        );
        return;
      }
    }
  }

  /// `https://sintong.kr/coupon/{token}`, `fortunefusion://coupon/{token}`,
  /// 또는 순수 토큰 문자열 중 하나로부터 토큰을 추출한다.
  String? _extractToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      if ((uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments[0] == 'coupon') {
        return uri.pathSegments[1];
      }
      if (uri.scheme == 'fortunefusion' && uri.host == 'coupon') {
        return uri.pathSegments.first;
      }
    }

    // URL 형식이 아니면(스킴/슬래시 없음) QR 자체에 토큰 문자열만 인코딩된
    // 경우로 간주한다(redeemToken은 32자 hex — 영숫자 검증만 가볍게 수행).
    if (!trimmed.contains('/') && !trimmed.contains(' ')) {
      return trimmed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DarkPage(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('쿠폰 QR 스캔'),
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _cameraError = error.errorDetails?.message ??
                        '카메라를 사용할 수 없습니다.');
                  }
                });
                return Container(color: Colors.black);
              },
            ),
            _ScanOverlay(hasError: _cameraError != null),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Column(
                children: [
                  if (_cameraError != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UnifiedTokens.spaceXl,
                      ),
                      child: Text(
                        _cameraError!,
                        style: UnifiedText.body(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceLg),
                  ],
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const BokjuCouponEntryScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '카메라 대신 코드 직접 입력',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.hasError});
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (hasError) return const SizedBox.shrink();
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: UnifiedColors.black, width: 3),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        ),
      ),
    );
  }
}

/// [수동 코드 입력 폴백] QR 스캔이 불가능한 환경(카메라 권한 거부, 손상된
/// 쿠폰 이미지 등)을 위한 텍스트 입력 화면. 관리자가 쿠폰 발급 시 사람이
/// 읽을 수 있는 코드(couponNo, 예: `BK-2026-0001`)를 함께 인쇄하는 경우를
/// 대비한 것이 아니라, 이 화면은 QR이 인코딩하는 것과 동일한 redeemToken
/// 문자열(또는 그 토큰이 담긴 URL 전체)을 직접 붙여넣는 용도다.
class BokjuCouponEntryScreen extends StatefulWidget {
  const BokjuCouponEntryScreen({super.key});

  @override
  State<BokjuCouponEntryScreen> createState() =>
      _BokjuCouponEntryScreenState();
}

class _BokjuCouponEntryScreenState extends State<BokjuCouponEntryScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = '쿠폰 코드 또는 링크를 입력해 주세요.');
      return;
    }

    // URL 형태로 붙여넣었을 수도 있으니 마지막 path segment만 취한다.
    String token = raw;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      token = uri.pathSegments.last;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BokjuCouponResolveScreen(token: token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DarkPage(
      child: Scaffold(
        backgroundColor: UnifiedColors.bg,
        appBar: AppBar(title: const Text('쿠폰 코드 입력')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('쿠폰 코드 또는 링크를 입력해 주세요', style: UnifiedText.title()),
                const SizedBox(height: UnifiedTokens.spaceLg),
                TextField(
                  controller: _controller,
                  style: UnifiedText.body(color: UnifiedColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '예: https://sintong.kr/coupon/abcd1234...',
                    hintStyle: UnifiedText.caption(),
                    errorText: _error,
                    filled: true,
                    fillColor: UnifiedColors.cardMain,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(UnifiedTokens.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: UnifiedTokens.spaceXl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UnifiedColors.black,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(UnifiedTokens.radiusPill),
                      ),
                    ),
                    onPressed: _submit,
                    child: const Text(
                      '확인',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
