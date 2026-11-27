import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../application/ad_banner_provider.dart';
import '../domain/ad_banner_model.dart';
import 'ad_script_view.dart';

/// CMS 제휴광고 배너 위젯 — admin_web `/cms/banners`에서 관리자가 등록/활성화한
/// 배너를 [position]에 맞춰 홈 화면 등에 노출한다.
///
/// - 로딩 중: 스켈레톤 표시
/// - 데이터 없음(비활성/기간외/서버오류 등): 아무것도 렌더링하지 않음(공간 차지 없이 사라짐)
/// - 여러 건: 가로 스와이프 캐러셀(PageView)로 표시, sortOrder 오름차순
/// - 탭 시: linkUrl이 있으면 외부 브라우저로 제휴 링크 오픈
class AdBannerWidget extends StatefulWidget {
  final String position; // 'home_top' | 'home_middle' | 'home_bottom'

  /// [홈 하단 빈 공간 보완] CMS에 활성 배너가 없을 때(비활성/기간외/서버오류 등)
  /// 표시할 대체 위젯. `LuckyNumberWidget`의 fallback 패턴을 그대로 재사용한다.
  /// 지정하지 않으면 기존 동작대로 공간을 차지하지 않고 사라진다(SizedBox.shrink).
  final Widget? fallback;

  const AdBannerWidget({super.key, required this.position, this.fallback});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdBannerProvider>().load(widget.position);
    });
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (kDebugMode && !launched) {
      debugPrint('[AdBannerWidget] 링크 오픈 실패 -> $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdBannerProvider>();
    final isLoading = provider.isLoading(widget.position);
    final banners = provider.bannersFor(widget.position);
    final error = provider.errorFor(widget.position);

    if (kDebugMode) {
      debugPrint(
        '[AdBannerWidget] build() -> position=${widget.position}, '
        'isLoading=$isLoading, count=${banners.length}, error=$error',
      );
    }

    if (isLoading && banners.isEmpty) {
      return _buildSkeleton();
    }

    // 데이터가 없으면(비활성/기간외/오류 등) fallback이 지정된 경우 이를 표시하고,
    // 없으면 기존 동작대로 공간을 차지하지 않도록 빈 위젯 반환.
    if (banners.isEmpty) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    // [사용자 요청] "힐링박스 밑에 쿠팡파트너스 박스가 힐링박스랑 가로 간격이
    // 일치했으면 좋겠어" — 활성 배너가 2개 이상이면 기존에는
    // PageController(viewportFraction: 0.94) + padEnds:false + 우측 peek용
    // padding 때문에 현재 보이는 배너 카드가 컨테이너 전체 폭의 94%만 차지하고
    // 오른쪽에 다음 카드가 살짝 미리보기(peek)되어, 위쪽 힐링 카드(항상 전체
    // 폭을 꽉 채움)와 좌우 여백이 달라 보이는 문제가 있었다. viewportFraction을
    // 1.0으로, padEnds를 true로 바꾸고 peek용 우측 padding을 제거해 배너 개수와
    // 무관하게 항상 힐링 카드와 동일하게 전체 폭을 꽉 채우도록 통일한다.
    return SizedBox(
      height: 96,
      child: banners.length == 1
          ? _BannerCard(banner: banners.first, onTap: _openLink)
          : PageView.builder(
              itemCount: banners.length,
              itemBuilder: (context, index) {
                final banner = banners[index];
                return _BannerCard(banner: banner, onTap: _openLink);
              },
            ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final AdBannerModel banner;
  final void Function(String? url) onTap;

  const _BannerCard({required this.banner, required this.onTap});

  Widget _buildMedia() {
    if (banner.isScriptAd) {
      final script = banner.adScript;
      if (script == null || script.trim().isEmpty) {
        return Container(
          color: AppColors.divider,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined),
        );
      }
      // 광고소스형: 제휴사 원본 스크립트/iframe을 그대로 렌더링(Web=DOM 오버레이,
      // Android/iOS=WebView). 탭 이벤트는 광고소스 내부 링크에 맡기고, 카드 자체의
      // onTap(linkUrl)은 스크립트형에서는 보조 수단으로만 동작한다.
      return IgnorePointer(
        ignoring: false,
        child: buildAdScriptView(script, height: 96),
      );
    }
    return Image.network(
      banner.imageUrl ?? '',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          '[AdBannerWidget] 이미지 로드 실패 -> id=${banner.id}, url=${banner.imageUrl}, error=$error',
        );
        return Container(
          color: AppColors.divider,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.divider,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: banner.isScriptAd ? null : () => onTap(banner.linkUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(),
            if (!banner.isScriptAd)
              Positioned(
                left: 12,
                bottom: 10,
                right: 12,
                child: Text(
                  banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
