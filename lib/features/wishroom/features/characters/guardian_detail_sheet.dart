// SCR-05-C 수호자 자세히 — app3/guardians.jsx › GuardianDetail 1:1 포팅.
// [Stage 3-B — 대표 판정 "3-A 옷장 완료 승인 → 3-B 수호자 자세히를 시작하세요"]
// character_shop_screen.dart _infoSheet()에 있던 3-A 임시 버전("자세히 화면이
// 아직 따로 없어 그 역할을 하는 정보 시트에 옷 갈아입히기 버튼만 우선 추가")을
// 대체하는 정식 "수호자 자세히" 시트. 아래 2곳에서 공용으로 연다:
//   1) 수호자 탭 「함께하는 수호자」 카드의 [자세히] 버튼 · 목록 카드 탭
//   2) 방 화면에서 수호자(캐릭터)를 직접 눌렀을 때(main_room_screen.dart onTapGuardian)
//
// 큰 그림 · 테마 옷 4벌 미리보기 · 한마디 · 하는 일 · 성향 · 성격 · 좋아하는 것 ·
// 지켜주는 소원(+ 내 소원과 잘 맞아요 배지) · 상태별 CTA 1개(함께하기 / 🔒 N일 뒤 /
// 🧧 모셔오기(PayScreen) / 이벤트로만 / 옷 갈아입히기).
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_toast.dart';
import '../shop/pay_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

/// 어디서든(수호자 탭 · 방 화면) 동일하게 호출하는 수호자 자세히 시트 오프너.
void showGuardianDetailSheet(BuildContext context, String characterId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => GuardianDetailSheet(characterId: characterId),
  );
}

class GuardianDetailSheet extends StatefulWidget {
  const GuardianDetailSheet({super.key, required this.characterId});
  final String characterId;
  @override
  State<GuardianDetailSheet> createState() => _GuardianDetailSheetState();
}

class _GuardianDetailSheetState extends State<GuardianDetailSheet> {
  // 테마 옷 미리보기 선택(아직 저장 안 함 — app3/guardians.jsx `look` 1:1).
  String? _look;
  bool _busy = false;

  static const _gradeInfo = {
    'basic': ('기본', Color(0xFFBFE8C8)),
    'normal': ('일반', Color(0xFFCFD8FF)),
    'rare': ('희귀', Color(0xFFFFD88A)),
    'event': ('이벤트', Color(0xFFFFB0D0)),
  };

  int _leftDays(WishRoom? room, String key) {
    final unlockDay = (WrCatalog.I.raw['UNLOCK'] as Map)[key] as int? ?? 0;
    final dayN = room?.dayN ?? 1;
    return math.max(1, unlockDay - dayN);
  }

