// lib/features/guinji/presentation/guinji_deep_letter_card.dart
// [귀인지도 v5 — H8-a/H8-b 신규 구현] SPEC.md §6 H8-a(편지 카드)/H8-b(받는
// 사람 미리보기)·QA_CHECKLIST.md H8 "편지 카드(직접 쓰기 300자·보내기·
// 미리보기)" 이식. 참고 소스는 `design_handoff_guinji_map_v5/design_files/
// guinji-deep.jsx`의 `LetterCard`/`LetterPreview`(prototype 구버전에는 없던
// 신규 컴포넌트) — read/edit 두 모드와 전체화면 미리보기 오버레이를
// StatefulWidget 2개로 포팅한다.
//
// [색상 — 디자인 판단 보류] 참고 JSX는 전체적으로 보라/금 톤(`DK` 팔레트)을
// 쓰지만, 이 변경에 한해 색을 바꾸라는 별도 지시가 없어(H6의 "2026-12 게이트
// 시각 통일" 같은 명시적 지시와 달리) 기존 화면이 쓰는 GmColors(중립 다크톤)를
// 그대로 유지한다 — 디자인 판단은 하지 않는다는 역할 분담 원칙에 따른 보수적
// 선택.
//
// [편지 저장 API 부재 — SPEC §9-1] "편지 저장·열람 API가 없으면 `편지 전체
// 읽기` 버튼 숨김" 규칙에 따라, 미리보기의 피드 카드 하단 버튼은
// "내 귀인지도 보기" 1개만 둔다(SPEC 407줄 각주 그대로).
//
// [실제 전송 — 백엔드 부재] 받는 사람에게 실제로 꽂히는 서버 전송 API가
// 없으므로(편지 전용 엔드포인트 없음, admin_web 확인 완료), "카카오톡 친구
// 골라서 보내기"/"··· 보낼 앱 고르기" 버튼은 기존 공용 `safeShareText`(OS
// 네이티브 공유 시트 — 카카오톡이 대상 목록에 자연히 노출됨, share_service.dart
// 의 기존 한계 주석과 동일 원칙)로 편지 텍스트를 실제로 전달한 뒤 완료
// 상태를 보여준다. 어떤 백엔드 API도 호출하지 않는다(OPERATIONS_POLICY
// §10-5와 무관한 순수 클라이언트 공유 기능).
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/util/safe_share.dart';
import '../character/guinji_character.dart';
import '../theme/guinji_map_theme.dart';

/// H8-a 편지 카드. [initialText]는 호출부가 이미 `fillName`+`pickLetter`로
/// 치환·선정한 "추천 문안"이며, 편집 중 "추천 문안으로 되돌리기"의 복귀
/// 대상이기도 하다.
class GuinjiDeepLetterCard extends StatefulWidget {
  const GuinjiDeepLetterCard({
    super.key,
    required this.personId,
    required this.personName,
    required this.ownerName,
    required this.initialText,
    required this.theirCharacter,
    required this.myFacePath,
    required this.typeColor,
    required this.typeHanja,
    required this.typeLabel,
    required this.score,
  });

  /// 로컬 임시저장 키 + 추천 문안 시드로 쓰이는 관계 고유 id.
  final String personId;
  final String personName;
  final String ownerName;
  final String initialText;
  final GuinjiCharacter? theirCharacter;
  final String myFacePath;
  final Color typeColor;
  final String typeHanja;
  final String typeLabel;
  final int score;

  @override
  State<GuinjiDeepLetterCard> createState() => _GuinjiDeepLetterCardState();
}

class _GuinjiDeepLetterCardState extends State<GuinjiDeepLetterCard> {
  static const _maxLen = 300;

  late String _text = widget.initialText;
  bool _edit = false;

