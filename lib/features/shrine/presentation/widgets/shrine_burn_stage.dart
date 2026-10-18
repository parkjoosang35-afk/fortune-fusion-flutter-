// shrine_burn_stage.dart — burn.mp4(720×1294)를 cover 배치하고, 실측 좌표
// 위에 부적을 겹친다(신당 디자인 핸드오프 screens/ritual.dart BurnStage).
// [변경 금지 값 — 신당_개발지시서_v1.4.pdf §2] shrineBurnBox 좌표를 그대로 사용.
// 비율을 바꾸면 좌표 전부 재계산해야 하므로 로직 변경 없이 이식했다.
import 'package:flutter/widgets.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_tokens.dart';

class ShrineBurnStage extends StatelessWidget {
  final Widget paper;
  final Widget? video;
  const ShrineBurnStage({super.key, required this.paper, this.video});

  static double get ratio =>
      ((100 - shrineBurnBox.l - shrineBurnBox.r) * 720) / ((100 - shrineBurnBox.t - shrineBurnBox.b) * 1294);

  @override
  Widget build(BuildContext context) => Positioned.fill(
      child: ClipRect(
          child: OverflowBox(
              maxWidth: double.infinity,
              child: AspectRatio(
                  aspectRatio: 720 / 1294,
                  child: LayoutBuilder(builder: (_, c) => Stack(children: [
                        if (video != null)
                          Stack(children: [video!])
                        else
                          Positioned.fill(child: Image.asset('${kShrineVideoBase}burn.jpg', fit: BoxFit.cover)),
                        Positioned(
                            left: c.maxWidth * shrineBurnBox.l / 100,
                            right: c.maxWidth * shrineBurnBox.r / 100,
                            top: c.maxHeight * shrineBurnBox.t / 100,
                            bottom: c.maxHeight * shrineBurnBox.b / 100,
                            child: paper),
                      ]))))));
}
