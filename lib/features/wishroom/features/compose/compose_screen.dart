// SCR-02 소원 작성 `/compose` — docs/SCREENS.md §SCR-02 · docs/CHANGELOG.md §소원 봉인(타임캡슐)
// [S1 재구축 — 2026-11] app3/start.jsx `Write3({app})` 1:1 포팅으로 전면 재작성.
// 한지 카드(60자) + 갈래 인장 8개(WC_ORDER) + 종이색 + 갈래별 예시 48개 토글.
// 기존에 있던 테마 선택 · 수호자 선택 · 봉인일 선택 · 공개범위 선택 UI는 모두
// 제거했다 — 각각 자유 방(free) · 하린(F00, null→서버 기본값) · 봉인 없음(null) ·
// 나만 보기(PRIVATE) 자동값으로 대체되고, 나중에 ⋯(더보기) 메뉴에서 바꿀 수 있다
// (「방 분위기」 7일째 · 「수호자」 2일째 · 「타임캡슐로 남기기」 · 「함께 빌어달라고 하기」).
// 문구 검사(checkWishText)는 app3/flow.js `checkText(t)` 1:1 포팅 — 나쁜 말은 막고,
// 전화번호·링크는 한 번 더 누르면 그대로 담을 수 있게 경고만, 위기 표현은 막지 않고
// 109(자살예방 상담) 안내만 보여준다.
// 제출 성공 시 "봉인 완료" 두루마리(SealedDoneScreen) 대신 "촛불 켜기" 연출
// (WishLightScreen)로 이동한다 — SealedDoneScreen은 capsule_screen.dart(REWISH
// 타임캡슐 플로우)에서 여전히 재사용 중이므로 그대로 둔다.
import 'dart:ui';
import 'package:flutter/material.dart' hide Visibility;
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../intro/wish_room_intro_screen.dart';
import 'wish_light_screen.dart';
import '../../core/wr_toast.dart';
import '../../../fortune/shared/domain/reading_artifact.dart';
import '../../../fortune/shared/data/reading_wish_link_store.dart';

/// app3/start.jsx `WC_ORDER` 1:1 — 갈래 인장 UI 표시 순서(바람이 맨 앞).
const _wcOrder = [
  'hope',
  'health',
  'study',
  'career',
  'love',
  'family',
  'wealth',
  'peace',
];

/// app3/start.jsx `WC_SHORT` 1:1 — 인장 아래 짧은 라벨.
const _wcShort = {
  'hope': '바람',
  'health': '건강',
  'study': '합격',
  'career': '일',
  'love': '인연',
  'family': '가족',
  'wealth': '재물',
  'peace': '평온',
};

/// 문구 검사 결과 심각도 — app3/flow.js `checkText()`의 level 1:1.
enum WrTextCheckLevel {
  /// 제출 자체를 막는다(너무 짧음 · 나쁜 말).
  block,

  /// 막지 않고 도움만 안내한다(위기 표현 → 109).
  care,

  /// 한 번 더 누르면 그대로 담을 수 있다(전화번호 · 링크 의심).
  warn,
}

class WrTextCheck {
  const WrTextCheck(this.code, this.level, this.msg);
  final String code;
  final WrTextCheckLevel level;
  final String msg;
}

const _badWords = ['시발', '씨발', '개새', '병신', '좆', '엠창', '지랄'];
const _crisisWords = ['죽고 싶', '자살', '사라지고 싶', '살기 싫'];
final RegExp _phoneRe = RegExp(r'01[016789][-\s.]?\d{3,4}[-\s.]?\d{4}');
final RegExp _urlRe = RegExp(
  r'(https?://|www\.|\.com\b|\.kr\b|카톡|오픈채팅)',
  caseSensitive: false,
);