  // 조사(을/를, 이/가) 선택 — 받침 유무 판정. entrust_sheet.dart _josa() 1:1.
  bool _hasBatchim(String s) {
    if (s.isEmpty) return false;
    final code = s.codeUnitAt(s.length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return false;
    return (code - 0xAC00) % 28 != 0;
  }

  String _josa(String name, String withBatchim, String noBatchim) =>
      _hasBatchim(name) ? withBatchim : noBatchim;

  void _goWardrobe(BuildContext context, WishRoom? room) {
    if (!(room?.isFeatureUnlocked('wardrobe') ?? false)) {
      WrToast.show(context, '옷장은 ${_leftDays(room, 'wardrobe')}일 뒤에 열려요');
      return;
    }
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WardrobeScreen()));
  }

  Future<void> _chooseGuardian(
    BuildContext context,
    WishRoomProvider p,
    WrCharacter c,
  ) async {
    if (_busy) return;
    if (p.room?.guardianAway != null) {
      WrToast.show(context, '함께하는 수호자가 기도하러 나가 있어요 · 돌아오면 바꿀 수 있어요');
      return;
    }
    setState(() => _busy = true);
    final ok = await p.setCharacter(c.id);
    if (ok && p.room != null) await p.loadMyRoom();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      WrToast.show(context, '${c.name}${_josa(c.name, '이', '가')} 소원방을 함께 지켜요');
      Navigator.of(context).maybePop();
    } else {
      WrToast.show(context, p.lastError?.message ?? '수호자 변경에 실패했어요');
    }
  }

  void _buy(BuildContext context, WishRoomProvider p, WrCharacter c) {
    final cat = WrCatalog.I;
    final order = PayOrder(
      kind: 'char',
      name: '${c.name} 수호자',
      sub: '${c.title}${c.job != null ? ' · ${c.job}' : ''}',
      img: cat.charImage(c.id, WrTheme.free),
      price: c.price ?? 0,
      doneTitle: '${c.name}${_josa(c.name, '이', '가')} 소원방에 찾아왔어요',
      afterLabel: '👗 옷 갈아입히기',
      after: () {
        final room = p.room;
        if (room != null && room.isFeatureUnlocked('wardrobe')) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WardrobeScreen()));
        }
      },
      onConfirmPay: (idempotencyKey) async {
        final ok = await p.buyCharacter(c.id, idempotencyKey: idempotencyKey);
        if (!ok) return false;
        final ok2 = await p.setCharacter(c.id);
        if (ok2) await p.loadMyRoom();
        return ok2;
      },
    );
    // app3/guardians.jsx `onClose() || app.checkout(...)` 1:1 — 자세히 시트를
    // 먼저 닫고 결제창(PayScreen)을 연다. Navigator.pop() 직후에도 같은
    // context로 push하는 것은 이 모듈 다른 화면에서도 쓰는 안전한 패턴이다.
    Navigator.of(context).pop();
    openPayScreen(context, order);
  }

  Widget _cta(
    BuildContext context,
    WishRoomProvider p,
    WrCharacter c,
    bool owned,
    bool on,
    WishRoom? room,
  ) {
    Widget btn;
    if (on) {
      final unlocked = room?.isFeatureUnlocked('wardrobe') ?? false;
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _goWardrobe(context, room),
          style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
          child: Text(
            unlocked ? '👗 옷 갈아입히기' : '🔒 옷장은 ${_leftDays(room, 'wardrobe')}일 뒤에 열려요',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      );
    } else if (owned) {
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _busy ? null : () => _chooseGuardian(context, p, c),
          style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
          child: const Text(
            '이 수호자와 함께하기',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      );
    } else if (c.grade == 'event') {
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
          child: Text(
            '🎐 이벤트 미션으로만 만날 수 있어요',
            style: WrF.body(14, color: Colors.white54),
          ),
        ),
      );
    } else if (!(room?.isFeatureUnlocked('shop') ?? false)) {
      final left = _leftDays(room, 'shop');
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => WrToast.show(context, '$left일 뒤 상점이 열려요'),
          style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
          child: Text(
            '🔒 $left일 뒤 상점에서 모실 수 있어요',
            style: WrF.body(14, color: Colors.white54),
          ),
        ),
      );
    } else {
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _buy(context, p, c),
          style: ElevatedButton.styleFrom(backgroundColor: WrC.glow),
          child: Text(
            '🧧 ${c.price ?? 0} · 모셔오기',
            style: const TextStyle(
              color: Color(0xFF4A2A10),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      );
    }
    // [QA 테스트 보조 — 대표 지시, 기본 규칙화] wardrobe_screen.dart _ctaButton()과
    // 동일 패턴: 상태별로 버튼 내용은 달라도 이름표는 하나로 고정해 좌표 없이도
    // 누를 수 있게 한다.
    return Semantics(identifier: 'guardian_detail_cta', button: true, child: btn);
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(k, style: WrF.body(12.5, color: WrC.muted)),
        ),
        Expanded(
          child: Text(
            v,
            style: WrF.body(12.5, w: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  Widget _wishRow(Map<String, dynamic>? w, bool match) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text('지켜주는 소원', style: WrF.body(12.5, color: WrC.muted)),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                w != null ? '${w['hanja']} ${w['label']}' : '—',
                style: WrF.body(
                  12.5,
                  w: FontWeight.w700,
                  color: w != null ? _hex(w['color'] as String) : Colors.white,
                ),
              ),
              if (match)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: w != null ? _hex(w['color'] as String) : WrC.blossom,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '내 소원과 잘 맞아요',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Color(0xFF2A1020),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final p = context.watch<WishRoomProvider>();
    final c = p.characters
        .where((x) => x.id == widget.characterId)
        .firstOrNull;
    if (c == null) return const SizedBox.shrink();
    final room = p.room;
    final owned = p.me?.ownedChars.contains(c.id) ?? (c.price == 0);
    final on = room?.char == c.id;
    final art = Map<String, dynamic>.from(
      (cat.raw['OUTFIT_ART'] as Map)[c.id] as Map? ?? const {},
    );
    final look = _look ?? (on ? room!.outfitNow.name : 'free');
    final rawArt = art[look] as String?;
    final imgPath = rawArt != null
        ? 'assets/wishroom/${rawArt.replaceFirst('assets/', '')}'
        : cat.charImage(c.id, WrTheme.free);
    final wc = cat.wishColors.where((w) => w['id'] == c.aura).toList();
    final w = wc.isNotEmpty ? wc.first : null;
    final match = room != null && c.aura == room.wishColor;
    final gi = _gradeInfo[c.grade] ?? _gradeInfo['basic']!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .88,
          ),
          decoration: WrDeco.sheet,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 상단 큰 그림 ──
              SizedBox(
                height: 250,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, .5),
                            radius: 1.1,
                            colors: [
                              (w != null ? _hex(w['color'] as String) : WrC.blossom)
                                  .withValues(alpha: .28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: Image.asset(
                          imgPath,
                          key: ValueKey(look),
                          height: 240,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => SizedBox(
                            height: 240,
                            child: Center(
                              child: Text(
                                c.emblem,
                                style: const TextStyle(
                                  fontSize: 64,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: gi.$2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          gi.$1,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: Color(0xFF2A1020),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: Semantics(
                        identifier: 'guardian_detail_close',
                        button: true,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: WrC.glass,
                              shape: BoxShape.circle,
                              border: Border.all(color: WrC.line),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 테마 옷 4벌 미리보기
                    Positioned(
                      right: 12,
                      top: 56,
                      child: Column(
                        children: [
                          for (final t in ['free', 'god', 'buddha', 'shaman'])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Semantics(
                                identifier: 'guardian_detail_outfit_$t',
                                button: true,
                                child: GestureDetector(
                                  onTap: () => setState(() => _look = t),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: look == t
                                            ? WrC.blossom2
                                            : WrC.line,
                                        width: look == t ? 2 : 1,
                                      ),
                                      image: art[t] != null
                                          ? DecorationImage(
                                              image: AssetImage(
                                                'assets/wishroom/${(art[t] as String).replaceFirst('assets/', '')}',
                                              ),
                                              fit: BoxFit.cover,
                                              alignment: const Alignment(0, -.8),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: c.name,
                              style: WrF.display(22, color: Colors.white),
                            ),
                            TextSpan(
                              text: '  ${c.title}',
                              style: WrF.body(13, color: WrC.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '"${c.line}"',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFFFFE6D0),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _row('하는 일', c.job ?? '—'),
                      _row('성향', c.type ?? '—'),
                      _row('성격', c.personality ?? '—'),
                      _row('좋아하는 것', c.likes ?? '—'),
                      _wishRow(w, match),
                      const SizedBox(height: 18),
                      _cta(context, p, c, owned, on, room),
                      if (!owned && c.price != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '복주머니는 기도 · 함께 빌기로 적립돼요',
                            textAlign: TextAlign.center,
                            style: WrF.body(11, color: WrC.muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _hex(String s) {
  final h = s.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}
