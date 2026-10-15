// lib/features/guinji/presentation/guinji_invitation_letter.dart
// [귀인지도 초대장 리디자인 — design_handoff_guiin_invitation.zip]
// [B] InvitationLetter — 한지 두루마리 카드. hero 하단에 -70px 겹쳐
// 놓인다(배치는 호출부인 `guinji_map_guest_join_screen.dart`가 담당).
//
// [데이터 제약 — 백엔드 계약 확인 완료] 핸드오프 README는 사전 조회
// `GET /guiin/invites/{inviteId}`(inviteNo/createdAt/message/inviter.region/
// inviter.ageGroup)를 가정하지만, 실제 백엔드의 대응 엔드포인트
// `GET /api/public/guinji/g/{token}`는 인증이 필요해(`requireUser`) 비로그인
// 게스트가 제출 *전에* 호출할 수 없다(401). 서버에도 초대 순번(inviteNo)·
// 지역(region)·연령대(ageGroup) 필드 자체가 존재하지 않는다(`GuinjiMap`/
// `User` 스키마 확인 완료). 따라서 이 위젯은:
//   - 메타 태그 행: 서버 데이터 대신 "INVITATION" + 지도 생성일 기반
//     연-월-일-한자요일만 표시(순번 없이)
//   - 친구 메시지: 서버 메시지가 없으므로 README가 명시한 기본값 그대로 사용
//   - FROM 서명: 지역/연령대 데이터가 없어 "익명의 친구"로 대체(이름 노출
//     금지 원칙은 그대로 유지)
// 이는 디자인-백엔드 불일치를 "제출 전 데이터 없음 → 일반화된 문구" 원칙
// (이 화면의 기존 주석 "[초대자 이름 표시 제약]"과 동일한 패턴)으로 해소한
// 것이다. 추후 서버에 해당 필드가 추가되면 이 위젯에 파라미터로 주입하면
// 된다(이미 옵셔널 파라미터로 설계해 둠).
import 'package:flutter/material.dart';

import 'guinji_invitation_theme.dart';

class GuinjiInvitationLetter extends StatefulWidget {
  const GuinjiInvitationLetter({
    super.key,
    this.message,
    this.inviterRegion,
    this.inviterAgeGroup,
  });

  /// 서버에서 받은 초대 메시지. null이면 기본값 사용.
  final String? message;

  /// 초대자 지역(익명 표시용). null이면 서명 줄에서 지역 생략.
  final String? inviterRegion;

  /// 초대자 연령대(익명 표시용). null이면 서명 줄에서 연령대 생략.
  final String? inviterAgeGroup;

  static const String defaultMessage =
      '밤하늘 어딘가에서 우리 인연이 어떻게 이어져 있는지, 함께 보고 싶었어요';

  @override
  State<GuinjiInvitationLetter> createState() =>
      _GuinjiInvitationLetterState();
}

class _GuinjiInvitationLetterState extends State<GuinjiInvitationLetter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sealCtrl;

  @override
  void initState() {
    super.initState();
    // 진입 0.4초 후 1.4초간 등장(도장 찍히는 느낌).
    _sealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _sealCtrl.forward();
    });
  }

  @override
  void dispose() {
    _sealCtrl.dispose();
    super.dispose();
  }

  String _hanjaWeekday(DateTime d) {
    // 日月火水木金土 — Dart weekday: 1=Mon..7=Sun
    const map = ['月', '火', '水', '木', '金', '土', '日'];
    return map[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateTag =
        '${now.year} · ${now.month.toString().padLeft(2, '0')} · '
        '${now.day.toString().padLeft(2, '0')} · ${_hanjaWeekday(now)}';

    final hasSig = widget.inviterRegion != null || widget.inviterAgeGroup != null;
    final sigParts = [
      if (widget.inviterRegion != null) widget.inviterRegion!,
      if (widget.inviterAgeGroup != null) widget.inviterAgeGroup!,
    ];
    final sigText = hasSig ? 'FROM · ${sigParts.join(' · ')}' : 'FROM · 익명의 친구';

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 나무 봉 상단
          Positioned(
            top: -4,
            left: -6,
            right: -6,
            child: _WoodenRod(),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GiRadius.letter),
              gradient: const RadialGradient(
                center: Alignment(0, -1),
                radius: 1.6,
                colors: [Color(0xFFFFFAF0), Color(0xFFF3E7CC), Color(0xFFEAD9B4)],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: GiColors.glowShadow,
                  blurRadius: 60,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: CustomPaint(
              painter: const _PaperGrainPainter(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1) 메타 태그 행 — 한 줄 고정(nowrap)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'INVITATION',
                        style: TextStyle(
                          fontFamily: GiFonts.mono,
                          fontSize: 9,
                          letterSpacing: 9 * 0.2,
                          color: GiColors.hanjiMeta,
                        ),
                      ),
                      Text(
                        dateTag,
                        style: const TextStyle(
                          fontFamily: GiFonts.mono,
                          fontSize: 9,
                          letterSpacing: 9 * 0.2,
                          color: GiColors.hanjiMeta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 2) 인장 + 제목
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 1.6, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _sealCtrl,
                            curve: const Cubic(0.2, 0.7, 0.2, 1.0),
                          ),
                        ),
                        child: FadeTransition(
                          opacity: _sealCtrl,
                          child: const _SealBadge(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontFamily: GiFonts.display,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                height: 1.38,
                                letterSpacing: -0.4,
                                color: GiColors.hanjiInk,
                              ),
                              children: [
                                TextSpan(text: '친구가 당신을\n'),
                                TextSpan(
                                  text: '귀인지도',
                                  style: TextStyle(color: GiColors.hanjiAccent),
                                ),
                                TextSpan(text: '에 초대했어요'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 3) 친구 메시지
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Color(0x383C2D1E),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      '\u201C${widget.message ?? GuinjiInvitationLetter.defaultMessage}\u201D',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: GiFonts.body,
                        fontSize: 13,
                        height: 1.6,
                        color: GiColors.hanjiMuted,
                      ),
                    ),
                  ),
                  // 4) 보낸 사람 — 익명 원칙(이름 노출 금지)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      sigText,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: GiFonts.mono,
                        fontSize: 9.5,
                        letterSpacing: 9.5 * 0.25,
                        color: GiColors.hanjiMeta,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 나무 봉 하단
          Positioned(
            bottom: -4,
            left: -6,
            right: -6,
            child: _WoodenRod(),
          ),
        ],
      ),
    );
  }
}

class _SealBadge extends StatelessWidget {
  const _SealBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -6 * 3.14159265 / 180,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: GiColors.accent,
          borderRadius: BorderRadius.circular(GiRadius.seal),
          border: Border.all(
            color: const Color(0x59FFE6D2),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x668B3A2B),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          '緣',
          style: TextStyle(
            fontFamily: GiFonts.display,
            fontWeight: FontWeight.w900,
            fontSize: 30,
            color: Color(0xFFFBE9D8),
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _WoodenRod extends StatelessWidget {
  const _WoodenRod();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B4423), Color(0xFF3D2412)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// 가로 결(grain) 텍스처 — `repeating-linear-gradient` 근사.
class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x098B5A2B)
      ..strokeWidth = 1;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += 3;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) => false;
}