/// app3/flow.js `checkText(t)` 1:1 포팅.
WrTextCheck? checkWishText(String raw) {
  final s = raw.trim();
  if (s.length < 2) {
    return const WrTextCheck(
      'SHORT',
      WrTextCheckLevel.block,
      '두 글자 이상 적어 주세요',
    );
  }
  if (_badWords.any((w) => s.contains(w))) {
    return const WrTextCheck(
      'BAD',
      WrTextCheckLevel.block,
      '마음을 다치게 하는 말은 담을 수 없어요',
    );
  }
  if (_crisisWords.any((w) => s.contains(w))) {
    return const WrTextCheck(
      'CRISIS',
      WrTextCheckLevel.care,
      '많이 힘드셨죠. 소원은 그대로 담을 수 있어요. 이야기할 곳이 필요하면 109(자살예방 상담, 24시간)에 전화해 주세요.',
    );
  }
  if (_phoneRe.hasMatch(s) || _urlRe.hasMatch(s)) {
    return const WrTextCheck(
      'PRIVACY',
      WrTextCheckLevel.warn,
      '전화번호나 주소는 빼는 게 좋아요 · 함께 빌기에 공개하면 다른 분도 볼 수 있어요',
    );
  }
  return null;
}

class ComposeScreen extends StatefulWidget {
  // [관상·손금 결과화면 + 소원방 봉인 통합 리디자인 v7, v7.1 "예외 경로"]
  // 활성 소원이 아예 없는 사용자가 관상/손금 총결과 화면에서 "이 풀이를 내
  // 소원에 봉인하기"를 눌렀을 때만 이 파라미터가 채워진 채로 열린다.
  // 소원 작성이 성공하면(_submit) 새로 만들어진 소원에 이 풀이를 함께
  // 동봉한다 — v7.1 원칙("풀이는 동봉물, 새 소원 생성 금지")의 유일한
  // 예외 경로가 바로 이 경우다(소원이 아예 없을 때만 새로 씀).
  const ComposeScreen({super.key, this.pendingReading});
  final ReadingArtifact? pendingReading;
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // [S1 재구축] 테마 · 공개범위는 더 이상 작성 화면에서 고르지 않는다 — 자유 방 /
  // 나만 보기 자동값으로 시작하고, 나중에 ⋯ 메뉴(「방 분위기」·「함께 빌어달라고
  // 하기」)에서 바꿀 수 있다. 수호자(char)와 봉인일(sealUntil)은 아예 state로
  // 들고 있지 않고 서버에 null로 보내 각각 기본 수호자(F00)·봉인 없음이 된다.
  final Visibility _visibility = Visibility.PRIVATE;
  final WrTheme _theme = WrTheme.free;

  String _wishColor = 'hope';
  String _paper = 'hanji';
  bool _submitting = false;
  bool _exOpen = true; // app3/start.jsx Write3 useState(true) — 처음부터 펼쳐짐
  bool _warnAck = false; // PII 경고(warn) 한 번 더 누르면 그대로 담기
  int _pulseTick = 0; // 갈래 바꿀 때 인장 pulse 애니메이션 트리거

