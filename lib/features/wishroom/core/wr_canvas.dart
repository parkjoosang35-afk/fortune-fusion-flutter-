// 신통방통 소원방 · 390×844 기준 캔버스를 화면 폭에 맞춰 스케일하는 공용 래퍼.
// docs/FLUTTER_DETAIL.md §7: "기준 캔버스 390×844 → FittedBox/Transform.scale(screenW/390)로
// 기기 폭에 맞춤". RoomScene 및 각 SCR 화면의 방 장면 배경에 공통으로 사용한다.
import 'package:flutter/material.dart';

const double wrCanvasW = 390, wrCanvasH = 844;

/// 390×844 Stack을 화면 폭 기준으로 스케일해 꽉 채운다(세로는 넘치면 클립).
class WrCanvasScaler extends StatelessWidget {
  const WrCanvasScaler({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final scale = c.maxWidth / wrCanvasW;
      return ClipRect(
        child: OverflowBox(
          minWidth: wrCanvasW, maxWidth: wrCanvasW, minHeight: wrCanvasH, maxHeight: wrCanvasH,
          child: Transform.scale(scale: scale, alignment: Alignment.topCenter, child: child),
        ),
      );
    });
  }
}
