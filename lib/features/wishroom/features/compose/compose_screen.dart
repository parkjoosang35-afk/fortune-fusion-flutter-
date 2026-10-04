// SCR-02 소원 작성 `/compose` — docs/SCREENS.md §SCR-02 · docs/CHANGELOG.md §소원 봉인(타임캡슐)
// 한지 카드(텍스트 100자) + 수호자 선택 + 테마/빛깔/종이 + 공개범위 + 봉인일(SealDatePicker) + CTA.
// 봉인일 선택은 app2/capsule2.jsx의 SealGuideCard/SealDatePicker/SealConfirm을 그대로 따른다:
// 소원을 봉인하려면 반드시 봉인 날짜(내일~3년 이내)를 먼저 골라야 제출할 수 있다(sealUntil 필수).
// 제출 성공 시 인장 stamp 연출 후 인트로(full)로 자연 전환(WishRoomIntroScreen push replacement).
import 'dart:ui';
import 'package:flutter/material.dart' hide Visibility;
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_nav_pill.dart';
import '../intro/wish_room_intro_screen.dart';
import 'sealed_done_screen.dart';
import '../../core/wr_toast.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _textCtrl = TextEditingController();
  String? _char;
  Visibility _visibility = Visibility.PUBLIC;
  WrTheme _theme = WrTheme.free;
  String _wishColor = 'hope';
  String _paper = 'hanji';
  // [CHANGELOG §소원 봉인] 봉인일은 작성 단계에서 반드시 사용자가 직접 골라야 한다 —
  // 내일부터 3년 이내, 미선택 상태(null)로 시작. 고르기 전에는 제출 자체가 막힌다.
  DateTime? _sealUntil;
  bool _submitting = false;
  bool _piiWarning;
  bool _asking = false; // SealConfirm 표시 여부

  _ComposeScreenState() : _piiWarning = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  List<WrCharacter> get _myChars {
    final me = context.read<WishRoomProvider>().me;
    final owned = me?.ownedChars ?? const ['F00', 'M00'];
    final all = WrCatalog.I.characters;
    final list = all.where((c) => owned.contains(c.id)).toList();
    return list.isEmpty ? all.take(2).toList() : list;
  }

  Future<void> _submit({bool force = false}) async {
    if (_textCtrl.text.trim().isEmpty || _char == null || _sealUntil == null) return;
    setState(() {
      _asking = false;
      _submitting = true;
    });
    final p = context.read<WishRoomProvider>();
    final ok = await p.createRoom(
      text: _textCtrl.text.trim(),
      char: _char!,
      sealUntil: _fmtIso(_sealUntil!),
      visibility: _visibility,
      theme: _theme,
      wishColor: _wishColor,
      paper: _paper,
      force: force,
    );
    setState(() => _submitting = false);
    if (!mounted) return;
    if (ok) {
      // app2/capsule2.jsx SealedDone — 제출 성공 → 두루마리 말림/인장 연출 → "소원방 들어가기" → full 인트로.
      // 원본 submit(): setAsk(false) → setSealing(true) → 1.5s 뒤 setDone(true) → SealedDone onGo={reload('intro')}.
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SealedDoneScreen(
        date: _sealUntil!,
        text: _textCtrl.text.trim(),
        wishColor: _wishColor,
        onGo: () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WishRoomIntroScreen()));
        },
      )));
      return;
    }
    final err = p.lastError;
    if (err?.code == 'PII_WARNING') {
      setState(() => _piiWarning = true);
    } else if (err != null) {
      WrToast.show(context, err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final hasHistory = context.watch<WishRoomProvider>().archiveRooms.isNotEmpty;
    final canSubmit = _textCtrl.text.trim().isNotEmpty && _char != null && _sealUntil != null && !_submitting;
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        body: Stack(fit: StackFit.expand, children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                .45, 0, 0, 0, 0, //
                0, .45, 0, 0, 0, //
                0, 0, .45, 0, 0, //
                0, 0, 0, 1, 0,
              ]),
              child: Image.asset('assets/wishroom/room-main.jpg', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Stack(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 86, 18, 120),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hasHistory ? '새로운 마음을\n담아볼까요' : '소원을 담을\n준비가 되셨나요', style: WrF.display(26, height: 1.3)),
                  const SizedBox(height: 6),
                  Text('나의 소원을 정성스럽게 적어주세요.', style: WrF.body(13, color: WrC.muted)),
                  const SizedBox(height: 18),
                  // [A-3 §2] 소원방 테마 — 문서 순서상 한지 카드보다 먼저. 4열 그리드.
                  _sec('🌙 소원방 테마'),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (var i = 0; i < cat.themes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _themeCard(cat.themes[i])),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        _curTheme['desc'] as String,
                        key: ValueKey(_theme.name),
                        textAlign: TextAlign.center,
                        style: WrF.body(12, color: _hex(_curTheme['color'] as String)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // [A-3 §3] 한지 카드 — 소원빛깔 그라디언트 + 종이색 배경 + 8색 종이선택 통합.
                  _hanjiCard(),
                  if (_piiWarning)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: WrDeco.card.copyWith(border: Border.all(color: WrC.blossom)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('개인정보로 보일 수 있는 내용이 담겨 있어요', style: WrF.body(13, w: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('공개된 소원방에서는 다른 분들이 볼 수 있어요.', style: WrF.body(12, color: WrC.muted)),
                          const SizedBox(height: 10),
                          Row(children: [
                            _smallDarkBtn('고쳐 쓸게요', () => setState(() => _piiWarning = false)),
                            const SizedBox(width: 8),
                            _smallPinkBtn('그대로 담기', () => _submit(force: true)),
                          ]),
                        ]),
                      ),
                    ),
                  // [A-3 §5] 봉인일 선택 — PII 경고 다음, 소원빛깔/수호자보다 앞.
                  _sec('봉인일 선택'),
                  const SizedBox(height: 10),
                  WrSealDatePicker(value: _sealUntil, onChange: (d) => setState(() => _sealUntil = d)),
                  // [A-3 §6] 소원의 빛깔 — 4열×2 원형 카드.
                  _sec('소원의 빛깔'),
                  const SizedBox(height: 4),
                  Text('같은 빛깔의 아이템을 두면 기운이 1.5배로 닿아요', style: WrF.body(12, color: WrC.muted)),
                  const SizedBox(height: 12),
                  _wishColorGrid(),
                  const SizedBox(height: 10),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        '"${_curWishColor['desc']}"',
                        key: ValueKey(_wishColor),
                        style: WrF.body(12.5, color: _hex(_curWishColor['color'] as String)),
                      ),
                    ),
                  ),
                  // [A-3 §7] 함께할 수호자 — 우측 "{테마글리프} {테마} 의상으로 입어요" 라벨.
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('함께할 수호자', style: WrF.display(16)),
                      Text('${_curTheme['glyph']} ${_curTheme['label']} 의상으로 입어요', style: WrF.body(11, color: WrC.muted)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _myChars.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final ch = _myChars[i];
                        final sel = _char == ch.id;
                        return GestureDetector(
                          onTap: () => setState(() => _char = ch.id),
                          child: Container(
                            width: 96,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: sel ? WrC.card : Colors.transparent,
                              border: Border.all(color: sel ? WrC.blossom2 : WrC.line, width: sel ? 2 : 1),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: sel ? [const BoxShadow(color: WrC.blossomShadow, blurRadius: 18)] : null,
                            ),
                            child: Column(children: [
                              SizedBox(height: 104, width: double.infinity, child: Image.asset(cat.charImage(ch.id, _theme), fit: BoxFit.cover, alignment: Alignment.topCenter)),
                              const SizedBox(height: 4),
                              Text(ch.name, style: WrF.body(12.5, w: FontWeight.w700)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  _sec('공개 범위'),
                  const SizedBox(height: 10),
                  Row(children: [
                    _seg('모두에게', Visibility.PUBLIC),
                    const SizedBox(width: 6),
                    _seg('링크로만', Visibility.LINK),
                    const SizedBox(width: 6),
                    _seg('나만 보기', Visibility.PRIVATE),
                  ]),
                  const SizedBox(height: 8),
                  Text(_visibilityDesc(_visibility), style: WrF.body(12, color: WrC.muted, height: 1.6)),
                ]),
              ),
              // CTA — 하단 고정, 핑크 그라디언트 버튼(WrDeco.btnPink), 상태에 따라 문구가 바뀐다.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xF2100610)],
                      stops: [0, .4],
                    ),
                  ),
                  child: GestureDetector(
                    onTap: canSubmit ? () => setState(() => _asking = true) : null,
                    child: Opacity(
                      opacity: canSubmit ? 1 : .45,
                      child: Container(
                        height: WrSize.btnH,
                        alignment: Alignment.center,
                        decoration: WrDeco.btnPink,
                        child: _submitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_ctaLabel(), style: WrF.body(WrSize.btnFont, w: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
              if (_asking)
                WrSealConfirm(
                  date: _sealUntil!,
                  busy: _submitting,
                  onCancel: () => setState(() => _asking = false),
                  onOk: () => _submit(),
                ),
              // [명세위반 수정 — 전수감사] TopBar(NavPill + 중앙 타이틀)가 통째로
              // 누락돼 있었다. app2/fx2.jsx TopBar({title}) 1:1: absolute top:52,
              // 좌 NavPill, 중앙 disp 18px 타이틀("새로운 소원방 시작"/"소원 작성").
              Positioned(
                left: 0, right: 0, top: 0, height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    WrNavPill(onBack: () => Navigator.of(context).maybePop(), onExitHome: () => Navigator.of(context).popUntil((r) => r.isFirst)),
                    Expanded(child: Center(child: Text(hasHistory ? '새로운 소원방 시작' : '소원 작성',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: WrF.display(18)))),
                    const SizedBox(width: 60),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Map<String, dynamic> get _curTheme => WrCatalog.I.themes.firstWhere((t) => t['id'] == _theme.name);
  Map<String, dynamic> get _curWishColor => WrCatalog.I.wishColors.firstWhere((w) => w['id'] == _wishColor);
  Map<String, dynamic> get _curPaper => WrCatalog.I.papers.firstWhere((p) => p['id'] == _paper);

  /// [A-3 §2] 소원방 테마 카드 — 글리프(선택 시 bob) + 라벨, 선택 시 테마색 테두리·배경·글로우.
  Widget _themeCard(Map<String, dynamic> t) {
    final id = t['id'] as String;
    final sel = _theme.name == id;
    final color = _hex(t['color'] as String);
    return GestureDetector(
      onTap: () => setState(() => _theme = WrTheme.values.byName(id)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: .14) : WrC.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? color : WrC.line, width: sel ? 1.5 : 1),
          boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: .4), blurRadius: 18)] : null,
        ),
        child: Column(children: [
          _BobGlyph(glyph: t['glyph'] as String, animate: sel),
          const SizedBox(height: 6),
          Text(t['label'] as String, style: WrF.body(12, w: FontWeight.w700)),
        ]),
      ),
    );
  }

  /// [A-3 §3] 한지 카드 — 소원빛깔 그라디언트 + 종이색 배경, 1행(날짜+8색 종이원), textarea, 하단(글자수+인장).
  Widget _hanjiCard() {
    final wc = _curWishColor;
    final wishColor = _hex(wc['color'] as String);
    final paper = _curPaper;
    final bg = (paper['bg'] as List).cast<String>();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [wishColor.withValues(alpha: .20), _hex(bg[0]), _hex(bg[1])],
          stops: const [0, .45, 1],
        ),
        border: Border.all(color: wishColor.withValues(alpha: .55), width: 1.5),
        boxShadow: [
          BoxShadow(color: wishColor.withValues(alpha: .35), blurRadius: 26),
          const BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text('오늘의 소원 · ${_dateLabel()}',
                style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 11, color: Color(0x993C2D1E))),
          ),
          // [A-3 §3] 종이 8색 동그라미 20x20 — 선택 시 테두리2px + 빛깔 링 + scale 1.15.
          Row(children: [
            for (final pp in WrCatalog.I.papers) ...[
              _paperDot(pp, wishColor),
              const SizedBox(width: 6),
            ],
          ]),
        ]),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${paper['label']} 종이', style: const TextStyle(fontFamily: 'GowunBatangWish', fontSize: 10, color: Color(0x993C2D1E))),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 120,
          child: TextField(
            controller: _textCtrl,
            maxLength: 100,
            maxLines: 4,
            cursorColor: wishColor,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 17, height: 1.65, color: Color(0xFF4A2A1C)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '마음속 바람을 적어주세요\n예) 우리 가족 모두 건강하고 행복하게 해주세요.',
              hintStyle: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 15, height: 1.5, color: Color(0x663C2D1E)),
              counterText: '',
            ),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_textCtrl.text.length} / 100', style: WrF.mono(size: 10, color: const Color(0x993C2D1E))),
          Opacity(
            opacity: _textCtrl.text.trim().isEmpty ? .3 : 1,
            child: WrSealGlyph(glyph: wc['hanja'] as String),
          ),
        ]),
      ]),
    );
  }

  Widget _paperDot(Map<String, dynamic> pp, Color wishColor) {
    final id = pp['id'] as String;
    final sel = _paper == id;
    final bg = (pp['bg'] as List).cast<String>();
    return GestureDetector(
      onTap: () => setState(() => _paper = id),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: sel ? 1.15 : 1,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_hex(bg[0]), _hex(bg[1])]),
            border: Border.all(color: sel ? wishColor : const Color(0x33000000), width: sel ? 2 : 1),
            boxShadow: sel ? [BoxShadow(color: wishColor.withValues(alpha: .6), blurRadius: 6)] : null,
          ),
        ),
      ),
    );
  }

  /// [A-3 §6] 소원의 빛깔 — 4열×2 카드, 30px 원(radial 그라디언트 + 한자13px) + 라벨11.
  Widget _wishColorGrid() {
    final colors = WrCatalog.I.wishColors;
    return Column(children: [
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: 10),
        Row(children: [
          for (var col = 0; col < 4; col++) ...[
            if (col > 0) const SizedBox(width: 8),
            Expanded(child: _wishColorCard(colors[row * 4 + col])),
          ],
        ]),
      ],
    ]);
  }

  Widget _wishColorCard(Map<String, dynamic> w) {
    final id = w['id'] as String;
    final sel = _wishColor == id;
    final color = _hex(w['color'] as String);
    final deep = _hex(w['deep'] as String);
    return GestureDetector(
      onTap: () => setState(() => _wishColor = id),
      child: Column(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Colors.white, color, deep]),
            border: sel ? Border.all(color: color, width: 2) : null,
            boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: .6), blurRadius: 10)] : null,
          ),
          child: Text(w['hanja'] as String, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF2A1F14))),
        ),
        const SizedBox(height: 4),
        Text(w['label'] as String, style: WrF.body(11, w: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? WrC.fg : WrC.muted)),
      ]),
    );
  }

  String _ctaLabel() {
    if (_textCtrl.text.trim().isEmpty) return '소원을 먼저 적어주세요';
    if (_sealUntil == null) return '봉인 날짜를 골라주세요';
    if (_char == null) return '수호자를 골라주세요';
    return '🔐 소원 봉인하기';
  }

  Widget _sec(String label) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 0),
        child: Text(label, style: WrF.display(16)),
      );

  Widget _seg(String label, Visibility v) {
    final sel = _visibility == v;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _visibility = v),
        child: Container(
          height: WrSize.tabH,
          alignment: Alignment.center,
          decoration: sel ? WrDeco.tabOn : BoxDecoration(borderRadius: BorderRadius.circular(WrR.tab), color: WrC.chipBg),
          child: Text(label, style: WrF.body(WrSize.tabFont, w: FontWeight.w700, color: sel ? Colors.white : WrC.muted)),
        ),
      ),
    );
  }

  String _visibilityDesc(Visibility v) {
    switch (v) {
      case Visibility.PUBLIC:
        return '모두의 소원방에 보여요. 누구나 응원하고 복주머니를 보낼 수 있어요.';
      case Visibility.LINK:
        return '모두의 소원방에는 보이지 않아요. 소원방을 만든 뒤 공유 버튼으로 링크를 보내면, 받은 분만 들어와 응원할 수 있어요.';
      case Visibility.PRIVATE:
        return '나만 볼 수 있어요. 응원이나 복주머니는 받을 수 없어요.';
    }
  }

  Widget _smallDarkBtn(String label, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(height: WrSize.btnSmH, alignment: Alignment.center, decoration: WrDeco.btnDark, child: Text(label, style: WrF.body(WrSize.btnSmFont, w: FontWeight.w700))),
        ),
      );

  Widget _smallPinkBtn(String label, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(height: WrSize.btnSmH, alignment: Alignment.center, decoration: WrDeco.btnPink, child: Text(label, style: WrF.body(WrSize.btnSmFont, w: FontWeight.w700, color: Colors.white))),
        ),
      );

  // golden/10_compose.png 기준 날짜 포맷: YYYY.MM.DD (0패딩, 점 사이 공백 없음)
  String _dateLabel() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }

  String _fmtIso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

