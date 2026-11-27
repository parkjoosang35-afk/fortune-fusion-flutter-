import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../domain/admob_ad_ids.dart';

/// [애드몹 테스트 연동] 구글 공식 테스트 Ad Unit ID로 표시하는 배너 광고.
///
/// 홈 화면 최하단(열림패스 고정바 위)에 배치해, 실제 서비스 화면 흐름을
/// 건드리지 않으면서 "애드몹이 정상적으로 붙어서 광고가 뜨는지"만
/// 확인하는 용도다. 기존 CMS 제휴광고([AdBannerWidget], home_middle 슬롯)와는
/// 완전히 별개의 위젯이며, 이 배너가 노출되지 않아도(로드 실패 등) 기존
/// 화면 레이아웃에는 영향이 없다(로드 성공 전까지는 공간을 차지하지 않음).
///
/// Web 플랫폼은 google_mobile_ads SDK 자체를 지원하지 않으므로 아무것도
/// 렌더링하지 않는다(SizedBox.shrink) — 이 위젯을 web에서 써도 크래시 없이
/// 안전하게 무시된다.
class AdmobTestBanner extends StatefulWidget {
  const AdmobTestBanner({super.key});

  @override
  State<AdmobTestBanner> createState() => _AdmobTestBannerState();
}

class _AdmobTestBannerState extends State<AdmobTestBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (AdmobAdIds.isSupportedPlatform) {
      _loadBanner();
    }
  }

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: AdmobAdIds.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('[AdmobTestBanner] 배너 로드 실패 -> $error');
          }
          ad.dispose();
          if (mounted) setState(() => _isLoaded = false);
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdmobAdIds.isSupportedPlatform || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      margin: const EdgeInsets.only(bottom: 8),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