  @override
  void initState() {
    super.initState();
    // [안내창 — 사용자 피드백 5] 완료된 소원방은 되돌릴 수 있도록 완료 후 7일간 남아
    // 있고, 그동안 서버가 새 봉인을 409 ROOM_EXISTS로 막는다. 이유를 모르면
    // "버튼이 먹통"으로 보이므로 작성 화면 진입 시점에 미리 안내한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = context.read<WishRoomProvider>().room;
      if (r != null && r.status.name == 'COMPLETED') _showCompletedNotice();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showCompletedNotice() {
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: WrC.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: WrC.line),
        ),
        title: Text(
          '새 소원은 조금 뒤에 봉인할 수 있어요',
          style: WrF.body(16.5, w: FontWeight.w800, color: WrC.fg),
        ),
        content: Text(
          '소원이 이루어진 방은 되돌릴 수 있도록 완료 후 7일간 소원방에 그대로 남아 있어요.\n\n이 유예 기간이 끝나면 새로운 소원을 봉인할 수 있어요. 그때까지 이루어진 소원의 기운이 방을 지켜줍니다.',
          style: WrF.body(13.5, height: 1.6, color: WrC.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: Text(
              '알겠어요',
              style: WrF.body(14, w: FontWeight.w700, color: WrC.blossom),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (_submitting) return;
    final chk = checkWishText(text);
    if (chk != null && chk.level == WrTextCheckLevel.block) return;
    if (chk != null && chk.level == WrTextCheckLevel.warn && !_warnAck) {
      setState(() => _warnAck = true);
      return;
    }
    setState(() => _submitting = true);
    final p = context.read<WishRoomProvider>();
    final ok = await p.createRoom(
      text: text,
      visibility: _visibility,
      theme: _theme,
      wishColor: _wishColor,
      paper: _paper,
      // 클라이언트가 이미 전화번호/링크 경고를 한 번 보여주고 사용자가 다시
      // 눌렀다면, 서버의 같은 취지 검사(PII_WARNING)도 함께 통과시킨다.
      force: chk?.level == WrTextCheckLevel.warn,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      // [v7 통합 — v7.1 예외 경로] 소원이 아예 없어 이 화면에서 "함께"
      // 새로 소원을 쓴 경우에만, 방금 생성된 소원에 대기 중이던 풀이를
      // 동봉한다(ReadingWishLinkStore — 서버 영속 전까지의 로컬 매핑).
      if (widget.pendingReading != null) {
        final newRoomId = context.read<WishRoomProvider>().room?.id;
        if (newRoomId != null) {
          await ReadingWishLinkStore.attach(
            newRoomId,
            widget.pendingReading!.id,
          );
        }
      }
      if (!mounted) return;
      // [S1 재구축] app3/flows.jsx Light3 — 글자가 촛불로 날아듦 → 갈래 인장
      // 쾅 → "이제 두 손 모아, 첫 기도를 올려볼까요" 연출 후 소원방 입장.
      // [버그수정] onGo 콜백이 바깥쪽(ComposeScreen, 곧 pushReplacement로
      // dispose됨)의 context를 캡처하면 나중에 탭해도 조용히 실패한다 —
      // 반드시 builder가 제공하는 새 context(lightCtx)를 써야 한다.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (lightCtx) => WishLightScreen(
            text: text,
            wishColor: _wishColor,
            onGo: () => Navigator.of(lightCtx).pushReplacement(
              MaterialPageRoute(builder: (_) => const WishRoomIntroScreen()),
            ),
          ),
        ),
      );
      return;
    }
    final err = p.lastError;
    if (err?.code == 'PII_WARNING') {
      setState(() => _warnAck = true);
      WrToast.show(context, '전화번호나 주소처럼 보이는 내용이 있어요 · 한 번 더 누르면 그대로 담아요');
    } else if (err?.code == 'ROOM_EXISTS') {
      // [안내창 — 사용자 피드백 5] "진행 중인 소원방이 있어요" 토스트 대신
      // 이유와 해제 시점을 알려주는 안내창을 보여준다.
      _showCompletedNotice();
    } else if (err != null) {
      WrToast.show(context, err.message);
    }
  }

  void _useExample(String text) {
    setState(() {
      _textCtrl.text = text;
      _textCtrl.selection = TextSelection.collapsed(offset: text.length);
      _exOpen = false;
      _warnAck = false;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Map<String, dynamic> get _curWishColor =>
      WrCatalog.I.wishColors.firstWhere((w) => w['id'] == _wishColor);
  Map<String, dynamic> get _curPaper =>
      WrCatalog.I.papers.firstWhere((p) => p['id'] == _paper);

  @override
  Widget build(BuildContext context) {
    final text = _textCtrl.text;
    final trimmed = text.trim();
    final chk = checkWishText(text);
    final canSubmit =
        trimmed.length >= 2 &&
        !_submitting &&
        chk?.level != WrTextCheckLevel.block;
    final archiveCount = context
        .watch<WishRoomProvider>()
        .archiveRooms
        .length;
    final banner = _checkBanner(chk, trimmed);
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  .45, 0, 0, 0, 0, //
                  0, .45, 0, 0, 0, //
                  0, 0, .45, 0, 0, //
                  0, 0, 0, 1, 0,
                ]),
                child: Image.asset(
                  'assets/wishroom/room-main.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              bottom: true,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 86, 18, 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'NEW WISH · ${(archiveCount + 1).toString().padLeft(3, '0')}',
                          style: WrF.mono(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '어떤 소원을\n담아둘까요',
                          textAlign: TextAlign.center,
                          style: WrF.display(28, height: 1.3),
                        ),
                        const SizedBox(height: 18),
                        // [S1 재구축] 소원 갈래 — 인장 8개, WC_ORDER 순서로 가로 1줄.
                        _wishColorRow(),
                        const SizedBox(height: 20),
                        // [v7 통합 — v7.1 예외 경로] 관상/손금 총결과 화면에서
                        // 넘어온 풀이가 있으면, 소원 작성이 끝나는 즉시 함께
                        // 봉인된다는 것을 미리 보여준다.
                        if (widget.pendingReading != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: _PendingReadingChip(
                              artifact: widget.pendingReading!,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        // [S1 재구축] 한지 카드 — 60자 제한, 테마/종이색은 유지하되
                        // 날짜·봉인 안내는 제거.
                        _hanjiCard(),
                        if (banner != null)
                          SizedBox(width: double.infinity, child: banner),
                        _paperRow(),
                        _examplesSection(),
                      ],
                    ),
                  ),
                  // CTA — 하단 고정, 핑크 그라디언트 버튼(WrDeco.btnPink).
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: canSubmit ? _submit : null,
                            child: Opacity(
                              opacity: canSubmit ? 1 : .45,
                              child: Container(
                                height: WrSize.btnH,
                                width: double.infinity,
                                alignment: Alignment.center,
                                decoration: WrDeco.btnPink,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _ctaLabel(),
                                        style: WrF.body(
                                          WrSize.btnFont,
                                          w: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '담은 소원은 나만 볼 수 있어요 · 나중에 고칠 수 있어요',
                            textAlign: TextAlign.center,
                            style: WrF.body(12, color: WrC.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // TopBar(NavPill + 중앙 타이틀) — app2/fx2.jsx TopBar({title}) 1:1.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          WrNavPill(
                            onBack: () => Navigator.of(context).maybePop(),
                            onExitHome: () => Navigator.of(
                              context,
                            ).popUntil((r) => r.isFirst),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text('소원 작성'),
                            ),
                          ),
                          const SizedBox(width: 60),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ctaLabel() => _submitting ? '촛불에 담는 중…' : '🕯 촛불에 소원 담기';

  /// [S1 재구축] 소원 갈래 인장 8개 — app3/start.jsx Write3 1:1
  /// (`gridTemplateColumns: repeat(8,1fr)`), WC_ORDER 순서.
  Widget _wishColorRow() {
    return Row(
      children: [
        for (final id in _wcOrder) ...[
          Expanded(child: _wishColorIcon(id)),
        ],
      ],
    );
  }

  Widget _wishColorIcon(String id) {
    final w = WrCatalog.I.wishColors.firstWhere((e) => e['id'] == id);
    final sel = _wishColor == id;
    final color = _hex(w['color'] as String);
    final deep = _hex(w['deep'] as String);
    return GestureDetector(
      onTap: () => setState(() {
        _wishColor = id;
        _pulseTick++;
        _warnAck = false;
      }),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: 36,
            height: 36,
            alignment: Alignment.center,
            transform: sel
                ? (Matrix4.identity()
                    ..translateByDouble(18.0, 18.0, 0, 1)
                    ..rotateZ(-6 * 3.1415926535 / 180)
                    ..scaleByDouble(1.08, 1.08, 1.08, 1)
                    ..translateByDouble(-18.0, -18.0, 0, 1))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: sel ? deep : const Color(0x8C140810),
              border: Border.all(
                color: sel ? color : const Color(0x2EFFE6D2),
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: .6),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              w['hanja'] as String,
              style: TextStyle(
                fontFamily: 'NotoSerifKR',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: sel ? const Color(0xFFFFF9E8) : color,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _wcShort[id] ?? '',
            style: WrF.body(
              11,
              w: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? WrC.fg : WrC.muted,
            ),
          ),
        ],
      ),
    );
  }

  /// [S1 재구축] 한지 카드 — app3/start.jsx Write3 두루마리(textarea) 1:1.
  /// 날짜 표시·봉인 안내 없이, 종이색 배경 + 60자 입력 + 하단(글자수+인장)만 남긴다.
  Widget _hanjiCard() {
    final wc = _curWishColor;
    final wishColor = _hex(wc['color'] as String);
    final paper = _curPaper;
    final bg = (paper['bg'] as List).cast<String>();
    final ink = _hex(paper['ink'] as String);
    final sub = _rgba(paper['sub'] as String);
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hex(bg[0]), _hex(bg[1])],
        ),
        border: focused
            ? Border.all(color: wishColor.withValues(alpha: .8), width: 2)
            : null,
        boxShadow: [
          const BoxShadow(
            color: Color(0x73000000),
            blurRadius: 28,
            offset: Offset(0, 8),
          ),
          if (focused)
            BoxShadow(color: wishColor.withValues(alpha: .55), blurRadius: 30),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✎ 내 마음을 내 말로 적어 주세요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: sub,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _textCtrl,
            focusNode: _focusNode,
            maxLength: 60,
            maxLines: 4,
            minLines: 3,
            cursorColor: wishColor,
            onChanged: (_) => setState(() => _warnAck = false),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 17,
              height: 1.7,
              color: ink,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText:
                  '예) ${(WrCatalog.I.wishTemplates[_wishColor] ?? const ['']).first}',
              hintStyle: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                height: 1.5,
                color: ink.withValues(alpha: .4),
              ),
              counterText: '',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_textCtrl.text.length} / 60',
                style: WrF.mono(size: 11, color: sub),
              ),
              TweenAnimationBuilder<double>(
                key: ValueKey(_pulseTick),
                tween: Tween(begin: .55, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: WrSealOrOrb(picked: true, color: wc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _checkBanner(WrTextCheck? chk, String trimmed) {
    if (chk == null || trimmed.length < 2) return null;
    Color bg, border;
    String prefix;
    switch (chk.level) {
      case WrTextCheckLevel.block:
        bg = const Color(0x2EF2628F);
        border = const Color(0x80F2628F);
        prefix = '⚠ ';
        break;
      case WrTextCheckLevel.care:
        bg = const Color(0x249AD8E8);
        border = const Color(0x739AD8E8);
        prefix = '🤍 ';
        break;
      case WrTextCheckLevel.warn:
        bg = const Color(0x24F5CF6A);
        border = const Color(0x73F5CF6A);
        prefix = 'ⓘ ';
        break;
    }
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text(
        '$prefix${chk.msg}'
        '${chk.level == WrTextCheckLevel.warn && _warnAck ? ' · 한 번 더 누르면 그대로 담아요' : ''}',
        style: WrF.body(12, height: 1.55),
      ),
    );
  }

  Widget _paperRow() {
    final wishColor = _hex(_curWishColor['color'] as String);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('종이', style: WrF.body(11.5, color: WrC.muted)),
          const SizedBox(width: 8),
          for (final pp in WrCatalog.I.papers) ...[
            _paperDot(pp, wishColor),
            const SizedBox(width: 6),
          ],
        ],
      ),
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
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_hex(bg[0]), _hex(bg[1])]),
            border: Border.all(
              color: sel ? Colors.white : const Color(0x40FFFFFF),
              width: sel ? 2 : 1,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: wishColor.withValues(alpha: .6),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  /// [S1 재구축] "막막하다면 … 소원 예시에서 골라 고쳐 쓰세요" 토글 패널 —
  /// app3/start.jsx Write3 1:1, 고른 갈래의 예시 6개만 2열 그리드로 보여준다.
  Widget _examplesSection() {
    final list = WrCatalog.I.wishTemplates[_wishColor] ?? const <String>[];
    final color = _hex(_curWishColor['color'] as String);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _exOpen = !_exOpen),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✦ ', style: TextStyle(color: color)),
                Flexible(
                  child: Text(
                    '막막하다면 ${_wcShort[_wishColor] ?? ''} 소원 예시에서 골라 고쳐 쓰세요',
                    textAlign: TextAlign.center,
                    style: WrF.body(13, color: WrC.muted),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _exOpen ? .5 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Text('⌄', style: WrF.body(13, color: WrC.muted)),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.5,
                children: [for (final e in list) _exampleCard(e, color)],
              ),
            ),
            crossFadeState: _exOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 400),
          ),
        ],
      ),
    );
  }

  Widget _exampleCard(String text, Color color) {
    return GestureDetector(
      onTap: () => _useExample(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0x991E0C18),
          border: Border.all(color: color.withValues(alpha: .27)),
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: WrF.body(12.5, height: 1.35, color: Colors.white),
        ),
      ),
    );
  }
}