/// [A-3 §2] 테마 글리프 — 선택 시 `bob 2.6s ∞` (상하 살짝 떠다니는 애니메이션).
class _BobGlyph extends StatefulWidget {
  const _BobGlyph({required this.glyph, required this.animate});
  final String glyph;
  final bool animate;
  @override
  State<_BobGlyph> createState() => _BobGlyphState();
}

class _BobGlyphState extends State<_BobGlyph> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(widget.glyph, style: const TextStyle(fontSize: 24));
    if (!widget.animate) return text;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(offset: Offset(0, -3 * _ctrl.value), child: child),
      child: text,
    );
  }
}

/// 한지 카드 우상단 願 인장 — WrDeco.seal 1:1.
class WrSealGlyph extends StatelessWidget {
  const WrSealGlyph({super.key, required this.glyph});
  final String glyph;
  @override
  Widget build(BuildContext context) => Container(
        width: WrSize.sealBox,
        height: WrSize.sealBox,
        alignment: Alignment.center,
        decoration: WrDeco.seal,
        child: Text(glyph, style: WrF.display(18, color: const Color(0xFFFFF9E8))),
      );
}

/// app2/capsule2.jsx SealGuideCard — 접고 펼 수 있는 "소원 봉인이란" 안내 카드.
/// 접힌 상태(기본)에서는 작은 pill 버튼만 보이고, 탭하면 4단계 설명이 펼쳐진다.
class WrSealGuideCard extends StatefulWidget {
  const WrSealGuideCard({super.key});
  @override
  State<WrSealGuideCard> createState() => _WrSealGuideCardState();
}

