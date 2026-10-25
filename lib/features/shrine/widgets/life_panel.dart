// 신당(THE SHRINE) U5 — 부적 수명 표현 위젯: LifeVeil · LifeBar · LifePanel
// 원본: shrine-screens-f.jsx + shrine.css(.life-veil/.life-bar/.life-panel)
// [U7 전체화면 의식 복구 — 통합 지시서 §2-3] 과거 "[범위 조정]" 주석으로
// 향 올리기를 즉시처리+스낵바로 간소화했었으나, 이는 명시적 승인 기록이
// 아니므로 이번 지시에 따라 원안의 전체화면 의식(ShrineIncenseRite, 약
// 6.2초)을 복구한다. 실제 저장(tendTalisItem)은 의식의 "숫자" 단계(3.4s)
// 에서 수행되며 이전과 동일한 updateBox() 경로를 그대로 쓴다.
// [U9-4 포팅] devotionOf(연속 향 올림 "정성" 표시) — tended/lastTend에 더해
// U9-4에서 추가한 tendDays를 이용해 연속 일수를 계산하고 lp-dev 줄로 노출한다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../engine/life_system.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import 'shrine_fx.dart' show DevotionMark;
import 'shrine_incense_rite.dart' show showShrineIncenseRite;

/// 부적 그리드 셀 위에 얹는 수명 오버레이 — 盛/生 이면 아무것도 그리지 않는다.
class LifeVeil extends StatelessWidget {
  final Life life;
  const LifeVeil({super.key, required this.life});
  @override
  Widget build(BuildContext context) {
    if (life.st == 'full' || life.st == 'born') return const SizedBox.shrink();
    final bg = life.st == 'wane'
        ? const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0x59402814), Colors.transparent],
          )
        : null;
    final flat = life.st == 'gone' || life.st == 'sent'
        ? const Color(0x590A0605)
        : null;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(gradient: bg, color: flat),
        alignment: Alignment.center,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: life.st == 'sent'
                ? const Color(0xE5504A44)
                : const Color(0xD9A11D19),
            boxShadow: life.st == 'sent' ? null : Glow.red(14),
          ),
          child: Text(
            life.s.k,
            style: T(1).display(17, w: FontWeight.w900, c: C.btnText),
          ),
        ),
      ),
    );
  }
}