/// [v7 통합] 대기 중인 풀이를 작성 화면 상단에 미리 보여주는 칩.
/// 디자인 핸드오프 ReadingArtifact.jsx `ArtifactChip` 1:1 정신 — 사진 없이
/// 인장 한자 + 요약(실측 N · 해석 N건)만 노출한다.
class _PendingReadingChip extends StatelessWidget {
  const _PendingReadingChip({required this.artifact});
  final ReadingArtifact artifact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x26F5CF6A), Color(0x0DF5CF6A)],
        ),
        border: Border.all(color: const Color(0x73F5CF6A)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFC94A3B),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              artifact.total.key,
              style: const TextStyle(
                fontFamily: 'NotoSerifKR',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFFFFF9E8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '◈ 담겨온 풀이 · ${artifact.kind.hanja}',
                  style: WrF.body(
                    10.5,
                    w: FontWeight.w700,
                    color: const Color(0xFFF5CF6A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  artifact.total.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WrF.body(14, w: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '해석 ${artifact.interpretedCount}건 · 사진 없이 보관돼요',
                  style: WrF.body(11, color: WrC.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _hex(String h) =>
    Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

/// 종이 JSON의 `sub` 필드("rgba(90,50,30,.6)")를 Color로 변환.
Color _rgba(String s) {
  final m = RegExp(
    r'rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)',
  ).firstMatch(s);
  if (m == null) return const Color(0x993C2D1E);
  final r = int.parse(m.group(1)!);
  final g = int.parse(m.group(2)!);
  final b = int.parse(m.group(3)!);
  final a = m.group(4) != null ? double.parse(m.group(4)!) : 1.0;
  return Color.fromRGBO(r, g, b, a);
}

/// [소원빛깔 → 인장] 선택한 빛깔 구슬(원형 구슬 — 방사형 그라디언트 + 한자 각인).
/// [S1 재구축] 이제 작성 화면 진입 시점부터 이미 한 갈래(hope)가 선택돼 있으므로
/// `picked`는 항상 true로 쓰인다 — 클래스 자체는 과거 "선택 전엔 願 인장"
/// 분기를 그대로 남겨, 다른 화면에서 재사용할 길을 열어둔다.
class WrSealOrOrb extends StatelessWidget {
  const WrSealOrOrb({super.key, required this.picked, this.color});
  final bool picked;
  final Map<String, dynamic>? color;
  @override
  Widget build(BuildContext context) {
    if (!picked || color == null) return const WrSealGlyph(glyph: '願');
    final c = _hex(color!['color'] as String);
    final deep = _hex(color!['deep'] as String);
    return Container(
      width: WrSize.sealBox,
      height: WrSize.sealBox,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Colors.white, c, deep]),
        border: Border.all(color: c, width: 2),
        boxShadow: [BoxShadow(color: c.withValues(alpha: .6), blurRadius: 10)],
      ),
      child: Text(
        color!['hanja'] as String,
        style: const TextStyle(
          fontFamily: 'NotoSerifKR',
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: Color(0xFF2A1F14),
        ),
      ),
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
/// [S1 재구축] 작성 화면에서는 더 이상 쓰지 않지만, capsule_screen.dart가
/// WrSealDatePicker를 통해 참조하므로(REWISH 타임캡슐 플로우) 그대로 둔다.
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xEBF2628F),
                ),
                child: Text('?', style: WrF.display(10, color: Colors.white)),
              ),
              const SizedBox(width: 5),
              Text(
                '소원 봉인이란',
                style: WrF.body(
                  11.5,
                  w: FontWeight.w700,
                  color: const Color(0xFFFFE6B8),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x47FFDC96)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x14FFDC96), Color(0x0FFF96BE)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = false),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Text(
                    'SEAL · 소원 봉인이란',
                    style: WrF.mono(size: 10, color: const Color(0xFFFFE08A)),
                  ),
                  const Spacer(),
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x40000000),
                    ),
                    child: Text('✕', style: WrF.body(11, color: WrC.muted)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: WrF.body(13.5, height: 1.7),
                    children: [
                      const TextSpan(text: '지금의 소원을 '),
                      TextSpan(
                        text: '미래의 나에게',
                        style: WrF.body(
                          13.5,
                          w: FontWeight.w700,
                          color: const Color(0xFFFFE08A),
                        ),
                      ),
                      const TextSpan(
                        text: ' 맡겨두는 거예요.\n봉인한 날이 오면, 그때의 마음을 다시 꺼내볼 수 있어요.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final s in _steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 27,
                          height: 27,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2A1020),
                            border: Border.all(color: const Color(0x73FFDC96)),
                          ),
                          child: Text(
                            s.$1,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.$2,
                                style: WrF.body(12.5, w: FontWeight.w700),
                              ),
                              Text(
                                s.$3,
                                style: WrF.body(11.5, color: WrC.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x59FFDC96)),
                  ),
                  child: Text(
                    '· 기다리는 동안에도 촛불을 밝히고, 정성을 들이고, 방을 꾸밀 수 있어요.\n'
                    '· 봉인 날짜는 한 번 정하면 바꿀 수 없어요. 천천히 골라주세요.\n'
                    '· 그전에 이루어졌다면 언제든 "소원이 이루어졌어요"를 누를 수 있어요.',
                    style: WrF.body(
                      11.5,
                      color: const Color(0xD9FFF0DC),
                      height: 1.6,
                    ),
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

/// app2/capsule2.jsx SealDatePicker — 네이티브 날짜 선택 + 100일/1년/2년/3년 빠른 선택.
/// [S1 재구축] 작성 화면에서는 더 이상 쓰지 않는다 — capsule_screen.dart가
/// REWISH(타임캡슐) 플로우에서 import해서 쓰고 있으므로 그대로 둔다.
class WrSealDatePicker extends StatelessWidget {
  const WrSealDatePicker({
    super.key,
    required this.value,
    required this.onChange,
  });
  final DateTime? value;
  final ValueChanged<DateTime> onChange;

  DateTime get _today => DateTime.now();
  DateTime get _min => DateTime(
    _today.year,
    _today.month,
    _today.day,
  ).add(const Duration(days: 1));
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
    onChange(
      years > 0
          ? DateTime(base.year + years, base.month, base.day)
          : base.add(Duration(days: days)),
    );
  }

  int get _left => value == null
      ? 0
      : value!
            .difference(DateTime(_today.year, _today.month, _today.day))
            .inDays;

  String _fmtK(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                ? WrDeco.card.copyWith(
                    border: Border.all(color: const Color(0x99FFDC96)),
                    color: const Color(0x14FFDC96),
                  )
                : WrDeco.card,
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value != null ? _fmtK(value!) : '봉인 날짜 선택',
                    style: WrF.body(
                      15,
                      w: FontWeight.w700,
                      color: value != null ? WrC.fg : WrC.muted,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    value != null ? '바꾸기' : '날짜 직접 선택',
                    style: WrF.mono(size: 10, color: WrC.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _presetChip('100일', () => _preset(100, 0)),
            const SizedBox(width: 6),
            _presetChip('1년', () => _preset(0, 1)),
            const SizedBox(width: 6),
            _presetChip('2년', () => _preset(0, 2)),
            const SizedBox(width: 6),
            _presetChip('3년', () => _preset(0, 3)),
          ],
        ),
        if (value != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x59FFDC96)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1FFFDC96), Color(0x14FF96BE)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: WrF.body(13.5, height: 1.55),
                      children: [
                        const TextSpan(text: '✨ '),
                        TextSpan(
                          text: _fmtK(value!),
                          style: WrF.body(
                            13.5,
                            w: FontWeight.w700,
                            color: const Color(0xFFFFE08A),
                          ),
                        ),
                        const TextSpan(text: '까지\n소원을 봉인합니다.'),
                      ],
                    ),
                  ),
                ),
                Text(
                  'D-$_left',
                  style: WrF.display(24, color: const Color(0xFFFFE08A)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: WrDeco.chip,
        child: Text(
          label,
          style: WrF.body(12, w: FontWeight.w700, color: WrC.muted),
        ),
      ),
    ),
  );
}

