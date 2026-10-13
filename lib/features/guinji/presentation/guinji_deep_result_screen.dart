import 'package:flutter/material.dart';

import '../character/guinji_character.dart';
import '../deep/guinji_deep_text.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_animated_graph.dart' show parseGuinjiBirthLabel;

/// 08 · 자세한 결과(Deep Result) — 핸드오프 `DeepResult`(1321~1436줄) 1:1
/// 이식. "더 자세한 관계 보기" CTA가 결제(프리패스/광고)·인트로 애니메이션을
/// 거쳐 최종적으로 도달하는 10장 장문 풀이 화면이다.
///
/// [귀인지도 기능 정리 — 죽은 코드 연결] `guinji_deep_text.dart`
/// (`guinjiDeepText`, 10개 장문 필드: summary/first/energy/bond/role/
/// together/caution/seasons/tips/letter)가 지금까지 `specialInsight`/
/// `tips` 2개 필드만 간접 사용되고 나머지는 완전히 미사용 상태였다. 이
/// 화면이 그 10개 필드를 핸드오프와 동일한 순서·구성으로 전부 사용한다.
class GuinjiDeepResultScreen extends StatelessWidget {
  const GuinjiDeepResultScreen({
    super.key,
    required this.person,
    this.ownerName = '나',
    this.onShare,
  });

  final GuinjiPerson person;
  final String ownerName;
  final VoidCallback? onShare;

  /// `fillName(s, m, me)` 1:1 이식 — {n}=상대 이름, {me}=나(소유자) 이름.
  String _fill(String s) => fill(s, n: person.name, me: ownerName);

