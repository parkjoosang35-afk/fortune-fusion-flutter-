import 'package:web/web.dart' as web;

/// [웹 AdSense 광고 시스템] 페이지 레벨 광고(Anchor/Vignette) 활성화 —
/// Web 구현.
///
/// [배경] Anchor ads(화면 상/하단에 고정되는 띠 배너)와 Vignette ads
/// (페이지 전환 사이 전면 광고)는 개별 `<ins>` 슬롯이 아니라, 로더
/// 스크립트에 "이 타입의 페이지 레벨 광고를 켜 달라"고 1회 설정을
/// push하는 방식으로 동작한다(Google AdSense Auto ads 표준 패턴).
/// `enable_page_level_ads: true` + `overlays: {bottom: 'true'}` 형태의
/// 설정 객체를 `adsbygoogle` 큐에 push한다.
///
/// [중복 방지] 같은 adType으로 두 번 push하면 콘솔 경고가 발생하므로,
/// 타입별로 1회만 호출되도록 상위([WebAdService])가 보장해야 하지만,
/// 이 파일 레벨에서도 Set으로 한 번 더 방어한다.
final Set<String> _enabledTypes = {};

void enablePageLevelAdsOnce(String publisherId, String adType) {
  if (publisherId.isEmpty) return;
  if (_enabledTypes.contains(adType)) return;
  _enabledTypes.add(adType);

  // overlays 설정 키는 adType에 따라 다르다: anchor → {bottom:'true'},
  // vignette는 별도 overlays 없이 enable_page_level_ads만으로 충분하다
  // (Google 표준 Auto ads 페이지 레벨 설정 — anchor/vignette 모두 같은
  // enable_page_level_ads 큐에 push하지만 anchor는 추가로 overlays 힌트를
  // 줄 수 있다).
  final overlaysJs = adType == 'anchor' ? ", overlays: {bottom: 'true'}" : '';

  final script = web.document.createElement('script')
      as web.HTMLScriptElement
    ..text =
        '(window.adsbygoogle = window.adsbygoogle || []).push('
        '{google_ad_client: "$publisherId", enable_page_level_ads: true$overlaysJs}'
        ');';
  web.document.head?.appendChild(script);
}