class _WrSealGuideCardState extends State<WrSealGuideCard> {
  bool _open = false;

  static const _steps = [
    ('✍', '소원 적기', '마음속 바람을 두루마리에 적어요'),
    ('📅', '날짜 고르기', '내일부터 3년 안, 간직할 날을 정해요'),
    ('🔐', '봉인', '그날까지 소원을 조용히 맡겨둬요'),
    ('🎁', '봉인이 풀리는 날', '알림이 오면 두루마리를 펼쳐요'),
  ];

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return GestureDetector(
        onTap: () => setState(() => _open = true),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 11, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0x1AFFDC96),
            border: Border.all(color: const Color(0x59FFDC96)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xEBF2628F)),
              child: Text('?', style: WrF.display(10, color: Colors.white)),
            ),
            const SizedBox(width: 5),
            Text('소원 봉인이란', style: WrF.body(11.5, w: FontWeight.w700, color: const Color(0xFFFFE6B8))),
          ]),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x47FFDC96)),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x14FFDC96), Color(0x0FFF96BE)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _open = false),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Text('SEAL · 소원 봉인이란', style: WrF.mono(size: 10, color: const Color(0xFFFFE08A))),
              const Spacer(),
              Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x40000000)),
                  child: Text('✕', style: WrF.body(11, color: WrC.muted))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: TextSpan(style: WrF.body(13.5, height: 1.7), children: [
                const TextSpan(text: '지금의 소원을 '),
                TextSpan(text: '미래의 나에게', style: WrF.body(13.5, w: FontWeight.w700, color: const Color(0xFFFFE08A))),
                const TextSpan(text: ' 맡겨두는 거예요.\n봉인한 날이 오면, 그때의 마음을 다시 꺼내볼 수 있어요.'),
              ]),
            ),
            const SizedBox(height: 12),
            for (final s in _steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2A1020), border: Border.all(color: const Color(0x73FFDC96))),
                    child: Text(s.$1, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.$2, style: WrF.body(12.5, w: FontWeight.w700)),
                      Text(s.$3, style: WrF.body(11.5, color: WrC.muted)),
                    ]),
                  ),
                ]),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x59FFDC96))),
              child: Text(
                '· 기다리는 동안에도 촛불을 밝히고, 정성을 들이고, 방을 꾸밀 수 있어요.\n'
                '· 봉인 날짜는 한 번 정하면 바꿀 수 없어요. 천천히 골라주세요.\n'
                '· 그전에 이루어졌다면 언제든 "소원이 이루어졌어요"를 누를 수 있어요.',
                style: WrF.body(11.5, color: const Color(0xD9FFF0DC), height: 1.6),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// app2/capsule2.jsx SealDatePicker — 네이티브 날짜 선택 + 100일/1년/2년/3년 빠른 선택.
class WrSealDatePicker extends StatelessWidget {
  const WrSealDatePicker({super.key, required this.value, required this.onChange});
  final DateTime? value;
  final ValueChanged<DateTime> onChange;

  DateTime get _today => DateTime.now();
  DateTime get _min => DateTime(_today.year, _today.month, _today.day).add(const Duration(days: 1));
  DateTime get _max => DateTime(_today.year + 3, _today.month, _today.day);

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? _min,
      firstDate: _min,
      lastDate: _max,
      helpText: '봉인 날짜 선택',
    );
    if (picked != null) onChange(picked);
  }

  void _preset(int days, int years) {
    final base = DateTime(_today.year, _today.month, _today.day);
    onChange(years > 0 ? DateTime(base.year + years, base.month, base.day) : base.add(Duration(days: days)));
  }

  int get _left => value == null ? 0 : value!.difference(DateTime(_today.year, _today.month, _today.day)).inDays;

  String _fmtK(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const WrSealGuideCard(),
      const SizedBox(height: 14),
      Text('🔐 이 소원을 언제까지 간직할까요?', style: WrF.body(14, w: FontWeight.w700)),
      const SizedBox(height: 3),
      Text('내일부터 3년 안에서 고를 수 있어요', style: WrF.body(11.5, color: WrC.muted)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => _openPicker(context),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: value != null
              ? WrDeco.card.copyWith(border: Border.all(color: const Color(0x99FFDC96)), color: const Color(0x14FFDC96))
              : WrDeco.card,
          child: Row(children: [
            const Text('📅', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(value != null ? _fmtK(value!) : '봉인 날짜 선택', style: WrF.body(15, w: FontWeight.w700, color: value != null ? WrC.fg : WrC.muted))),
            Text(value != null ? '바꾸기' : '날짜 직접 선택', style: WrF.mono(size: 10, color: WrC.muted)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        _presetChip('100일', () => _preset(100, 0)),
        const SizedBox(width: 6),
        _presetChip('1년', () => _preset(0, 1)),
        const SizedBox(width: 6),
        _presetChip('2년', () => _preset(0, 2)),
        const SizedBox(width: 6),
        _presetChip('3년', () => _preset(0, 3)),
      ]),
      if (value != null)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x59FFDC96)),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1FFFDC96), Color(0x14FF96BE)]),
          ),
          child: Row(children: [
            Expanded(
              child: RichText(
                text: TextSpan(style: WrF.body(13.5, height: 1.55), children: [
                  const TextSpan(text: '✨ '),
                  TextSpan(text: _fmtK(value!), style: WrF.body(13.5, w: FontWeight.w700, color: const Color(0xFFFFE08A))),
                  const TextSpan(text: '까지\n소원을 봉인합니다.'),
                ]),
              ),
            ),
            Text('D-$_left', style: WrF.display(24, color: const Color(0xFFFFE08A))),
          ]),
        ),
    ]);
  }

  Widget _presetChip(String label, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(height: 34, alignment: Alignment.center, decoration: WrDeco.chip, child: Text(label, style: WrF.body(12, w: FontWeight.w700, color: WrC.muted))),
        ),
      );
}

