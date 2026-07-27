import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../application/lucky_number_provider.dart';
import '../domain/lucky_number_model.dart';
import '../../ad_banner/presentation/ad_script_view.dart';

/// "오늘의 행운숫자" 관리자 콘텐츠 위젯.
///
/// [사용자 요청] "오늘의 행운숫자 섹션은 꼭 광고을 아니 하던것 진핼해" — AdBannerWidget과
/// 구조는 유사하지만(로딩스켈레톤/빈상태 패턴 참고) "AD" 뱃지를 포함하지 않으며, 광고
/// Provider/Repository와 완전히 분리된 별도 구현이다. 관리자 콘텐츠가 없으면 null을
/// 반환하듯 동작하도록 [fallback]을 반드시 제공해야 한다(호출부에서 기존 숫자 UI로 폴백).
class LuckyNumberWidget extends StatefulWidget {
  final Widget fallback;
  final double height;
  const LuckyNumberWidget({super.key, required this.fallback, this.height = 160});

  @override
  State<LuckyNumberWidget> createState() => _LuckyNumberWidgetState();
}

class _LuckyNumberWidgetState extends State<LuckyNumberWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LuckyNumberProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LuckyNumberProvider>();

    if (kDebugMode) {
      debugPrint(
        '[LuckyNumberWidget] build() -> isLoading=${provider.isLoading}, '
        'hasContent=${provider.hasContent}, hasLoaded=${provider.hasLoaded}',
      );
    }

    // 아직 최초 로딩이 끝나지 않았으면 스켈레톤 표시.
    if (provider.isLoading && !provider.hasLoaded) {
      return _buildSkeleton();
    }

    // 관리자 콘텐츠가 없으면(비활성/미등록/오류) 기존 폴백 UI(숫자 표시)를 그대로 사용.
    if (!provider.hasContent) {
      return widget.fallback;
    }

    return _LuckyNumberCard(content: provider.content!, height: widget.height);
  }

  Widget _buildSkeleton() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _LuckyNumberCard extends StatefulWidget {
  final LuckyNumberModel content;
  final double height;
  const _LuckyNumberCard({required this.content, required this.height});

  @override
  State<_LuckyNumberCard> createState() => _LuckyNumberCardState();
}

class _LuckyNumberCardState extends State<_LuckyNumberCard> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.content.isVideo && (widget.content.videoUrl?.isNotEmpty ?? false)) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.content.videoUrl!),
      )
        ..setLooping(true)
        ..setVolume(0)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController?.play();
          }
        }).catchError((e) {
          debugPrint('[LuckyNumberWidget] 영상 초기화 실패 -> $e');
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildMedia() {
    final content = widget.content;
    if (content.isScript) {
      final script = content.script;
      if (script == null || script.trim().isEmpty) {
        return _buildErrorPlaceholder();
      }
      return buildAdScriptView(script, height: widget.height);
    }
    if (content.isVideo) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return Container(
          color: AppColors.divider,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }
    return Image.network(
      content.imageUrl ?? '',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
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

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppColors.divider,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(),
            if (content.caption != null && content.caption!.trim().isNotEmpty)
              Positioned(
                left: 12,
                bottom: 10,
                right: 12,
                child: Text(
                  content.caption!,
                  maxLines: 2,
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
          ],
        ),
      ),
    );
  }
}