  /// [P4-hotfix] 카드 스크린샷을 갤러리에 저장(무료·광고 없음).
  Future<void> _saveCardToGallery(BuildContext context) async {
    final obj = context.findRenderObject();
    if (obj is! RenderRepaintBoundary) return;
    final image = await obj.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    await ImageGallerySaver.saveImage(
      data.buffer.asUint8List(),
      quality: 100,
      name: 'sintong_guinji_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('갤러리에 저장했어요 ✦')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationMetaOf(person.relation);
    final deep = guinjiDeepText[person.relation] ??
        guinjiDeepText['BI_HWA']!; // 알 수 없는 키 폴백(크래시 방지).
    final birth = parseGuinjiBirthLabel(person.birth);
    final character = birth == null
        ? null
        : GuinjiCharacter.of(birth: birth, stableKey: person.id);
    final color = meta.color;

    // [핸드오프 bars 1:1 이식] S1~S5 고정 베이스값을 점수로 보정.
    const baseBars = <(String, double)>[
      ('일간 오행', 92),
      ('일지 관계', 88),
      ('오행 보완', 81),
      ('십성 흐름', 74),
      ('합충 균형', 69),
    ];
    final bars = baseBars
        .map(
          (e) => (
            e.$1,
            (e.$2 - (100 - person.score) * 0.7).clamp(28.0, 98.0),
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: GmColors.bg,
      body: Stack(
        children: [
          // 본문 스크롤 영역.
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DeepHero(
                  character: character,
                  initial: person.name.isNotEmpty
                      ? person.name.substring(0, 1)
                      : '?',
                  color: color,
                  hanja: meta.hanja,
                  label: meta.label,
                  title: deep.title,
                  bandCaption:
                      '${person.name}님의 캐릭터 · ${character?.band ?? ''} · '
                      '케미 ${person.score}점',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 130),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 키워드 칩.
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final k in deep.keywords)
                                Container(
                                  height: 30,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: GmColors.fg.withValues(alpha: 0.05),
                                    border: Border.all(color: GmColors.hair),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    '# $k',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: GmColors.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        _DeepChapter(
                          no: 1,
                          title: '한눈에 보는 두 사람',
                          color: color,
                          child: _ParaGroup(
                            texts: deep.summary.map(_fill).toList(),
                          ),
                        ),

                        _DeepChapter(
                          no: 2,
                          title: '관계를 이루는 다섯 가지 힘',
                          color: color,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  for (final bar in bars)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 70,
                                            child: Text(
                                              bar.$1,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500,
                                                color: GmColors.muted,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value: bar.$2 / 100,
                                                minHeight: 4,
                                                backgroundColor: GmColors.fg
                                                    .withValues(alpha: 0.08),
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                  color,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 24,
                                            child: Text(
                                              '${bar.$2.round()}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: GmColors.fg,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const _Para(
                                '다섯 가지 힘은 엔진이 판정에 사용한 S1~S5 단계를 '
                                '쉽게 풀어 본 것이에요. 막대가 길수록 그 부분이 '
                                '관계를 받쳐 주는 힘이 크다는 뜻이에요.',
                              ),
                            ],
                          ),
                        ),

                        _DeepChapter(
                          no: 3,
                          title: '처음 만났을 때의 느낌',
                          color: color,
                          child: _ParaGroup(
                            texts: deep.first.map(_fill).toList(),
                          ),
                        ),
                        _DeepChapter(
                          no: 4,
                          title: '서로에게 흐르는 기운',
                          color: color,
                          child: _ParaGroup(
                            texts: deep.energy.map(_fill).toList(),
                          ),
                        ),
                        _DeepChapter(
                          no: 5,
                          title: '마음 깊은 곳의 결',
                          color: color,
                          child: _ParaGroup(
                            texts: deep.bond.map(_fill).toList(),
                          ),
                        ),

                        _DeepChapter(
                          no: 6,
                          title: '서로에게 어떤 사람인가',
                          color: color,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _RoleCard(
                                      character: character,
                                      heading: '${person.name}님은 나에게',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _RoleCard(
                                      character: null,
                                      heading: '나는 ${person.name}님에게',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _ParaGroup(
                                texts: deep.role.map(_fill).toList(),
                              ),
                            ],
                          ),
                        ),

                        _DeepChapter(
                          no: 7,
                          title: '함께하면 좋은 일',
                          color: color,
                          child: _ParaGroup(
                            texts: deep.together.map(_fill).toList(),
                          ),
                        ),
                        _DeepChapter(
                          no: 8,
                          title: '조심하면 좋은 것',
                          color: color,
                          child: _ParaGroup(
                            texts: deep.caution.map(_fill).toList(),
                          ),
                        ),

                        _DeepChapter(
                          no: 9,
                          title: '계절마다 달라지는 관계의 흐름',
                          color: color,
                          child: Column(
                            children: [
                              for (var i = 0; i < deep.seasons.length; i++)
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    border: i == 0
                                        ? null
                                        : const Border(
                                            top: BorderSide(
                                              color: GmColors.hair,
                                            ),
                                          ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 34,
                                        child: Text(
                                          deep.seasons[i][0],
                                          style: TextStyle(
                                            fontFamily: GmText.display,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            height: 1.6,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _fill(deep.seasons[i][1]),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.7,
                                            color: Color(0xD6F2F0EC),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        _DeepChapter(
                          no: 10,
                          title: '관계를 이어가는 네 가지 방법',
                          color: color,
                          child: Column(
                            children: [
                              for (var i = 0; i < deep.tips.length; i++)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: color),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          _fill(deep.tips[i]),
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            height: 1.7,
                                            color: Color(0xE0F2F0EC),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // 귀인의 한마디(편지).
                        Container(
                          margin: const EdgeInsets.only(top: 18),
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
                          decoration: BoxDecoration(
                            color: GmColors.card,
                            border: Border.all(color: GmColors.hair),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _FaceAvatar(
                                    character: character,
                                    initial: person.name.isNotEmpty
                                        ? person.name.substring(0, 1)
                                        : '?',
                                    size: 44,
                                    ringColor: color,
                                    color: color,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${person.name}님이 전하는 한마디',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: GmColors.fg,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          '관계의 결로 써 본 편지',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: GmColors.dim,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '"${_fill(deep.letter)}"',
                                style: const TextStyle(
                                  fontFamily: GmText.body,
                                  fontSize: 16,
                                  height: 1.9,
                                  color: Color(0xE6F2F0EC),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.only(top: 26),
                          child: Text(
                            '이 풀이는 두 사람의 사주를 바탕으로 한 참고용 이야기예요.\n'
                            '관계를 만드는 건 결국 두 사람의 마음이에요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, height: 1.6, color: GmColors.dim),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 상단 고정 바(뒤로가기).
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            child: _RoundIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),

          // 하단 고정 CTA.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                28,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    GmColors.bg.withValues(alpha: 0),
                    GmColors.bg.withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                        try {
                          await _saveCardToGallery(context);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요.')),
                            );
                          }
                        }
                      },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: GmColors.line),
                          foregroundColor: GmColors.fg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          '저장',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: onShare,
                        style: gmPrimary(),
                        child: const Text('결과 공유하기'),
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

/// 히어로 영역 — 상반신 이미지 배경(없으면 색 그라디언트 폴백) + 타이틀.
class _DeepHero extends StatelessWidget {
  const _DeepHero({
    required this.character,
    required this.initial,
    required this.color,
    required this.hanja,
    required this.label,
    required this.title,
    required this.bandCaption,
  });

  final GuinjiCharacter? character;
  final String initial;
  final Color color;
  final String hanja;
  final String label;
  final String title;
  final String bandCaption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 440,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (character != null)
            Image.asset(
              character!.body,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => _HeroFallback(color: color, initial: initial),
            )
          else
            _HeroFallback(color: color, initial: initial),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  GmColors.bg.withValues(alpha: 0.55),
                  GmColors.bg.withValues(alpha: 0),
                  GmColors.bg.withValues(alpha: 0),
                  GmColors.bg,
                ],
                stops: const [0.0, 0.2, 0.45, 0.96],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: GmColors.bg.withValues(alpha: 0.5),
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hanja,
                        style: TextStyle(
                          fontFamily: GmText.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: GmText.display,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    letterSpacing: -0.7,
                    color: GmColors.fg,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  bandCaption,
                  style: const TextStyle(fontSize: 14, color: GmColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.color, required this.initial});

  final Color color;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), GmColors.bg],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: GmText.display,
            fontSize: 72,
            fontWeight: FontWeight.w700,
            color: GmColors.fg,
          ),
        ),
      ),
    );
  }
}

class _DeepChapter extends StatelessWidget {
  const _DeepChapter({
    required this.no,
    required this.title,
    required this.color,
    required this.child,
  });

  final int no;
  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GmColors.hair)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                no.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: GmText.mono,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: GmColors.fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ParaGroup extends StatelessWidget {
  const _ParaGroup({required this.texts});

  final List<String> texts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final t in texts) _Para(t)],
    );
  }
}

class _Para extends StatelessWidget {
  const _Para(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: GmText.body,
          fontSize: 16,
          height: 1.85,
          color: Color(0xDBF2F0EC),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.character, required this.heading});

  final GuinjiCharacter? character;
  final String heading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GmColors.card,
        border: Border.all(color: GmColors.hair),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FaceAvatar(
            character: character,
            initial: '•',
            size: 36,
            ringColor: null,
            color: GmColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            heading,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: GmColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceAvatar extends StatelessWidget {
  const _FaceAvatar({
    required this.character,
    required this.initial,
    required this.size,
    required this.ringColor,
    required this.color,
  });

  final GuinjiCharacter? character;
  final String initial;
  final double size;
  final Color? ringColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: ringColor == null
          ? null
          : [BoxShadow(color: ringColor!, blurRadius: 0, spreadRadius: 1.5)],
    );
    if (character == null) {
      return Container(
        width: size,
        height: size,
        decoration: decoration.copyWith(color: color.withValues(alpha: 0.2)),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: GmText.display,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        character!.face,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: color.withValues(alpha: 0.2),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              fontFamily: GmText.display,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
