import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/guinji_provider.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import '../widgets/guinji_chemistry_candle.dart';

/// 귀인지도(Guinji Map) — 06. 관계 상세 화면.
///
/// [Phase G-4] `GUINJI_SCREENS.md` "06 · 관계 상세" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `DetailScreen`): 지도(S5)에서 지인 노드를 탭했을
/// 때 유형·오행·케미점수·해설을 보여주는 화면.
///
/// [Phase G-4 범위 — 절대 원칙 준수] "스페셜 해설 잠금" 카드의 두 CTA
/// (광고 보고 열기 / 복주머니 50P로 열기)는 실제 광고 SDK 연동과 재화
/// 차감(Wallet/PointHistory 원장 + PointPolicy 등록)이 모두 필요한
/// 영역이라, 이 Phase에서는 **로컬 state로 잠금 해제 UI만** 보여주고
/// 실제 차감/지급은 하지 않는다. 백엔드 정책 확정 후 후속 Phase에서
/// 연결한다.
class GuinjiRelationDetailScreen extends StatefulWidget {
  const GuinjiRelationDetailScreen({super.key, required this.person});

  final GuinjiPerson person;

  @override
  State<GuinjiRelationDetailScreen> createState() =>
      _GuinjiRelationDetailScreenState();
}

class _GuinjiRelationDetailScreenState
    extends State<GuinjiRelationDetailScreen> {
  bool _specialUnlocked = false;
  bool _unlocking = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? '해금에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final relation = guinjiRelationTypes[person.relation]!;
    final ohaeng = guinjiOhaengTypes[person.ohaeng]!;

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      const _MonoLabel('RELATION · DETAIL'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _HeroCard(person: person, relation: relation),
                  const SizedBox(height: 12),
                  _TypeDescriptionCard(relation: relation),
                  const SizedBox(height: 8),
                  _OhaengCard(person: person, ohaeng: ohaeng),
                  const SizedBox(height: 8),
                  if (!_specialUnlocked)
                    _SpecialLockedCard(
                      unlocking: _unlocking,
                      onUnlockAd: () => _handleUnlock('ad'),
                      onUnlockPouch: () => _handleUnlock('point'),
                    )
                  else
                    _SpecialUnlockedCard(
                      person: person,
                      relation: relation,
                      ohaeng: ohaeng,
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    '"재미·참고용" 콘텐츠. 절대적 판단이 아니에요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.ui,
                      fontSize: 10,
                      color: GuinjiColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: GuinjiColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text, {this.color, this.fontSize = 10});

  final String text;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: fontSize,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
        color: color ?? GuinjiColors.textSecondary,
      ),
    );
  }
}

/// 공통 카드 컨테이너.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding, this.decoration});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration:
          decoration ??
          BoxDecoration(
            color: GuinjiColors.surfaceCard,
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
      child: child,
    );
  }
}

/// Hero 카드 — relation badge + 이름 + 생년월일 + 케미 촛불.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.person, required this.relation});

  final GuinjiPerson person;
  final GuinjiRelationMeta relation;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.2,
          colors: [
            relation.color.withValues(alpha: 0.25),
            GuinjiColors.surfaceCard,
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: Column(
        children: [
          _RelationBadge(relation: relation, large: true),
          const SizedBox(height: 10),
          Text(
            person.name,
            style: const TextStyle(
              fontFamily: GuinjiFonts.display,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: -0.4,
              color: GuinjiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          _MonoLabel(person.birth, fontSize: 9),
          const SizedBox(height: 14),
          GuinjiChemistryCandle(score: person.score, size: 54),
          const SizedBox(height: 6),
          const _MonoLabel('CHEMISTRY SCORE', fontSize: 9),
        ],
      ),
    );
  }
}

class _RelationBadge extends StatelessWidget {
  const _RelationBadge({required this.relation, this.large = false});

