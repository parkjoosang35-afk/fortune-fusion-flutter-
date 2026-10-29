// 신통방통 소원방 · 390×844 기준 캔버스를 화면 크기에 맞춰 스케일하는 공용 래퍼.
// docs/FLUTTER_DETAIL.md §7: "기준 캔버스 390×844 → FittedBox/Transform.scale(screenW/390)로
// 기기 폭에 맞춤". RoomScene 및 각 SCR 화면의 방 장면 배경에 공통으로 사용한다.
//
// [반응형 화면 규격 통일 — 잘림 현상 수정, 공통 원인 ①] 기존엔 `scale`을 화면
// "폭" 기준으로만 계산해 세로(844)는 디자인 고정값을 그대로 썼다. 디자인
// 기준 비율(390:844, 세로로 긴 기기)보다 화면비가 짧은 대부분의 안드로이드
// 기기(18:9·19:9·20:9 등)에서는 폭에 맞춰 키운 캔버스의 실제 렌더링 높이가
// 화면의 가용 높이를 초과했고, 그 초과분을 `ClipRect`가 그대로 잘라버렸다
// — 소원방 메인화면의 "정성 버튼"(하단 도크, 디자인 기준 top:690)처럼 캔버스
// 하단부에 배치된 핵심 버튼이 가장 먼저 잘리는 구조였다. 폭과 높이 각각의
// 스케일 중 더 작은 값을 쓰면(표준 `BoxFit.contain`과 동일한 원리) 캔버스
// 전체가 항상 화면 안에 들어오고, 디자인 비율과 다른 화면에서는 잘림 대신
// 좌우(또는 하단)에 균등한 여백이 생긴다 — 디자인·색상·좌표·애니메이션은
// 전혀 바꾸지 않고 "화면에 맞추는 비율 계산 방식"만 보정한 것이다.
//
// [추가 수정 — OverflowBox 정렬 누락] 기존 코드는 `OverflowBox`에 alignment를
// 지정하지 않아 기본값(Alignment.center)이 적용됐다. 844(고정 높이) 자식을
// 실제 가용 높이 한가운데에 정렬하면, 가용 높이가 844보다 작은 화면에서는
// 캔버스 "위쪽"이 화면 밖으로 밀려 올라가 상단 UI(상태바 쪽 NavPill 등)가
// 보이지 않는 추가 문제가 있었다(위젯 테스트로 실측 확인:
// 360×720에서 top 마커가 화면 상단보다 62px 위에 가려짐). 아래
// `Transform.scale`과 동일하게 topCenter로 맞춰 캔버스 "상단"이 항상 화면
// 상단에 고정되도록 한다 — 스케일을 min()으로 보정한 것과 합쳐야 상단·하단
// 어느 쪽도 잘리지 않는다.
import 'dart:math' as math;
import 'package:flutter/material.dart';

const double wrCanvasW = 390, wrCanvasH = 844;

/// 주어진 가용 영역(size)에 390×844 캔버스를 잘림 없이 맞추기 위한 배율.
/// [WrCanvasScaler]와 동일한 좌표계를 쓰는 다른 위젯(예: 꾸미기 화면의 드래그
/// 배치 좌표, 격자 배경 간격 계산)도 반드시 이 함수로 배율을 구해야
/// WrCanvasScaler가 실제로 그리는 캔버스와 좌표가 어긋나지 않는다.
double wrCanvasScaleFor(Size size) =>
    math.min(size.width / wrCanvasW, size.height / wrCanvasH);

/// 390×844 Stack을 화면 크기에 맞춰 스케일해 보여준다. 폭/높이 중 더 작은
/// 배율을 적용해(= `BoxFit.contain`과 동일한 원리) 캔버스가 잘리지 않고
/// 항상 전체가 화면 안에 보이도록 한다(디자인 비율과 다른 화면에서는 대신
/// 좌우 또는 하단에 균등한 여백이 생긴다).
class WrCanvasScaler extends StatelessWidget {
  const WrCanvasScaler({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final scale = wrCanvasScaleFor(Size(c.maxWidth, c.maxHeight));
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: wrCanvasW, maxWidth: wrCanvasW, minHeight: wrCanvasH, maxHeight: wrCanvasH,
          child: Transform.scale(scale: scale, alignment: Alignment.topCenter, child: child),
        ),
      );
    });
  }
}