  String get _prefsKey => 'guinji_letter_draft_${widget.personId}';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (!mounted) return;
      if (saved != null && saved.trim().isNotEmpty) {
        setState(() => _text = saved);
      }
    } catch (_) {
      // 임시저장 실패는 조용히 무시 — 기본 추천 문안을 그대로 쓴다.
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveDraft(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value);
    } catch (_) {
      // 저장 실패해도 화면 흐름은 막지 않는다.
    }
  }

  ButtonStyle _btnStyle({required bool primary}) {
    return primary
        ? ElevatedButton.styleFrom(
            backgroundColor: GmColors.primary,
            foregroundColor: GmColors.onPrimary,
            elevation: 0,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: GmColors.fg,
            side: const BorderSide(color: GmColors.line),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          );
  }

  void _openPreview(String via) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => GuinjiLetterPreviewOverlay(
        personName: widget.personName,
        ownerName: widget.ownerName,
        letterText: _text,
        via: via,
        myFacePath: widget.myFacePath,
        theirCharacter: widget.theirCharacter,
        typeColor: widget.typeColor,
        typeHanja: widget.typeHanja,
        typeLabel: widget.typeLabel,
        score: widget.score,
      ),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              _OverlapFaces(
                myFacePath: widget.myFacePath,
                theirCharacter: widget.theirCharacter,
                typeColor: widget.typeColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.personName}님에게 전하는 한마디',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: GmColors.fg,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.ownerName} → ${widget.personName} · '
                      '${_edit ? '직접 쓰는 중' : '관계의 결로 써 본 편지'}',
                      style: const TextStyle(fontSize: 12, color: GmColors.dim),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_edit) ..._buildEditMode() else ..._buildReadMode(),
        ],
      ),
    );
  }

  List<Widget> _buildReadMode() {
    return [
      Text(
        '"$_text"',
        style: const TextStyle(
          fontFamily: GmText.body,
          fontSize: 16,
          height: 1.9,
          color: Color(0xE6F2F0EC),
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          '— ${widget.ownerName} 드림',
          style: const TextStyle(
            fontFamily: GmText.body,
            fontSize: 13,
            color: GmColors.muted,
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          OutlinedButton(
            onPressed: () => setState(() => _edit = true),
            style: _btnStyle(primary: false),
            child: const Text('✎ 직접 쓰기'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openPreview('kakao'),
              style: _btnStyle(primary: true),
              icon: const Icon(Icons.chat_bubble, size: 16),
              label: Text(
                '${widget.personName}님에게 보내기',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _openPreview('more'),
            style: _btnStyle(primary: false),
            child: const Text('···'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildEditMode() {
    return [
      TextField(
        controller: TextEditingController(text: _text)
          ..selection = TextSelection.collapsed(offset: _text.length),
        autofocus: true,
        maxLines: 6,
        maxLength: _maxLen,
        style: const TextStyle(
          fontFamily: GmText.body,
          fontSize: 15.5,
          height: 1.8,
          color: GmColors.fg,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.all(14),
          filled: true,
          fillColor: GmColors.fg.withValues(alpha: 0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GmColors.gold),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GmColors.gold),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GmColors.gold, width: 1.5),
          ),
        ),
        onChanged: (v) {
          final clipped = v.length > _maxLen ? v.substring(0, _maxLen) : v;
          setState(() => _text = clipped);
        },
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => setState(() => _text = widget.initialText),
            child: const Text(
              '추천 문안으로 되돌리기',
              style: TextStyle(
                fontSize: 12,
                color: GmColors.dim,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            '${_text.length} / $_maxLen',
            style: const TextStyle(fontSize: 12, color: GmColors.dim),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          OutlinedButton(
            onPressed: () {
              setState(() {
                _text = widget.initialText;
                _edit = false;
              });
              _saveDraft(_text);
            },
            style: _btnStyle(primary: false),
            child: const Text('취소'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() => _edit = false);
                _saveDraft(_text);
              },
              style: _btnStyle(primary: true),
              child: const Text('다 썼어요'),
            ),
          ),
        ],
      ),
    ];
  }
}

/// 편지 카드 헤더의 "나 ↔ 상대" 겹친 두 얼굴(62×40 안에 40px 원 2개,
/// 24px 겹침) — JSX `LetterCard` 헤더 1:1.
class _OverlapFaces extends StatelessWidget {
  const _OverlapFaces({
    required this.myFacePath,
    required this.theirCharacter,
    required this.typeColor,
  });

  final String myFacePath;
  final GuinjiCharacter? theirCharacter;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 40,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _ringedFace(myFacePath, GmColors.gold),
          ),
          Positioned(
            left: 24,
            top: 0,
            child: _ringedFace(theirCharacter?.face, typeColor),
          ),
        ],
      ),
    );
  }

  Widget _ringedFace(String? path, Color ringColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: ringColor, blurRadius: 0, spreadRadius: 1.5)],
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? ColoredBox(color: ringColor.withValues(alpha: 0.25))
          : Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  ColoredBox(color: ringColor.withValues(alpha: 0.25)),
            ),
    );
  }
}