  final GuinjiRelationMeta relation;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: relation.color.withValues(alpha: 0.22),
        border: Border.all(color: relation.color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            relation.hanja,
            style: TextStyle(
              fontFamily: GuinjiFonts.display,
              fontWeight: FontWeight.w900,
              fontSize: large ? 14 : 11,
              color: relation.color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            relation.label,
            style: TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: large ? 13 : 10,
              color: relation.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 유형 해설 카드 — 신통도령 미니(pointing) + 관계 설명.
class _TypeDescriptionCard extends StatelessWidget {
  const _TypeDescriptionCard({required this.relation});

  final GuinjiRelationMeta relation;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/home/doryeong/pointing.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${relation.hanja} ${relation.label} · ',
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.body,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: GuinjiColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: relation.subtitle,
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.body,
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          color: GuinjiColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  relation.description,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontSize: 12,
                    height: 1.55,
                    color: GuinjiColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 오행 근거 카드 — 오행 배지 + 분포 바 차트.
class _OhaengCard extends StatelessWidget {
  const _OhaengCard({required this.person, required this.ohaeng});

  final GuinjiPerson person;
  final GuinjiOhaengMeta ohaeng;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonoLabel('OHAENG · 오행 근거', fontSize: 9),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ohaeng.color.withValues(alpha: 0.3),
                  border: Border.all(color: ohaeng.color),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ohaeng.label,
                  style: TextStyle(
                    fontFamily: GuinjiFonts.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: ohaeng.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ohaeng.name}(${ohaeng.label}) 기운의 사람',
                      style: const TextStyle(
                        fontFamily: GuinjiFonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: GuinjiColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.note,
                      style: const TextStyle(
                        fontFamily: GuinjiFonts.ui,
                        fontSize: 11,
                        color: GuinjiColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _OhaengDistributionBars(activeKey: person.ohaeng),
        ],
      ),
    );
  }
}

/// 오행 분포 바 차트 — 5개 세로바(木火土金水), 해당 오행만 강조.
class _OhaengDistributionBars extends StatelessWidget {
  const _OhaengDistributionBars({required this.activeKey});

  final String activeKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: guinjiOhaengTypes.entries.map((entry) {
        final key = entry.key;
        final meta = entry.value;
        final active = key == activeKey;
        // [Phase G-4 범위] 실제 명리 계산 없이, 활성 오행만 78%로
        // 강조하고 나머지는 키 코드 기반 결정론적 값으로 표시한다.
        final val = active ? 0.78 : 0.12 + (key.codeUnitAt(0) % 30) / 100;
        return Column(
          children: [
            SizedBox(
              height: 42,
              width: 18,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: val.clamp(0.0, 1.0),
                  child: Container(
                    width: 10,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: active ? 1 : 0.35),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: active
                          ? [BoxShadow(color: meta.color, blurRadius: 10)]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta.label,
              style: TextStyle(
                fontFamily: GuinjiFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: active ? meta.color : GuinjiColors.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// 스페셜 해설 잠금 카드(해금 전).
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
    return _Card(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: GuinjiColors.lavender.withValues(alpha: 0.4),
          style: BorderStyle.solid,
        ),
        gradient: RadialGradient(
          center: const Alignment(0.8, -0.6),
          radius: 1.0,
          colors: [
            GuinjiColors.lavender.withValues(alpha: 0.2),
            GuinjiColors.surfaceCard,
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonoLabel('SPECIAL · 스페셜 해설', fontSize: 9),
          const SizedBox(height: 6),
          const Text(
            '이 관계, 어떻게 대해야 할까',
            style: TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: GuinjiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '사주 4기둥을 근거로 신통도령이 자세히 풀어드립니다.',
            style: TextStyle(
              fontFamily: GuinjiFonts.body,
              fontSize: 12,
              height: 1.5,
              color: GuinjiColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (unlocking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: GuinjiColors.lavender,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _SmallCta(
                    label: '광고 보고\n지금 열기',
                    primary: true,
                    onPressed: onUnlockAd,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SmallCta(
                    label: '복주머니\n50P로 열기',
                    primary: false,
                    onPressed: onUnlockPouch,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SmallCta extends StatelessWidget {
  const _SmallCta({
    required this.label,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? GuinjiColors.lavender : GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: primary
                ? null
                : Border.all(color: GuinjiColors.surfaceCardBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
              fontSize: 11,
              height: 1.2,
              color: primary ? GuinjiColors.ink : GuinjiColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 스페셜 해설 카드(해금 후) — 신통도령 풀이.
class _SpecialUnlockedCard extends StatelessWidget {
  const _SpecialUnlockedCard({
    required this.person,
    required this.relation,
    required this.ohaeng,
  });

  final GuinjiPerson person;
  final GuinjiRelationMeta relation;
  final GuinjiOhaengMeta ohaeng;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonoLabel(
            'SPECIAL · 해금됨',
            color: GuinjiColors.lavender,
            fontSize: 9,
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: GuinjiFonts.body,
                fontSize: 13,
                height: 1.65,
                color: GuinjiColors.textPrimary,
              ),
              children: [
                const TextSpan(text: '두 분은 '),
                TextSpan(
                  text: relation.label,
                  style: TextStyle(
                    color: relation.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '의 결이에요. '),
                TextSpan(text: '${person.name}님이 지닌 '),
                TextSpan(
                  text: '${ohaeng.name}(${ohaeng.label})',
                  style: const TextStyle(color: GuinjiColors.crystalAqua),
                ),
                const TextSpan(text: '의 기운은 서로를 '),
                const TextSpan(
                  text: '살리는(生)',
                  style: TextStyle(color: GuinjiColors.lavender),
                ),
                const TextSpan(text: ' 작용을 합니다. 작은 일도 함께 상의하면 결이 잘 풀려요.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GuinjiColors.lavender.withValues(alpha: 0.08),
              border: Border.all(
                color: GuinjiColors.lavender.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: GuinjiFonts.body,
                  fontSize: 11,
                  height: 1.5,
                  color: GuinjiColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: 'Tip. ',
                    style: TextStyle(color: GuinjiColors.lavender),
                  ),
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