/// app2/capsule2.jsx SealConfirm — dim 오버레이 + "이 소원을 봉인할까요?" 확인창.
/// [S1 재구축] 작성 화면에서는 더 이상 쓰지 않는다 — capsule_screen.dart가
/// REWISH(타임캡슐) 플로우에서 import해서 쓰고 있으므로 그대로 둔다.
class WrSealConfirm extends StatelessWidget {
  const WrSealConfirm({
    super.key,
    required this.date,
    required this.onCancel,
    required this.onOk,
    required this.busy,
  });
  final DateTime date;
  final VoidCallback onCancel, onOk;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // app2/capsule2.jsx › SealConfirm `API.dayDiff(API.kstDate(), date)` 1:1 —
    // [버그수정 — 전수감사] 기존엔 DateTime.now()(시:분 포함)로 차를 구하고 +1까지
    // 더해 SealDatePicker가 보여주는 D-값과 어긋났다(하루 밀림). 자정 기준 절삭 + +1 제거.
    final today = DateTime.now();
    final left = date
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return Stack(
      children: [
        GestureDetector(
          onTap: onCancel,
          child: Container(color: const Color(0x80080308)),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .9,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x4DFFC8AA)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3A1630), Color(0xFF1E0A16)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 50,
                  offset: Offset(0, 20),
                ),
                BoxShadow(color: Color(0x26FFBE8C), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔐', style: TextStyle(fontSize: 34)),
                        const SizedBox(height: 10),
                        Text(
                          '이 소원을 봉인할까요?',
                          style: WrF.display(19),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '봉인 날짜가 되면\n다시 소원을 확인할 수 있습니다.',
                          textAlign: TextAlign.center,
                          style: WrF.body(13, color: WrC.muted, height: 1.65),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${date.year}년 ${date.month}월 ${date.day}일 · D-$left',
                          style: WrF.body(
                            12.5,
                            w: FontWeight.w700,
                            color: const Color(0xFFFFE08A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '봉인 날짜는 나중에 바꿀 수 없어요',
                          style: WrF.body(11, color: WrC.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onCancel,
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: WrDeco.btnDark,
                          child: Text(
                            '취소',
                            style: WrF.body(15, w: FontWeight.w700),
                          ),
                        ),
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
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    '봉인하기',
                                    style: WrF.body(
                                      15,
                                      w: FontWeight.w700,
                                      color: Colors.white,
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
          ),
        ),
      ],
    );
  }
}
