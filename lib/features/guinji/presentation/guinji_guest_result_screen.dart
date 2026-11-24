import 'package:flutter/material.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/widgets/result_text_scale_overlay.dart';
import '../../../core/widgets/zoomable_content.dart';
import '../../share/application/share_service.dart';
import '../../share/domain/share_result_model.dart';
import '../deep/guinji_deep_text.dart';
import '../deep/guinji_reasons.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart' show gradeOf;
import '../widgets/guinji_animated_graph.dart';
import '../widgets/guinji_map_widgets.dart';
import 'guinji_host_welcome_screen.dart';

/// Y · Guest Result — 바이럴 링크로 들어온 게스트가 자신의 사주를 입력한 뒤,
/// 호스트와의 관계 판정 결과를 확인하는 화면.
///
/// [2026-09 새 디자인 리스킨] 새 디자인 zip에는 이 화면과 1:1 대응하는
/// 화면이 없다(`create_intro_screen.dart`는 "만들기 인트로"로 목적이 다름).
/// 따라서 새 디자인의 아이보리+로즈골드 팔레트·타이포그래피·공용 위젯
/// (`GmTopBar`/`GmChip`/`GmLabelMini`/`GmRoseButton`)만 재사용해 이 화면
/// 고유의 레이아웃(방통선녀 bobbing 캐릭터 + 결과 카드 + CTA)을 재도색했다.
/// [주의] 새 디자인의 `ResultAppHandoff`는 위젯 주석에 "결과 화면(M/N)에서만
/// 사용, 다른 화면엔 절대 넣지 말 것"이라 명시되어 있어 이 화면에는 사용하지
/// 않는다.
///
/// [절대 원칙 — 바이럴 게스트 플로우] 이 화면은:
///  (a) 회원가입 없이 도달 가능해야 하고,
///  (b) 결과를 완전히 확인할 수 있는 완결된 경험이어야 하며(추가 결제/
///      가입 장벽 없음),
///  (c) 하단의 "내 지도 만들기" CTA는 게스트가 **스스로 원할 때만** 누르는
///      선택적 전환 유도일 뿐, 이 화면에 도달하거나 머무는 동안 자동으로
///      회원가입/앱으로 리다이렉트되는 로직은 **절대 포함하지 않는다**.
///      (`Timer`/`Future.delayed` 등으로 자동 전환하는 코드를 추가하지
///      말 것 — 사용자가 과거에 이 문제로 강하게 항의한 바 있음. 리스킨
///      이후에도 이 원칙은 그대로 유지된다.)
class GuinjiGuestResultScreen extends StatelessWidget {
  const GuinjiGuestResultScreen({
    super.key,
    required this.hostName,
    this.hostGender,
    required this.relationKey,
    required this.score,
    this.evidenceSummary = '오행 보충도 +0.82 · 희신 일치 · 합 2',
    this.narratorText,
    this.onCreateOwnMap,
    this.guestName,
    this.mapTotal,
  });

  static const routeName = '/guinji-map/guest/result';

  /// 지도 소유자(호스트) 이름.
  final String hostName;

  /// [초대장 리디자인 — 초대한사람 캐릭터 부여] 지도 소유자(호스트)의
  /// 성별('male'/'female'). `joinAnonymous` 응답의 `ownerGender` 필드를
  /// 그대로 전달받는다(백엔드 `User.gender`가 선택 입력이라 비어있으면
  /// null — 이 경우 [_BobbingHostMascot]이 중립 기본값(선녀)으로
  /// 표시한다). `GET /guinji/g/{token}`은 인증이 필요해 제출 전에는 이
  /// 값을 알 수 없으므로, 호스트 캐릭터는 이 화면(제출 *이후*)에서만
  /// 노출한다 — [GuinjiMapGuestJoinScreen]에는 넣지 않는다.
  final String? hostGender;
  final String relationKey;
  final int score;
  final String evidenceSummary;

