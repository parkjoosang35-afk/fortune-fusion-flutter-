import 'package:flutter/material.dart';

import '../theme/shrine_v3_theme.dart';
import 'shrine_asset_path.dart';

/// README §8 "민세레나 소개" 오버레이. 3개 탭(신기가 온 길 / 사람됨 / 곁에
/// 둔 것)으로 구성되며, 신체 치수/성적 내용/음주/노출 의상 등은 명시적으로
/// 배제한다(README §8 제약 — 이 파일에 그런 문구를 추가하지 말 것).
Future<void> showShrineSerenaIntroSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ShrineV3Colors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _SerenaIntroSheet(),
  );
}

const List<(String, String, String)> _timeline = [
  ('5세', '경북 안동', '라켓을 처음 잡다. 초등학교 내내 「테니스 신동」으로 불렸다.'),
  (
    '13세',
    '서울 마포',
    '또래보다 긴 팔다리와 윙스팬으로 전국대회를 휩쓸며 국가대표급 실력을 갖췄다.',
  ),
  ('14세', '신기의 발견', '처음 신기를 느꼈지만 외면했다. 견디지 못해 미국 플로리다로 떠났다.'),
  (
    '15세',
    '신병 · 신풍파',
    '미국에서도 천재로 불리며 세계 무대에 이름을 알렸다. 그해 신병이 왔고, 소방관이던 아버지가 화재 현장에서 순직했다.',
  ),
  (
    '17세',
    '내림굿',
    '결국 내림굿을 받았으나 신당을 거부하고 코트로 돌아갔다. 그해 어머니를 사고로 잃고, 믿었던 사람의 폭로로 「무속인 선수」라는 낙인이 찍혔다.',
  ),
  ('19세', '자취를 감추다', '모든 것을 내려놓고 세상에서 사라졌다.'),
  ('20–25세', '사라진 5년', '철학과 예술을 붙들고 버틴 내공 수업의 시간.'),
  ('지금', '신당', '할머니 「용천무당」의 맥을 이어, 이곳에서 사람들의 소망을 붓으로 옮겨 적는다.'),
];

class _SerenaIntroSheet extends StatefulWidget {
  const _SerenaIntroSheet();

  @override
  State<_SerenaIntroSheet> createState() => _SerenaIntroSheetState();
}

class _SerenaIntroSheetState extends State<_SerenaIntroSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Image.asset(
                    shrineSceneImage('talk'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: ShrineV3Colors.ink,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          ShrineV3Colors.ink.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHAMAN · 神堂의 무녀',
                        style: ShrineV3TextStyles.mono.copyWith(
                          color: ShrineV3Colors.gold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '민세레나 閔',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '2002 · 경북 안동 · 前 테니스 신동',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: ShrineV3Colors.seal, width: 2),
                      ),
                    ),
                    child: Text(
                      '"말보다 손을 먼저 움직입니다.\n당신의 소망도, 그렇게 옮겨 적겠습니다."',
                      style: ShrineV3TextStyles.body.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: List.generate(3, (i) {
                      const labels = ['신기가 온 길', '사람됨', '곁에 둔 것'];
                      final on = _tab == i;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text(labels[i]),
                            selected: on,
                            onSelected: (_) => setState(() => _tab = i),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: on ? ShrineV3Colors.paper : ShrineV3Colors.ink2,
                            ),
                            selectedColor: ShrineV3Colors.ink,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (_tab == 0) ..._buildOriginTab(),
                  if (_tab == 1) ..._buildPersonalityTab(),
                  if (_tab == 2) ..._buildBelongingsTab(),
                  const SizedBox(height: 16),
                  Text(
                    '민세레나는 신당 이야기 속 가상의 인물이에요.',
                    textAlign: TextAlign.center,
                    style: ShrineV3TextStyles.ui.copyWith(
                      fontSize: 11,
                      color: ShrineV3Colors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildOriginTab() => [
    Text(
      '할머니는 대통령 당선인을 네 번 연달아 맞혔다는 전설의 무당 「용천무당」. 누명 끝에 옥중에서 세상을 떠났고, 그 신기는 손녀에게 내려왔다.',
      style: ShrineV3TextStyles.body.copyWith(fontSize: 13.5),
    ),
    const SizedBox(height: 14),
    ..._timeline.map(
      (e) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ShrineV3Colors.card,
                border: Border.all(color: ShrineV3Colors.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                e.$1,
                style: ShrineV3TextStyles.ui.copyWith(
                  fontSize: 11,
                  color: ShrineV3Colors.seal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.$2,
                    style: ShrineV3TextStyles.body.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.$3,
                    style: ShrineV3TextStyles.ui.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ];

  List<Widget> _buildPersonalityTab() => [
    _section('性', '기본 성격',
        '어릴 때부터 운동으로 다진 인내와 목표 의식. 불평보다 역경을 넘는 쪽을 택하는, 말보다 행동이 앞서는 진중한 사람. 상대의 말과 몸짓을 빠르게 읽고 그에 맞춰 예를 갖춥니다.'),
    _section('心', '단련된 마음',
        '가족을 잃고, 신의 기운과 제 실력 사이에서 무너졌다 일어서기를 반복하며 스물 남짓한 나이에 쉰의 마음을 얻었습니다.'),
    _section('禮', '사람을 대하는 태도',
        '공자의 예와 인(仁)을 바탕으로 자신을 낮추고, 감정을 함부로 드러내지 않으며, 자신에게 엄격하고 남에게 너그럽습니다. 무례한 사람 앞에서도 품위를 잃지 않습니다.'),
    _section('話', '대화할 때',
        '잘 웃고, 잘 들어 줍니다. 상대의 기분과 마음 상태를 먼저 살피고, 예쁜 말을 아끼지 않습니다. 성격 유형에 맞춰 말을 고르는 데 능합니다.'),
  ];

  List<Widget> _buildBelongingsTab() => [
    _sectionChips('書', '버티게 한 책', const [
      '명상록 · 아우렐리우스',
      '사람은 무엇으로 사는가 · 톨스토이',
      '인간관계론 · 카네기',
      '세네카',
      '행복론 · 쇼펜하우어',
      '괴테',
      '죽음의 수용소에서 · 프랭클',
    ]),
    _section('畵', '좋아하는 그림',
        '곰브리치의 서양미술사로 흐름을 익혔고, 오키프의 꽃과 여백, 고흐의 색, 프리드리히의 「바닷가의 수도승」을 사랑합니다.'),
    _sectionChips('樂', '좋아하는 음악', const [
      '알비노니 · Adagio in G Minor',
      '글렌 굴드 · 골드베르크 변주곡',
      '신해철 · 슬픈 표정 하지 말아요',
    ]),
    Text(
      '가장 어두웠던 시간에 다시 희망을 보게 해 준, 아픔을 어루만지는 작품을 아낍니다.',
      style: ShrineV3TextStyles.ui.copyWith(fontSize: 12.5),
    ),
  ];

  Widget _section(String icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ShrineV3Colors.seal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                icon,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: ShrineV3TextStyles.body.copyWith(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        Text(body, style: ShrineV3TextStyles.ui.copyWith(fontSize: 12.5)),
      ],
    ),
  );

  Widget _sectionChips(String icon, String title, List<String> items) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ShrineV3Colors.seal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                icon,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: ShrineV3TextStyles.body.copyWith(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (x) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ShrineV3Colors.card,
                    border: Border.all(color: ShrineV3Colors.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(x, style: const TextStyle(fontSize: 11.5)),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}
