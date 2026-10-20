// TalismanStage — 의식 영상/사진 속 종이 위에 부적을 겹치는 좌표 스테이지 (부적 그림은 widgets/bujeok.dart)
import 'package:flutter/material.dart';

/// 부적 이미지(900×1613) 위 오버레이 배치. 좌표는 이미지 비율 기준이므로
/// 반드시 같은 비율 박스를 cover 로 깔고 그 안에서 퍼센트 배치한다.
class TalismanStage extends StatelessWidget {
  final Widget background; // img/paper.jpg 또는 burn 영상
  final Widget overlay;
  const TalismanStage({super.key, required this.background, required this.overlay});
  @override
  Widget build(BuildContext context) {
    return FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge,
      child: SizedBox(width: 900, height: 1613, child: Stack(children: [
        Positioned.fill(child: background),
        // left 25% · right 27% · top 14.5% · bottom 11.5%  — 웹 .paperzone / .burnfx 와 동일 (사진 속 종이 전체)
        Positioned(left: 900 * .25, right: 900 * .27, top: 1613 * .145, bottom: 1613 * .115, child: overlay),
      ])));
  }
}
