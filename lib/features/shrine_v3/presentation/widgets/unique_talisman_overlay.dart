import 'package:flutter/material.dart';

import '../../domain/shrine_order.dart';
import '../theme/shrine_v3_theme.dart';

/// 唯一(unique) 부적 오버레이 — README/HTML 프로토타입의 `UOver`/`Uniq`를
/// Flutter로 옮긴 것. 부적 이미지 위에 "이름 + 사주(세로쓰기)"와
/// "神堂 + 일련번호" 도장을 겹쳐 그린다.
///
/// [서버 전담 원칙] 여기 표시하는 이름/사주/일련번호는 전부
/// [ShrineOrder]에 이미 담겨 있는 서버 계산값을 그대로 쓸 뿐, 이 위젯이
/// 직접 계산하는 값은 하나도 없다. 07(받기 연출)/08(결과)/10(부적함 상세)
/// 세 화면이 공용으로 재사용한다(README §6 "이 부적에만 새겨진 기록"
/// 5곳 중 확대보기/저장 이미지를 제외한 화면 표시 3곳).
class UniqueTalismanOverlay extends StatelessWidget {
  const UniqueTalismanOverlay({
    super.key,
    required this.order,
    required this.width,
    this.height,
    this.useThumb = false,
  });

  final ShrineOrder order;
  final double width;
  final double? height;

  /// true면 thumbPath(없으면 imagePath), false면 항상 imagePath(원본)를 쓴다.
  final bool useThumb;

  @override
  Widget build(BuildContext context) {
    final t = order.talisman;
    final path = useThumb && t.thumbPath != null ? t.thumbPath! : t.imagePath;
    final h = height ?? width * 2.3;
    final fontSize = (width * 0.085).clamp(7.0, 13.0);

    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/shrine_v3/$path',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: ShrineV3Colors.paperDark,
                alignment: Alignment.center,
                child: Text(
                  t.hanja,
                  style: ShrineV3TextStyles.title.copyWith(
                    fontSize: width * 0.4,
                    color: ShrineV3Colors.seal,
                  ),
                ),
              ),
            ),
          ),
          // 이름 + 사주 세로쓰기 — 오른쪽 가장자리.
          Positioned(
            right: width * 0.06,
            top: h * 0.18,
            child: _VerticalText(
              name: order.ownerName,
              sajuCompact: order.sajuPillars.replaceAll(' ', ''),
              fontSize: fontSize,
            ),
          ),
          // 일련번호 도장 — 좌측 하단, 살짝 기울임.
          Positioned(
            left: width * 0.08,
            bottom: h * 0.06,
            child: Transform.rotate(
              angle: -0.1,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.09,
                  vertical: width * 0.05,
                ),
                decoration: BoxDecoration(
                  color: ShrineV3Colors.gold.withValues(alpha: 0.85),
                  border: Border.all(color: ShrineV3Colors.seal, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '神堂',
                      style: TextStyle(
                        color: ShrineV3Colors.seal,
                        fontFamily: 'NotoSerifKR',
                        fontWeight: FontWeight.w900,
                        fontSize: fontSize,
                      ),
                    ),
                    Text(
                      order.serial.replaceFirst('神堂 ', ''),
                      style: TextStyle(
                        color: ShrineV3Colors.seal,
                        fontFamily: 'NotoSerifKR',
                        fontWeight: FontWeight.w800,
                        fontSize: fontSize * 0.85,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalText extends StatelessWidget {
  const _VerticalText({
    required this.name,
    required this.sajuCompact,
    required this.fontSize,
  });

  final String name;
  final String sajuCompact;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.5, vertical: 6),
      decoration: BoxDecoration(
        color: ShrineV3Colors.gold.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final ch in name.characters)
            Text(
              ch,
              style: TextStyle(
                color: ShrineV3Colors.seal,
                fontFamily: 'GowunBatang',
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                height: 1.25,
              ),
            ),
          SizedBox(height: fontSize * 0.5),
          for (final ch in sajuCompact.characters)
            Text(
              ch,
              style: TextStyle(
                color: ShrineV3Colors.seal,
                fontFamily: 'NotoSerifKR',
                fontWeight: FontWeight.w800,
                fontSize: fontSize * 0.9,
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}

/// 10 화면("이 부적에만 새겨진 기록" 카드) 전용 — README/HTML `URec`을
/// Flutter 카드로 옮긴 것.
class UniqueRecordCard extends StatelessWidget {
  const UniqueRecordCard({super.key, required this.order});
  final ShrineOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShrineV3Colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShrineV3Colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('唯一', style: ShrineV3TextStyles.title.copyWith(fontSize: 14, color: ShrineV3Colors.seal)),
              const SizedBox(width: 6),
              Text('이 부적에만 새겨진 기록', style: ShrineV3TextStyles.body.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          _row('이름', order.ownerName),
          _row('사주 팔자', order.sajuPillars),
          _row('담은 소망', order.wish),
          _row('지은 날', order.issuedDateKey),
          _row('일련번호', order.serial),
          const SizedBox(height: 8),
          Text(
            '같은 ${order.talisman.name}라도 이름 · 사주 · 소망 · 날짜 · 번호가 겹치지 않아 세상에 한 장뿐이에요.',
            style: ShrineV3TextStyles.ui.copyWith(fontSize: 11.5, color: ShrineV3Colors.ink3),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(label, style: ShrineV3TextStyles.ui.copyWith(fontSize: 12))),
        Expanded(child: Text(value, style: ShrineV3TextStyles.body.copyWith(fontSize: 13))),
      ],
    ),
  );
}
