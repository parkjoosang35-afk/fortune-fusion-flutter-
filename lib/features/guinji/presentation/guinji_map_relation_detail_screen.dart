import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../application/guinji_provider.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// 귀인지도(Guinji Map) — 관계 상세 화면 (`/guinji-map/*` 신규 디자인 톤).
///
/// [귀인지도 기능 정리 — 1] M(내 지도) 화면 노드 탭 → 바텀시트(N)의
/// "더 자세히 보기" 버튼이 지금까지 빈 콜백(`onSeeMore: () {}`)이라 눌러도
/// 아무 반응이 없던 문제를 해결한다. N(바텀시트)의 요약보다 더 깊은 정보
/// (오행 근거·좋은/조심할 순간·스페셜 해설 잠금해제)를 아이보리·로즈골드
/// 톤(`GmColors`, `/guinji-map/*` 8화면과 동일 팔레트)으로 새로 구현했다.
/// 기존 `guinji_relation_detail_screen.dart`(다크·라벤더 톤, `/guinji/*`
/// 구계열 전용)는 그대로 두고 건드리지 않는다 — 완전히 별개의 화면이다.
///
/// [스페셜 해설 잠금해제] "광고 보고 열기"/"복주머니 50P로 열기"는 실제
/// 서버 API(`POST /guinji/unlocks`, [GuinjiProvider.unlock])를 그대로
/// 호출한다 — 구계열 상세화면과 동일한 백엔드 연동, UI만 새 디자인으로.
class GuinjiMapRelationDetailScreen extends StatefulWidget {
  const GuinjiMapRelationDetailScreen({super.key, required this.person});

  final GuinjiPerson person;

  @override
  State<GuinjiMapRelationDetailScreen> createState() =>
      _GuinjiMapRelationDetailScreenState();
}