/// app2/capsule2.jsx SealConfirm — dim 오버레이 + "이 소원을 봉인할까요?" 확인창.
class WrSealConfirm extends StatelessWidget {
  const WrSealConfirm({super.key, required this.date, required this.onCancel, required this.onOk, required this.busy});
  final DateTime date;
  final VoidCallback onCancel, onOk;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // app2/capsule2.jsx › SealConfirm `API.dayDiff(API.kstDate(), date)` 1:1 —
    // [버그수정 — 전수감사] 기존엔 DateTime.now()(시:분 포함)로 차를 구하고 +1까지
    // 더해 SealDatePicker가 보여주는 D-값과 어긋났다(하루 밀림). 자정 기준 절삭 + +1 제거.
    final today = DateTime.now();
    final left = date.difference(DateTime(today.year, today.month, today.day)).inDays;
    return Stack(children: [
      GestureDetector(
        onTap: onCancel,
        child: Container(color: const Color(0x80080308)),
      ),
      Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x4DFFC8AA)),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A1630), Color(0xFF1E0A16)]),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 50, offset: Offset(0, 20)), BoxShadow(color: Color(0x26FFBE8C), blurRadius: 40)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔐', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text('이 소원을 봉인할까요?', style: WrF.display(19), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('봉인 날짜가 되면\n다시 소원을 확인할 수 있습니다.', textAlign: TextAlign.center, style: WrF.body(13, color: WrC.muted, height: 1.65)),
            const SizedBox(height: 12),
            Text('${date.year}년 ${date.month}월 ${date.day}일 · D-$left', style: WrF.body(12.5, w: FontWeight.w700, color: const Color(0xFFFFE08A))),
            const SizedBox(height: 8),
            Text('봉인 날짜는 나중에 바꿀 수 없어요', style: WrF.body(11, color: WrC.muted)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(height: 48, alignment: Alignment.center, decoration: WrDeco.btnDark, child: Text('취소', style: WrF.body(15, w: FontWeight.w700))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: busy ? null : onOk,
                  child: Opacity(
                    opacity: busy ? .6 : 1,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: WrDeco.btnPink,
                      child: busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('봉인하기', style: WrF.body(15, w: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }
}
