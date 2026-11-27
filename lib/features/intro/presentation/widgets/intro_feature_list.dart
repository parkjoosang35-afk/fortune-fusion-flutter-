import 'package:flutter/material.dart';
import '../../domain/intro_config_model.dart';
import '../intro_palette.dart';
import '../intro_text_styles.dart';

/// [핸드오프 콘텐츠 반영 - 신규] 페이지3(귀인지도) `.feature-list` — 貴/緣/符
/// 3개 행. 각 행은 순서대로 0.5s/0.7s/0.9s 지연 후 fade+slide-up 되는
/// `feat-in` 애니메이션을 그대로 재현한다(`AnimatedOpacity`+`AnimatedSlide`
/// 조합, `TweenAnimationBuilder`로 지연 시작).
class IntroFeatureList extends StatelessWidget {
  final List<IntroFeatureItem> items;

  const IntroFeatureList({super.key, required this.items});

  static const List<Duration> _delays = [
    Duration(milliseconds: 500),
    Duration(milliseconds: 700),
    Duration(milliseconds: 900),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _FeatureRow(
            item: items[i],
            delay: i < _delays.length ? _delays[i] : Duration.zero,
          ),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatefulWidget {
  final IntroFeatureItem item;
  final Duration delay;

  const _FeatureRow({required this.item, required this.delay});

  @override
  State<_FeatureRow> createState() => _FeatureRowState();
}

class _FeatureRowState extends State<_FeatureRow> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x0FC8B4FF), // rgba(200,180,255,0.06)
            border: Border.all(color: const Color(0x26DCC8FF)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: IntroPalette.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: IntroPalette.primary.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.item.icon,
                  style: IntroTextStyles.featureIcon(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: IntroTextStyles.featureTitle(),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.item.description,
                      style: IntroTextStyles.featureDesc(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