  /// 결과 본문 서술(방통선녀 나레이션). null이면 [relationKey] 메타의
  /// long 설명을 사용해 기본 문구를 생성한다.
  final String? narratorText;

  /// "내 지도 만들기" CTA — 게스트가 스스로 눌렀을 때만 호출된다(자동
  /// 트리거 금지).
  final VoidCallback? onCreateOwnMap;

  /// [바이럴 페이지 개편] 게스트가 참여 화면에서 직접 입력한 이름(닉네임).
  /// null이면 애니메이션 지도 중앙 라벨을 "나"로 대체한다.
  final String? guestName;

  /// [바이럴 페이지 개편] `joinAnonymous` 응답의 `mapSummary.total`(호스트
  /// 지도에 참여 중인 전체 인원 수) — "지금 N명이 함께해요" 안내에 사용.
  /// null이면 안내 문구 자체를 숨긴다.
  final int? mapTotal;

  /// [귀인지도 v5 — G2/W2 QA 대조 보강] COPY.md G2 "footer(앱) = 나도 내
  /// 귀인지도 만들기 / 결과 공유하기"의 두 번째 버튼. `guinji_map_relation_
  /// detail_screen.dart`의 `_handleShare()`와 동일하게 `ShareService.
  /// shareResult(resultType: relationship)`를 호출해 호스트-게스트 관계
  /// 유형/점수/근거를 공유 링크로 전달한다 — 게스트 본인 생년월일 등
  /// 민감정보는 payload에 포함하지 않는다(이미 화면에 보이는 이름·유형·
  /// 점수·근거 요약만 포함).
  Future<void> _handleShare(BuildContext context) async {
    final meta = guinjiRelationMetaOf(relationKey);
    final message = '$hostName님과의 관계는 "${meta.label}"예요 · 귀인지도';
    try {
      await ShareService.shareResult(
        context,
        resultType: ShareResultType.relationship,
        title: message,
        description: '${meta.label} · 귀인지도',
        payload: {
          'kind': 'relationship',
          'relationType': meta.key,
          'relationLabel': meta.label,
          'summary': meta.long,
          'highlights': [meta.specialInsight, ...meta.tips],
          'personName': hostName,
          'score': score,
          'note': evidenceSummary,
        },
        subject: '귀인지도',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결과 공유에 실패했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationMetaOf(relationKey);
    final color = meta.color;
    final label = meta.label;
    final hanja = meta.hanja;
    final body = narratorText ?? meta.long;

    // [바이럴 페이지 개편 — "메인귀인지도 기능들이 다 나옴"] 게스트 본인을
    // 중심(center)에 두고, 초대한 호스트를 관계 노드 1개로 표시하는 미니
    // 애니메이션 지도. M(My Map)화면과 동일한 [GuinjiAnimatedRelationGraph]
    // 위젯을 그대로 재사용해 회원가입한 사용자가 보는 지도와 동일한 시각
    // 언어(회전 궤도 링·레이더 펄스·호흡하는 노드·에너지 흐름)를 로그인
    // 없이도 그 자리에서 체험할 수 있게 한다.
    final hostNode = GuinjiPerson(
      id: 'host',
      name: hostName,
      birth: '',
      ohaeng: 'to',
      relation: relationKey,
      score: score,
      note: evidenceSummary,
    );
    final centerName = (guestName == null || guestName!.isEmpty)
        ? '나'
        : guestName!;

    return ResultTextScaleOverlay(
      child: Scaffold(
        backgroundColor: GmColors.bg,
        // [2026-12 보강 — COPY.md G2 "bar.title (앱) = 관계 결과" 대조]
        // 기존 "게스트 결과"는 COPY.md와 다른 문구였다.
        appBar: GmTopBar(
          back: true,
          title: '관계 결과',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        // [2026-12 보강 — G2/W2 하단탭바 누락 수정] QA_CHECKLIST.md §1
        // 전역 규칙 "앱 화면 전부 하단 탭바 노출, '홈' 활성"은 예외 없이
        // 모든 화면에 적용되고, SPEC.md §6 G2 구성 목록(1~8)에도 하단탭바를
        // 제외하라는 명시적 지시가 없다. 이 화면은 named route 체계 밖에서
        // `MaterialPageRoute`로 직접 push되어 `wrapWithGlobalBottomNav()`
        // 셸의 적용을 받지 못했던 것이 원인이었다 — G1(`guinji_map_guest_
        // join_screen.dart`)이 이미 동일한 이유로 `MainBottomNavBar`를
        // 직접 갖고 있는 것과 같은 패턴으로 여기에도 추가한다. "자동 전환
        // 금지"(결과 화면 체류 자체) 절대 원칙과는 무관 — 하단탭바는 사용자가
        // 직접 누를 때만 탭을 전환한다.
        bottomNavigationBar: const MainBottomNavBar(currentIndex: 0),
        // [2026-12 보강 — SPEC §2 `bgGlow` 전역 배경] `design_files/
        // guinji-guest.jsx`의 `GsResult`(105줄~)는 공유 셸 `GsShell`
        // (18줄 `<TpBg />`)로 래핑돼 G2/W2 모두 이 배경을 공유한다.
        // `GmColors.bg` 단색만 쓰던 기존 구현을 [GmTempleBg]로 교체한다.
        body: GmTempleBg(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: _BobbingHostMascot(gender: hostGender),
                ),
                const SizedBox(height: 4),
                GmLabelMini(
                  hostGender == 'male' ? '▸ 방통도령 · RESULT' : '▸ 방통선녀 · RESULT',
                ),
                const SizedBox(height: 10),
                // [렌더 버그 방지] 줄바꿈이 들어가는 첫 줄과 색상이 다른
                // TextSpan을 한 Text.rich 트리에 섞으면 Flutter Web(CanvasKit)
                // 에서 첫 줄 글리프가 깨지는 문제가 있어, 줄바꿈이 들어가는
                // 첫 줄을 별도 Text로 분리한다.
                Text(
                  '당신은 $hostName에게',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GmText.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: GmColors.fg,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '이에요'),
                    ],
                    style: const TextStyle(
                      fontFamily: GmText.display,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: GmColors.fg,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _GuestResultCard(
                  label: label,
                  hanja: hanja,
                  score: score,
                  color: color,
                  evidenceSummary: evidenceSummary,
                  body: body,
                ),
                // [귀인지도 v5 — G2/W2 QA 대조 보강] SPEC §6 G2-5 "근거 박스" ·
                // COPY.md G2 "reasons = 왜 이렇게 나왔나요 → §1-2". H5(인물
                // 시트, `guinji_node_sheet.dart`)가 이미 같은 `guinjiReasons`
                // 데이터로 구현해 둔 S1~S5 행 패턴을 그대로 이식한다.
                if ((guinjiReasons[relationKey] ?? const []).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _GuinjiReasonBox(relationKey: relationKey, color: color),
                ],
                const SizedBox(height: 24),
                const Divider(color: GmColors.line, height: 1),
                const SizedBox(height: 16),
                Text(
                  mapTotal != null
                      ? '$hostName님의 지도에 지금 $mapTotal명이 함께해요'
                      : '당신의 지도에는 누가 있을까요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GmText.ui,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: GmColors.fg,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '노드를 눌러 관계 상세를 확인하세요',
                  style: TextStyle(fontSize: 10.5, color: GmColors.dim),
                ),
                const SizedBox(height: 12),
                // [바이럴 페이지 개편] 회원가입한 사용자의 "내 귀인지도"(M화면)와
                // 동일한 애니메이션 관계 그래프. 게스트 본인이 중심, 호스트가
                // 관계 노드 1개로 표시된다.
                GuinjiAnimatedRelationGraph(
                  centerTitle: '$centerName님',
                  centerSubtitle: '나',
                  people: [hostNode],
                  interactive: true,
                  showControls: false,
                  height: 260,
                ),
                // [귀인지도 핸드오프 v4 — L5, 2026-12 광고형 재설계]
                // `guinji-loop.jsx`의 `LpTeaser` 레이아웃(1장 맛보기 +
                // 2~10장 제목+자물쇠)은 그대로 가져오되, 문구는 '결제하면
                // 열린다'는 해금 뉘앙스에서 '내 지도를 만들면 이런 깊은
                // 풀이를 가질 수 있다'는 광고/유도 뉘앙스로 바꿨다 —
                // [대표 확인 완료, 2026-12] 이 화면이 보여주는 것은
                // 호스트-게스트 두 사람의 관계 그 자체이고, 그 관계의
                // 10장 심층 풀이를 결제해서 볼 권한은 지도 소유자인
                // 호스트에게만 있다(게스트 본인은 이 관계를 결제할 권한이
                // 아예 없음 — `guinji_map_relation_detail_screen.dart`의
                // `_handleUnlock`은 호스트 전용). 따라서 이 위젯은 '잠금
                // 해제' 기능이 아니라 순수 홍보/미리보기이며, CTA는
                // 항상 [onCreateOwnMap](자기 지도 만들기, 이 관계와는
                // 무관한 완전히 새로운 여정)만 호출한다 — 절대 원칙(자동
                // 전환 금지)과 동일하게 게스트가 버튼을 직접 눌렀을 때만
                // 동작한다.
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _GuinjiDeepTeaser(
                    hostName: hostName,
                    meName: centerName,
                    relationKey: relationKey,
                    // [귀인지도 v5 — G3 연결] SPEC §6 G2 "동작: 나도 내 귀인지도
                    // 만들기 → G3". 기본값은 더 이상 H1(`/guinji-map`)로
                    // 바로 가지 않고, 먼저 G3(새 호스트 환영,
                    // [GuinjiHostWelcomeScreen])를 보여준다 — 이 화면은
                    // 순수 표시 위젯(상태를 저장하지 않음)이므로 "게스트가
                    // 자기 지도 만들기를 누른 시점"마다 매번 보여줘도
                    // 자동 전환 금지 원칙에 위배되지 않는다(사용자가 직접
                    // 누른 버튼의 즉시 결과일 뿐). G3 내부에서 다시
                    // "내 귀인지도 만들기"→H2(`/guinji-map/new`),
                    // "나중에 할게요"→H1(`/guinji-map`)로 분기한다.
                    onCreateOwnMap:
                        onCreateOwnMap ??
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GuinjiHostWelcomeScreen(
                              guestName: centerName,
                              hostName: hostName,
                              onCreateMap: () => Navigator.of(
                                context,
                              ).pushNamed('/guinji-map/new'),
                              onLater: () =>
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/guinji-map',
                                    (route) => false,
                                  ),
                            ),
                          ),
                        ),
                  ),
                ),
                // [귀인지도 v5 — G2/W2 QA 대조 보강, G1과 동일 원칙] SPEC §6
                // G2-7 "점선 안내 박스" · COPY.md G2 note. 원문 note(앱)은
                // "+20P가 쌓였어요"이지만, 백엔드(`join/route.ts` 설계 결정
                // 1)는 익명 참여에 포인트를 절대 지급하지 않는다 — G1에서
                // 사용자가 결정한 원칙(B: 사실과 일치하는 COPY.md 웹 버전
                // 문구로 플랫폼 구분 없이 통일)을 그대로 적용해, 여기서도
                // "참여가 완료돼…" 문구 하나로 통일한다.
                const SizedBox(height: 16),
                _GiGuestDashedNotice(hostName: hostName),
                const SizedBox(height: 24),
                // [귀인지도 v5 — G2/W2 QA 대조 보강] SPEC §6 G2-8 "footer(앱:
                // Primary + Ghost / 웹: 문구 다름)" · COPY.md G2 footer(앱) =
                // "나도 내 귀인지도 만들기 / 결과 공유하기". Primary(위
                // `_GuinjiDeepTeaser` CTA)는 이미 있으나 Ghost "결과 공유하기"
                // 버튼이 화면에 전혀 없었다 — `guinji_map_relation_detail_
                // screen.dart`의 `_handleShare()`와 동일한 `ShareService.
                // shareResult` 경로로 추가한다.
                OutlinedButton.icon(
                  onPressed: () => _handleShare(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GmColors.line),
                    foregroundColor: GmColors.fg,
                    minimumSize: const Size.fromHeight(46),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text(
                    '결과 공유하기',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SPEC §6 G2-5 "근거 박스" — H5(`guinji_node_sheet.dart`)의 "왜 이렇게
/// 나왔나요" S1~S5 행 패턴을 그대로 이식한다(`guinjiReasons` 공용 데이터).
class _GuinjiReasonBox extends StatelessWidget {
  const _GuinjiReasonBox({required this.relationKey, required this.color});

  final String relationKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reasons = guinjiReasons[relationKey] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GmLabelMini('왜 이렇게 나왔나요'),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GmColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < reasons.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: i > 0
                        ? const Border(top: BorderSide(color: GmColors.hair))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: color.withValues(alpha: 0.53),
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          reasons[i][0],
                          style: TextStyle(
                            fontFamily: GmText.mono,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reasons[i][1],
                          style: const TextStyle(
                            fontFamily: GmText.ui,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            height: 1.5,
                            color: GmColors.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// SPEC §6 G2-7 "점선 안내 박스" — `guinji_map_guest_join_screen.dart`의
/// `_GiDashedPointNotice`/`_GiDashedRectPainter`와 동일한 CustomPaint 점선
/// 테두리 패턴(패키지 의존 없음)을 이 화면의 `GmColors` 팔레트로 재구현한다.
/// [G1과 동일 원칙] "+20P" 대신 사실과 일치하는 COPY.md 웹 버전 문구로
/// 플랫폼 구분 없이 통일한다.
class _GiGuestDashedNotice extends StatelessWidget {
  const _GiGuestDashedNotice({required this.hostName});

  final String hostName;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _GmDashedRectPainter(color: GmColors.gold, radius: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          '참여가 완료돼 $hostName님의 지도에 당신의 별이 떴어요. 내 지도를 만들면 내 곁의 귀인도 볼 수 있어요.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: GmText.ui,
            fontSize: 12.5,
            height: 1.6,
            color: GmColors.muted,
          ),
        ),
      ),
    );
  }
}

class _GmDashedRectPainter extends CustomPainter {
  const _GmDashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        const dashLen = 5.0, gapLen = 3.5;
        final next = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GmDashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// [귀인지도 핸드오프 v4 — L5, 2026-12 광고형 재설계] `LpTeaser` 레이아웃을
/// 1:1로 가져오되(1장 맛보기 + 2~10장 제목 목록), 문구를 '결제 해금'이
/// 아니라 '내 지도를 만들면 이런 깊이의 풀이를 가질 수 있다'는 광고로
/// 바꿨다. [대표 확인 — 2026-12] 게스트는 이 관계(호스트-게스트)의 10장
/// 풀이를 결제할 권한 자체가 없다(그건 지도 소유자인 호스트의 몫).
/// 따라서 이 위젯은 '잠금 해제' 기능이 아니라 순수 홍보/유도용
/// 미리보기이며, 버튼은 항상 [onCreateOwnMap](자기 지도 만들기, 완전히
/// 새로운 여정)만 호출한다.
class _GuinjiDeepTeaser extends StatelessWidget {
  const _GuinjiDeepTeaser({
    required this.hostName,
    required this.meName,
    required this.relationKey,
    required this.onCreateOwnMap,
  });

  final String hostName;
  final String meName;
  final String relationKey;

  /// "나도 내 지도 만들기" — 게스트가 직접 탭했을 때만 호출된다(자동
  /// 트리거 금지, 절대 원칙).
  final VoidCallback onCreateOwnMap;

  static const _chapters = [
    '한눈에 보는 두 사람',
    '관계를 이루는 다섯 가지 힘',
    '처음 만났을 때의 느낌',
    '서로에게 흐르는 기운',
    '마음 깊은 곳의 결',
    '서로에게 어떤 사람인가',
    '함께하면 좋은 일',
    '조심하면 좋은 것',
    '계절마다 달라지는 흐름',
    '관계를 이어가는 방법',
  ];

  @override
  Widget build(BuildContext context) {
    final deep = guinjiDeepText[relationKey] ?? guinjiDeepText['BI_HWA']!;
    // [G-5 맛보기 문단] summary[0] 앞부분 — {n}=호스트, {me}=게스트(나).
    final firstParagraph = fill(deep.summary.first, n: hostName, me: meName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // [2026-12 보강 — COPY.md G2 "preview.meta" 대조] 원문 "10장 풀이
        // 미리보기"로 교정.
        const GmLabelMini('10장 풀이 미리보기'),
        const SizedBox(height: 10),
        // 1장 맛보기 카드.
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: GmColors.card,
                  border: Border.all(color: GmColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '01 · 한눈에 보는 두 사람',
                      style: TextStyle(
                        fontFamily: GmText.display,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: GmColors.gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 82,
                      child: ClipRect(
                        child: Text(
                          firstParagraph,
                          style: const TextStyle(
                            fontFamily: GmText.body,
                            fontSize: 14,
                            height: 1.7,
                            color: GmColors.fg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 하단 그라데이션 페이드.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 56,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          GmColors.card.withValues(alpha: 0),
                          GmColors.card,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // [2026-12 광고형 재설계] 2~10장 — 제목 + 금색 자물쇠. 이
        // 자물쇠는 "결제하면 열린다"가 아니라 "귀인지도를 만들면 이런
        // 깊이의 풀이 10장을 가질 수 있다"는 견본(샘플) 표시다 — 실제로
        // 게스트가 이 10장을 결제해서 여는 경로는 없다(위 클래스 주석
        // 참고).
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: GmColors.hair),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 1; i < _chapters.length; i++)
                Container(
                  decoration: BoxDecoration(
                    border: i > 1
                        ? const Border(top: BorderSide(color: GmColors.hair))
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Opacity(
                    opacity: 0.75,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            (i + 1).toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontFamily: GmText.mono,
                              fontSize: 11,
                              color: GmColors.dim,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _chapters[i],
                            style: const TextStyle(
                              fontFamily: GmText.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: GmColors.muted,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.lock_outline,
                          size: 15,
                          color: GmColors.gold,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // [2026-12 보강 — COPY.md G2 "preview.cta" 대조, 사용자 지시
        // "둘다 고쳐"] 이전 "광고형 재설계"(대표 확인 완료, 2026-12)로
        // "내 지도 만들기 · 무료"로 바뀌었던 CTA를 COPY.md 원문 "나도 내
        // 귀인지도 만들기"로 되돌린다 — 로직(onCreateOwnMap, G3 연결)은
        // 전혀 변경하지 않았다.
        GmRoseButton(
          label: '나도 내 귀인지도 만들기',
          icon: Icons.arrow_forward,
          onPressed: onCreateOwnMap,
        ),
        const SizedBox(height: 8),
        // [2026-12 보강 — COPY.md G2 "preview.pitch" 대조] 원문 "내
        // 지도를 만들면 내 곁의 인연마다 / 이런 깊은 풀이를 가질 수
        // 있어요"로 교정.
        const Text(
          '내 지도를 만들면 내 곁의 인연마다\n이런 깊은 풀이를 가질 수 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: GmColors.dim, height: 1.5),
        ),
      ],
    );
  }
}

/// 호스트(초대한 사람) 캐릭터의 위상 단독 bob 애니메이션(3.6s).
///
/// [2026-10 초대장 리디자인 — 초대한사람 캐릭터 부여] 기존에는
/// `seonnyeo/celebrating.png`(여성 캐릭터)가 성별과 무관하게 항상
/// 고정으로 표시되는 결함이 있었다. [gender]가 'male'이면 도령(남성)
/// 캐릭터 세트를, 그 외(female 또는 서버에 성별이 없어 null)는 선녀(여성)
/// 캐릭터 세트를 사용한다 — `doryeong/`은 celebrating 포함 7종이 모두
/// 있지만 `seonnyeo/`는 3종(celebrating 포함)뿐이라, 두 세트 모두 공통으로
/// 가진 `celebrating.png`를 사용해 균형을 맞춘다.
class _BobbingHostMascot extends StatefulWidget {
  const _BobbingHostMascot({this.gender});

  /// 'male' | 'female' | null(미입력 — 선녀로 폴백).
  final String? gender;

  @override
  State<_BobbingHostMascot> createState() => _BobbingHostMascotState();
}

class _BobbingHostMascotState extends State<_BobbingHostMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        double bob({required double from, required double mid}) {
          if (t <= 0.5) return from + (mid - from) * (t / 0.5);
          return mid + (from - mid) * ((t - 0.5) / 0.5);
        }

        final y = bob(from: 0, mid: -4);
        final rot = bob(from: -1.5, mid: 1.0);
        return Transform.translate(
          offset: Offset(0, y),
          child: Transform.rotate(
            angle: rot * (3.14159265 / 180),
            // [결과페이지 확대 기능] 마스코트 이미지를 탭하면 전체화면으로
            // 크게 볼 수 있다.
            child: ZoomableAssetImage(
              assetPath: widget.gender == 'male'
                  ? 'assets/images/guinji/doryeong/celebrating.png'
                  : 'assets/images/guinji/seonnyeo/celebrating.png',
              heroTag: 'guinji_guest_mascot_${widget.gender}',
              child: Image.asset(
                widget.gender == 'male'
                    ? 'assets/images/guinji/doryeong/celebrating.png'
                    : 'assets/images/guinji/seonnyeo/celebrating.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 관계색 그라디언트 배경 + chip + 점수 + 산출근거 요약 + 나레이션 본문.
/// [2026-09 새 디자인 리스킨] 새 디자인 `GmChip`/아이보리 카드 스타일로
/// 재도색했다.
class _GuestResultCard extends StatelessWidget {
  const _GuestResultCard({
    required this.label,
    required this.hanja,
    required this.score,
    required this.color,
    required this.evidenceSummary,
    required this.body,
  });

  final String label;
  final String hanja;
  final int score;
  final Color color;
  final String evidenceSummary;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: GmColors.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.6),
          radius: 1.1,
          colors: [color.withValues(alpha: 0.14), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          GmChip(
            label: '$label · $hanja人',
            background: color.withValues(alpha: 0.12),
            foreground: color,
            borderColor: color.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/ 100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: GmColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // [2026-12 보강 — COPY.md G2 "score = 케미 점수 · {등급}등급 +
          // {유형 설명}" 대조] 기존에는 등급(S/A/B/C/D)이 전혀 표시되지
          // 않았다 — H5(guinji_node_sheet.dart)와 동일한 gradeOf(score)를
          // 재사용해 추가한다.
          Text(
            '케미 점수 · ${gradeOf(score)}등급',
            style: const TextStyle(fontSize: 10.5, color: GmColors.dim),
          ),
          const SizedBox(height: 14),
          Text(
            evidenceSummary,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: GmColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.65,
              color: GmColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}
