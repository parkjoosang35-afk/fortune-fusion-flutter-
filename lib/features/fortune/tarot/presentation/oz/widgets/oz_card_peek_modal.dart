import 'dart:math';
import 'package:flutter/material.dart';

import '../../../domain/tarot_card_assets.dart';
import '../oz_theme.dart';
import '../tarot_spread_deck.dart';
import 'oz_card_spread.dart' show OzFaceDownCardArt;

/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1a] 5장 완성 후 남은 카드를
/// 탭했을 때 확대해서 보여주는 엿보기 모달. CSS 대응:
/// `<CardPeekModal>`(TarotApp.jsx).
///
/// [순수 장식] 여기서 보여주는 이름/키워드는 실제 사용자가 뽑은 5장의
/// 정체와 무관하다(이미 5장을 다 골랐으므로 이 카드는 애초에 선택 대상이
/// 아니다). 그냥 "이런 느낌의 카드였구나" 재미를 위한 연출.
class OzCardPeekModal extends StatefulWidget {
  final TarotSpreadCardMeta meta;
  final VoidCallback onClose;
  const OzCardPeekModal({super.key, required this.meta, required this.onClose});

  @override
  State<OzCardPeekModal> createState() => _OzCardPeekModalState();
}

class _OzCardPeekModalState extends State<OzCardPeekModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _flip;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _flip.forward();
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: const Color(0xD90A0514),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PEEK · ${_peekCode(meta)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      letterSpacing: 3,
                      color: OzColors.gold.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 200,
                    height: 300,
                    child: AnimatedBuilder(
                      animation: _flip,
                      builder: (context, _) {
                        final angle = _flip.value * pi;
                        final showFront = angle > pi / 2;
                        final transform = Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateY(angle);
                        return Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: OzColors.gold.withValues(alpha: 0.35),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: transform,
                            child: showFront
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()..rotateY(pi),
                                    child: _PeekFront(meta: meta),
                                  )
                                : const ClipRRect(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                    child: OzFaceDownCardArt(),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    meta.name,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: OzColors.fg,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta.en,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: OzColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: OzColors.goldDeep),
                    ),
                    child: Text(
                      '◇ ${meta.keyword} ◇',
                      style: TextStyle(fontSize: 12, color: OzColors.gold),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                child: Text(
                  'TAP TO CLOSE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 3,
                    color: OzColors.muted,
                  ),
                ),
              ),
              Positioned(
                top: -10,
                right: -6,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: OzColors.goldDeep),
                    ),
                    child: Icon(Icons.close, size: 18, color: OzColors.fg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _peekCode(TarotSpreadCardMeta meta) {
    if (meta.id < 22) return meta.id.toString().padLeft(3, '0');
    return meta.id.toString().substring(max(0, meta.id.toString().length - 3));
  }
}

class _PeekFront extends StatelessWidget {
  final TarotSpreadCardMeta meta;
  const _PeekFront({required this.meta});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: const Color(0xFFF4ECD8),
        child: Image.asset(
          tarotCardImagePath(meta.name),
          width: 200,
          height: 300,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              meta.symbol,
              style: TextStyle(fontSize: 64, color: OzColors.goldDeep),
            ),
          ),
        ),
      ),
    );
  }
}