class _GuinjiMapRelationDetailScreenState
    extends State<GuinjiMapRelationDetailScreen> {
  bool _specialUnlocked = false;
  bool _unlocking = false;

  static String _goodMoment(String category) {
    switch (category) {
      case 'boost':
        return '큰 결정을 앞두고 있을 때, 감정이 흔들릴 때';
      case 'path':
        return '함께 계획하고 실행할 때, 여행이나 도전';
      case 'warm':
        return '일이 벅찰 때 잠깐 만나 대화를 나눌 때';
      case 'care':
        return '무대 위, 새로운 자극이 필요할 때';
    }
    return '평범한 일상 속 짧은 만남';
  }

  static String _carefulMoment(String category) {
    switch (category) {
      case 'boost':
        return '서로 지쳐 있는 저녁 시간대의 다툼';
      case 'path':
        return '속도가 안 맞을 때 서로 답답해질 수 있어요';
      case 'warm':
        return '너무 자주 만나면 서로 무뎌질 수 있어요';
      case 'care':
        return '가까이 붙어 있을 때 감정 소모가 커요';
    }
    return '무리한 부탁이나 갑작스러운 변화';
  }

  Future<void> _handleUnlock(String method) async {
    if (_unlocking) return;
    setState(() => _unlocking = true);
    final provider = context.read<GuinjiProvider>();
    final ok = await provider.unlock(
      memberId: widget.person.id,
      method: method,
    );
    if (!mounted) return;
    setState(() => _unlocking = false);
    if (ok) {
      setState(() => _specialUnlocked = true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.error ?? '해금에 실패했습니다.')));
    }
  }

  void _handleShare() {
    final person = widget.person;
    final meta = guinjiRelationTypes[person.relation];
    Share.share(
      '${person.name}님과의 관계는 "${meta?.label ?? ''}"예요 · 신통방통 귀인지도',
    );
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final meta = guinjiRelationTypes[person.relation];
    final ohaeng = guinjiOhaengTypes[person.ohaeng];
    final color = meta != null
        ? GmColors.categoryColor(meta.category)
        : GmColors.rose500;
    final initial = person.name.isNotEmpty ? person.name.substring(0, 1) : '?';
    final category = meta?.category ?? 'boost';

    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: GmTopBar(back: true, title: '${person.name}님과의 관계'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero — 아바타 + 이름 + 관계 라벨 + 점수.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  border: Border.all(color: GmColors.line),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.85)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: GmFonts.serif,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GmChip(
                      label: meta != null ? '${meta.hanja} ${meta.label}' : person.relation,
                      background: color.withValues(alpha: 0.12),
                      foreground: color,
                      borderColor: color.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontFamily: GmFonts.serif,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GmColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.birth,
                      style: const TextStyle(fontSize: 11, color: GmColors.inkFaint),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${person.score}',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/ 100',
                          style: TextStyle(fontSize: 13, color: GmColors.inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '관계 케미 점수',
                      style: TextStyle(fontSize: 10.5, color: GmColors.inkFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 관계의 결.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  border: Border.all(color: GmColors.line),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GmLabelMini('관계의 결'),
                    const SizedBox(height: 10),
                    Text(
                      meta?.long ?? meta?.description ?? '두 분의 관계를 살펴보고 있어요.',
                      style: const TextStyle(fontSize: 13.5, height: 1.7, color: GmColors.ink),
                    ),
                    const SizedBox(height: 14),
                    _MomentRow(
                      color: color,
                      label: '함께 있으면 좋은 순간',
                      desc: _goodMoment(category),
                    ),
                    const SizedBox(height: 8),
                    _MomentRow(
                      color: GmColors.rose800,
                      label: '조심할 순간',
                      desc: _carefulMoment(category),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 오행 근거.
              if (ohaeng != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    border: Border.all(color: GmColors.line),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ohaeng.color.withValues(alpha: 0.16),
                          border: Border.all(color: ohaeng.color.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          ohaeng.label,
                          style: TextStyle(
                            fontFamily: GmFonts.serif,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: ohaeng.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ohaeng.name}(${ohaeng.label}) 기운의 사람',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: GmColors.ink,
                              ),
                            ),
                            if (person.note.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                person.note,
                                style: const TextStyle(fontSize: 11, color: GmColors.inkSoft),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // 스페셜 해설 잠금/해금.
              if (!_specialUnlocked)
                _SpecialLockedCard(
                  unlocking: _unlocking,
                  onUnlockAd: () => _handleUnlock('ad'),
                  onUnlockPouch: () => _handleUnlock('point'),
                )
              else
                _SpecialUnlockedCard(person: person, meta: meta, ohaeng: ohaeng, color: color),

              const SizedBox(height: 16),
              GmRoseButton(
                label: '이 관계 공유하기',
                icon: Icons.ios_share,
                onPressed: _handleShare,
              ),
              const SizedBox(height: 12),
              const Text(
                '"재미·참고용" 콘텐츠. 절대적 판단이 아니에요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: GmColors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.color, required this.label, required this.desc});

  final Color color;
  final String label;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, height: 1.55, color: GmColors.inkSoft),
              children: [
                TextSpan(
                  text: '$label · ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: GmColors.ink),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpecialLockedCard extends StatelessWidget {
  const _SpecialLockedCard({
    required this.onUnlockAd,
    required this.onUnlockPouch,
    this.unlocking = false,
  });

  final VoidCallback onUnlockAd;
  final VoidCallback onUnlockPouch;
  final bool unlocking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GmColors.gold.withValues(alpha: 0.4)),
        gradient: RadialGradient(
          center: const Alignment(0.8, -0.6),
          radius: 1.0,
          colors: [
            GmColors.gold.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GmLabelMini('SPECIAL · 스페셜 해설', color: GmColors.rose700),
          const SizedBox(height: 6),
          const Text(
            '이 관계, 어떻게 대해야 할까',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GmColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            '사주 4기둥을 근거로 신통도령이 자세히 풀어드립니다.',
            style: TextStyle(fontSize: 12, height: 1.5, color: GmColors.inkSoft),
          ),
          const SizedBox(height: 12),
          if (unlocking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: GmColors.rose600),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onUnlockPouch,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: GmColors.line),
                      foregroundColor: GmColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      '복주머니\n50P로 열기',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, height: 1.3, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: GmColors.gradientRose,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: onUnlockAd,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '광고 보고\n지금 열기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SpecialUnlockedCard extends StatelessWidget {
  const _SpecialUnlockedCard({
    required this.person,
    required this.meta,
    required this.ohaeng,
    required this.color,
  });

  final GuinjiPerson person;
  final GuinjiRelationMeta? meta;
  final GuinjiOhaengMeta? ohaeng;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = meta?.label ?? person.relation;
    final ohaengText = ohaeng != null ? '${ohaeng!.name}(${ohaeng!.label})' : '오행';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GmLabelMini('SPECIAL · 해금됨', color: color),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, height: 1.65, color: GmColors.ink),
              children: [
                const TextSpan(text: '두 분은 '),
                TextSpan(text: label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                const TextSpan(text: '의 결이에요. '),
                TextSpan(text: '${person.name}님이 지닌 '),
                TextSpan(text: ohaengText, style: const TextStyle(color: GmColors.rose700)),
                const TextSpan(text: '의 기운은 서로를 살리는(生) 작용을 합니다. 작은 일도 함께 상의하면 결이 잘 풀려요.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GmColors.rose700.withValues(alpha: 0.06),
              border: Border.all(color: GmColors.rose700.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 11, height: 1.5, color: GmColors.inkSoft),
                children: [
                  TextSpan(text: 'Tip. ', style: TextStyle(color: GmColors.rose700)),
                  TextSpan(text: '결정이 흔들릴 때 이 사람에게 먼저 물어보세요.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