/// 향 막대 게이지 — 남은 기운(qi)만큼 금빛으로 채워지고, 끝에 불씨 점 하나.
class LifeBar extends StatelessWidget {
  final Life life;
  final bool small;
  const LifeBar({super.key, required this.life, this.small = false});
  @override
  Widget build(BuildContext context) {
    final warn = life.st == 'wane' || life.st == 'gone';
    return Row(
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0x1AEFE4D2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: life.qi.clamp(0, 1),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: warn
                          ? const [Color(0xFF4A3020), Color(0xFFC98A3A)]
                          : const [Color(0xFF6B4A2E), C.gold],
                    ),
                  ),
                ),
              ),
              if (life.st != 'gone' && life.st != 'sent')
                Positioned(
                  left: (life.qi.clamp(0, 1)) * 100 - 3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF8A4A),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xB3E0412F),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${life.s.k} ',
                style: T(1).display(
                  small ? 10 : 11,
                  w: FontWeight.w900,
                  c: warn ? C.redHot : C.gold,
                ),
              ),
              TextSpan(
                text: life.st == 'sent'
                    ? '보냄'
                    : life.st == 'gone'
                    ? '소멸'
                    : '${life.left}일',
                style: T(1).mono.copyWith(
                  fontSize: small ? 9.5 : 10.5,
                  color: C.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 부적 설명서(showTalisManual) 위에 얹는 수명 카드 — 향 올리기 · 보내 드리기.
class LifePanel extends StatefulWidget {
  final BoxItem item;
  final VoidCallback? onSent;
  const LifePanel({super.key, required this.item, this.onSent});
  @override
  State<LifePanel> createState() => _LifePanelState();
}

class _LifePanelState extends State<LifePanel> {
  bool _burning = false;

  void _tend(ShrineSessionProvider provider) {
    final beforeLeft = lifeOf(widget.item).left;
    showShrineIncenseRite(
      context,
      beforeLeft: beforeLeft,
      tendDays: kTendDays,
      doTend: () => provider.updateBox(widget.item.no, tendTalisItem),
    );
  }

  Future<void> _send(ShrineSessionProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B0D0B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: C.goldLine),
        ),
        title: Text('보내 드리겠습니까?', style: T(1).display(17, w: FontWeight.w900)),
        content: Text(
          '소멸한 부적을 태워 보냅니다. 되돌릴 수 없으며, 재(灰)로 부적함에 남습니다.',
          style: T(1).body(13.5, c: C.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('그만두기', style: T(1).ui(13, c: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('태워 보내기', style: T(1).ui(13, c: C.redHot)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _burning = true);
    await Future.delayed(
      Duration(
        milliseconds: context.read<ShrineSessionProvider>().state.reduce
            ? 200
            : 1400,
      ),
    );
    if (!mounted) return;
    provider.updateBox(widget.item.no, sendTalisItem);
    setState(() => _burning = false);
    widget.onSent?.call();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShrineSessionProvider>();
    // provider.state.box 변경 시 최신 item을 다시 조회(향 올리기/보내기 직후 즉시 반영).
    final item = provider.state.box.firstWhere(
      (b) => b.no == widget.item.no,
      orElse: () => widget.item,
    );
    final life = lifeOf(item);
    final warnBorder = life.st == 'wane'
        ? const Color(0x8CC98A3A)
        : life.st == 'gone'
        ? const Color(0x99E0412F)
        : C.goldLine;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warnBorder),
        color: life.st == 'gone'
            ? const Color(0x1FA11D19)
            : const Color(0x4D000000),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: life.st == 'sent'
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFB8241F), Color(0xFF6E0F0C)],
                            ),
                      color: life.st == 'sent'
                          ? const Color(0xFF4A4440)
                          : null,
                    ),
                    child: Text(
                      life.s.k,
                      style: T(1).display(17, w: FontWeight.w900, c: C.btnText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          life.s.label,
                          style: T(1).body(14.5, w: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          life.s.note,
                          style: T(1).body(12, c: C.muted, h: 1.55),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (life.st != 'sent') ...[
                const SizedBox(height: 10),
                LifeBar(life: life),
              ],
              // [U9-4 포팅] 원본: `(L.st !== 'sent' && L.st !== 'gone') ? <div
              // className={'lp-dev r'+dv.rank}>...</div> : null`.
              if (life.st != 'sent' && life.st != 'gone') Builder(builder: (_) {
                final dv = devotionOf(item, nowMs());
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    DevotionMark(dv: dv, small: true),
                    if (dv.rank > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        if (dv.rank > 0) TextSpan(text: '${kDevName[dv.rank]} · '),
                        TextSpan(text: '향 ${dv.streak}일째 이어 올림'),
                        if (dv.rank < 2) TextSpan(text: ' · ${dv.rank > 0 ? 21 : 7}일이면 테두리가 ${dv.rank > 0 ? '붉은 금빛' : '금빛'}으로'),
                      ]), style: T(1).ui(11.5, c: dv.rank == 2 ? const Color(0xFFFF9A86) : dv.rank == 1 ? C.gold : C.muted)),
                    ),
                  ]),
                );
              }),
              const SizedBox(height: 10),
              Text(
                life.st == 'sent'
                    ? '받은 날 ${item.date}'
                          '${item.sentAt != null ? ' · 보낸 날 ${_fmtDate(item.sentAt!)}' : ''}'
                    : '받은 지 ${life.age}일 · 수명 $kLifeDays일 · 향 ${item.tended}번',
                style: T(1).mono.copyWith(fontSize: 10.5, color: C.faint),
              ),
              if (life.st == 'full' || life.st == 'born' || life.st == 'wane') ...[
                const SizedBox(height: 10),
                _smallButton(
                  label: life.tendedToday
                      ? '오늘은 향을 올렸습니다 · 내일 다시'
                      : '香 향 올리기 — 기운 +$kTendDays일',
                  enabled: !life.tendedToday,
                  danger: !life.tendedToday,
                  onTap: () => _tend(provider),
                ),
              ],
              if (life.st == 'gone') ...[
                const SizedBox(height: 10),
                _smallButton(
                  label: _burning ? '태워 보내는 중…' : '火 보내 드리기 — 태워서 돌려보냅니다',
                  enabled: !_burning,
                  danger: true,
                  onTap: () => _send(provider),
                ),
              ],
            ],
          ),
          if (_burning)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 1.1,
                      colors: [Color(0xE6E0412F), Colors.transparent],
                      stops: [0, .75],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _smallButton({
    required String label,
    required bool enabled,
    required bool danger,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: enabled && danger ? redButtonGradient : null,
        color: enabled && danger ? null : const Color(0x1AEFE4D2),
        border: enabled && danger
            ? null
            : Border.all(color: const Color(0x47EFE4D2)),
      ),
      child: Text(
        label,
        style: T(1).ui(
          12.5,
          w: FontWeight.w600,
          c: enabled && danger ? C.btnText : C.muted,
        ),
      ),
    ),
  );
}

String _fmtDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
