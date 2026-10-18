// shrine_rite_rail.dart — 상단 레일 2종.
// 신당 디자인 핸드오프를 그대로 이식했다(두 레일은 서로 다른 표기 체계라
// 하나로 합치지 않고 원본 그대로 분리 유지):
//  · ShrinePhaseRail — ritual.dart PhaseRail. write/paper/burn/reveal/read
//    4화면 전용, 하드코딩된 '筆符示讀' 4글자(0=筆 write, 1=符 paper·burn,
//    2=示 reveal, 3=讀 read).
//  · ShrineRiteRail — receive.dart RiteRail. shrineRiteSteps(診寫奉示受用
//    6단계) 데이터를 그대로 사용, receive/use 화면 전용(at=4/5).
import 'package:flutter/widgets.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_tokens.dart';

class ShrinePhaseRail extends StatelessWidget {
  final int i;
  const ShrinePhaseRail(this.i, {super.key});
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < 4; k++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              '筆符示讀'[k],
              style: ShrineType.display(13, c: k == i ? ShrineColor.gold : k < i ? ShrineColor.muted : ShrineColor.faint)
                  .copyWith(shadows: k == i ? const [Shadow(color: Color(0x99C9A368), blurRadius: 12)] : null),
            ),
          ),
      ]);
}

class ShrineRiteRail extends StatelessWidget {
  final int at;
  const ShrineRiteRail(this.at, {super.key});
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shrineRiteSteps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.5),
            child: Text(
              shrineRiteSteps[i].k,
              style: ShrineType.display(12.5, c: i == at ? ShrineColor.gold : i < at ? const Color(0x80EFE4D2) : ShrineColor.faint)
                  .copyWith(shadows: i == at ? const [Shadow(color: Color(0xB3C9A368), blurRadius: 12)] : null),
            ),
          ),
      ]);
}