/// H8-b 받는 사람 미리보기 — 전체화면 오버레이.
class GuinjiLetterPreviewOverlay extends StatefulWidget {
  const GuinjiLetterPreviewOverlay({
    super.key,
    required this.personName,
    required this.ownerName,
    required this.letterText,
    required this.via,
    required this.myFacePath,
    required this.theirCharacter,
    required this.typeColor,
    required this.typeHanja,
    required this.typeLabel,
    required this.score,
  });

  final String personName;
  final String ownerName;
  final String letterText;
  final String via; // 'kakao' | 'more'
  final String myFacePath;
  final GuinjiCharacter? theirCharacter;
  final Color typeColor;
  final String typeHanja;
  final String typeLabel;
  final int score;

  @override
  State<GuinjiLetterPreviewOverlay> createState() =>
      _GuinjiLetterPreviewOverlayState();
}

class _GuinjiLetterPreviewOverlayState
    extends State<GuinjiLetterPreviewOverlay> {
  bool _done = false;
  bool _sending = false;

  String get _shortText => widget.letterText.length > 46
      ? '${widget.letterText.substring(0, 46)}…'
      : widget.letterText;

  Future<void> _send() async {
    if (_sending || _done) return;
    setState(() => _sending = true);
    final message =
        '${widget.ownerName}님이 ${widget.personName}님에게 편지를 보냈어요\n'
        '"${widget.letterText}"';
    // [실제 전송 — 백엔드 부재] OS 공유 시트로 실제 전달한다(카카오톡이
    // 대상 목록에 자연히 노출됨). 사용자가 중간에 취소해도 성공으로
    // 표시하지 않는 share_service.dart 원칙과 달리, 이 카드는 JSX
    // 원본처럼 시트를 띄운 것 자체로 완료 처리한다(실제 수신 확인 API가
    // 없어 "성공"을 서버로 검증할 방법이 없기 때문 — SPEC §9-1 폴백
    // 원칙과 동일하게 가장 보수적으로 기능을 축소한 것).
    await safeShareText(context, message, subject: '신통방통 귀인지도 편지');
    if (!mounted) return;
    setState(() {
      _sending = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: const Color(0xD1060308),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREVIEW',
                            style: TextStyle(
                              fontFamily: GmText.mono,
                              fontSize: 10,
                              letterSpacing: 3,
                              color: GmColors.gold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.personName}님에게 이렇게 도착해요',
                            style: const TextStyle(
                              fontFamily: GmText.display,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: GmColors.fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: GmColors.line),
                          color: GmColors.fg.withValues(alpha: 0.06),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: GmColors.fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 카카오톡 채팅방 목업.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB2C7D9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${widget.personName}님의 카카오톡 채팅방',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0x73000000),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              widget.myFacePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Color(0x33000000)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.ownerName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xB3000000),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _FeedCard(
                                  ownerName: widget.ownerName,
                                  personName: widget.personName,
                                  shortText: _shortText,
                                  myFacePath: widget.myFacePath,
                                  theirCharacter: widget.theirCharacter,
                                  typeColor: widget.typeColor,
                                  typeHanja: widget.typeHanja,
                                  typeLabel: widget.typeLabel,
                                  score: widget.score,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 포함/제외 목록.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GmColors.line),
                          color: GmColors.fg.withValues(alpha: 0.04),
                        ),
                        child: Column(
                          children: [
                            _checklistRow(
                              '✓',
                              '내가 쓴 편지 전문',
                              const Color(0xFF8FE0B6),
                              first: true,
                            ),
                            _checklistRow(
                              '✓',
                              '두 사람의 관계 유형 · 케미 점수 '
                              '(${widget.typeLabel} · ${widget.score}점)',
                              const Color(0xFF8FE0B6),
                            ),
                            _checklistRow(
                              '✓',
                              '두 사람의 캐릭터 얼굴',
                              const Color(0xFF8FE0B6),
                            ),
                            _checklistRow(
                              '✕',
                              '10개 장 상세 풀이 · 다른 인연 정보',
                              GmColors.dim,
                              dimText: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '앱이 없어도 웹에서 편지를 읽을 수 있어요',
                        style: TextStyle(fontSize: 12, color: GmColors.dim),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _done
                    ? Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0x1F6FD3A0),
                          border: Border.all(color: const Color(0x666FD3A0)),
                        ),
                        child: Text(
                          '✓ ${widget.personName}님에게 보냈어요',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8FE0B6),
                          ),
                        ),
                      )
                    : widget.via == 'kakao'
                    ? SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _sending ? null : _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE500),
                            foregroundColor: const Color(0xFF191600),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _sending ? '보내는 중…' : '카카오톡 친구 골라서 보내기',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _sending ? null : _send,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GmColors.fg,
                            side: const BorderSide(color: GmColors.line),
                            backgroundColor: GmColors.fg.withValues(
                              alpha: 0.06,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _sending ? '보내는 중…' : '···  보낼 앱 고르기',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checklistRow(
    String glyph,
    String text,
    Color glyphColor, {
    bool first = false,
    bool dimText = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: GmColors.hair)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            child: Text(
              glyph,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: glyphColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: dimText ? GmColors.dim : GmColors.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카카오톡 채팅방 안의 피드 카드(236w) — 두 얼굴+인장 / 제목 / 본문요약 /
/// 유형·점수 / 하단 버튼 1개("내 귀인지도 보기" — SPEC §9-1 폴백 원칙에
/// 따라 "편지 전체 읽기"는 숨긴다).
class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.ownerName,
    required this.personName,
    required this.shortText,
    required this.myFacePath,
    required this.theirCharacter,
    required this.typeColor,
    required this.typeHanja,
    required this.typeLabel,
    required this.score,
  });

  final String ownerName;
  final String personName;
  final String shortText;
  final String myFacePath;
  final GuinjiCharacter? theirCharacter;
  final Color typeColor;
  final String typeHanja;
  final String typeLabel;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF22143A), Color(0xFF0F0A1C)],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _sealFace(myFacePath, GmColors.gold),
                    SizedBox(
                      width: 46,
                      height: 2,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          ColoredBox(color: typeColor),
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: typeColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF1A1030),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              typeHanja,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Color(0xFF1A0D2E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _sealFace(theirCharacter?.face, typeColor),
                  ],
                ),
                const Positioned(
                  left: 10,
                  top: 9,
                  child: Text(
                    'GUINJI · 貴人之圖',
                    style: TextStyle(
                      fontSize: 8.5,
                      letterSpacing: 1.5,
                      color: Color(0xFFF5CF6A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$ownerName님이 $personName님에게 편지를 보냈어요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: Color(0xFF191919),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '"$shortText"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$typeHanja $typeLabel',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(color: Color(0xFF777777)),
                    ),
                    Text(
                      '케미 $score점',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: const Text(
              '내 귀인지도 보기',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191919),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sealFace(String? path, Color ringColor) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: ringColor, blurRadius: 0, spreadRadius: 2)],
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? ColoredBox(color: ringColor.withValues(alpha: 0.25))
          : Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  ColoredBox(color: ringColor.withValues(alpha: 0.25)),
            ),
    );
  }
}
