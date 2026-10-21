import 'dart:typed_data';


import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';



import '../../../core/util/image_gallery_saver.dart';
import '../../../core/util/original_result_capture.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/widgets/app_toast.dart';
import '../../../core/theme/legacy_wish_room/wish_room_sigil.dart';
import '../../share/application/share_service.dart';
import '../../share/domain/share_result_model.dart';
import '../application/guinji_provider.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';

/// 귀인지도(Guinji Map) — 10. 결과 카드(Result Card) 화면.
///
/// [Phase G-8] `GUINJI_SCREENS.md` "10 · 결과 카드" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `ResultCardScreen`): 카톡·인스타에 공유할 세로
/// 3:4 스크린샷 카드. 랭킹(S7)의 "결과 카드로 공유하기" CTA에서 진입한다.
///
/// [비식별 원칙] 원본 스펙 그대로 카드에는 이름을 노출하지 않고 관계
/// 유형별 인원수(귀인/오른팔/호랑이 선생)만 표시한다. "귀인 N명"은
/// 전체 참여자 수가 아니라 관계유형이 정확히 'guin'(貴)인 인원수만
/// 세는 것이 원본 설계 의도다(GUINJI_SCREENS.md §10, §84 관계유형 5종
/// 표 참고 — 지도 메인 화면 필터 chips·랭킹 화면도 동일 원칙으로 유형별
/// 카운트를 표시한다).
///
/// [귀인지도 실구현] "공유하기" 버튼은 `tarot_result_screen`의 검증된
/// 패턴(RepaintBoundary → PNG → share_plus 네이티브 공유 시트)을 그대로
/// 재사용해 실제로 동작한다. 어떤 재화 지급도 이 화면에서는 발생하지
/// 않는다(캡처·공유는 순수 클라이언트 로컬 동작).
///
/// [타로 공유 안 되는 버그 수정과 동일 건] 과거에는 path_provider로 캡처
/// 이미지를 디스크 임시 파일에 저장한 뒤 그 경로로 XFile을 만들어
/// 공유했는데, path_provider는 Web 플랫폼을 지원하지 않는 패키지라(pub.dev
/// platforms 목록에 web 없음) 웹 프리뷰/웹 배포에서 getTemporaryDirectory()
/// 호출 자체가 예외를 던져 공유가 항상 실패했다. XFile.fromData()(메모리
/// 기반, 모든 플랫폼 지원)로 바꿔 디스크 파일 저장 단계를 완전히 제거한다.
///
/// [2026-11 버그수정 — "이미지 저장/공유가 뭘 하는지 모르겠다"] 두 가지를
/// 함께 고쳤다:
/// 1) 기존에는 "이미지 저장" 버튼도 "공유하기" 버튼도 똑같이
///    `Share.shareXFiles()`만 호출해서, "저장"을 눌러도 OS 공유 시트만
///    뜨고 갤러리에 곧바로 저장되지 않았다. 이제 "이미지 저장"은
///    [saveImageBytesToGallery](Android: gal 패키지로 실제 갤러리 저장,
///    Web: 브라우저 다운로드)를 호출해 실제로 저장하고, "공유하기"만
///    OS 공유 시트를 연다.
/// 2) 공유 텍스트가 "나의 귀인지도 · 신통방통"처럼 지나치게 짧아 받는
///    사람이 무엇을 받았는지 알기 어려웠다. 이제 소유자 이름·귀인 수·
///    앱 안내 문구가 담긴 구체적인 문장 + 앱 링크로 교체한다.
class GuinjiResultCardScreen extends StatefulWidget {
  const GuinjiResultCardScreen({
    super.key,
    this.people = guinjiSamplePeople,
    this.ownerName = '지민',
  });

  final List<GuinjiPerson> people;

  /// [귀인지도 기능 정리 — 3, 이상한 부분] 이전까지 카드 본문의
  /// "지민의 지도에는" 문구가 실제 소유자 이름과 무관하게 항상 "지민"으로
  /// 하드코딩돼 있었다. 호출부(랭킹 화면 등)에서 실제 이름을 전달하면
  /// 그 이름이 표시되고, 값이 없으면(기존 `/guinji/result-card` 라우트
  /// 등 회귀 방지) 기존 기본값 '지민'을 그대로 유지한다.
  final String ownerName;

  @override
  State<GuinjiResultCardScreen> createState() => _GuinjiResultCardScreenState();
}

class _GuinjiResultCardScreenState extends State<GuinjiResultCardScreen> {
  final _cardKey = GlobalKey();
  bool _capturing = false;

  /// [2026-11 버그수정] "이미지 저장"과 "공유하기"가 공통으로 필요로 하는
  /// 카드 캡처 로직만 분리한 헬퍼. 실패 시 null을 반환하며, 준비 중
  /// 안내 토스트는 호출부에서 각자의 문구로 보여준다.
  Future<Uint8List?> _captureCardBytes() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return captureOriginalResult(_cardKey);
  }

  /// [비식별 원칙] 카드에 이름을 노출하지 않는 원칙은 그대로 유지하되,
  /// 공유 문구(카톡 등 텍스트로만 먼저 보이는 부분)에는 받는 사람이
  /// "무엇을 공유받았는지" 한눈에 알 수 있도록 소유자 이름·귀인 수·앱
  /// 안내를 구체적으로 담는다. 기존 '나의 귀인지도 · 신통방통' 한 줄만으로는
  /// "뭘 공유한 건지 모르겠다"는 사용자 불만으로 이어졌었다.


  /// [2026-11 버그수정 — "이미지 저장이 뭘 하는지 모르겠다"] 캡처한 카드를
  /// 곧바로 기기 갤러리(Android: gal / Web: 브라우저 다운로드)에 저장한다.
  /// 이전에는 이 버튼도 공유 시트를 여는 것과 동일하게 동작해, "저장"을
  /// 눌렀는데 왜 공유창이 뜨는지 혼란스럽다는 문제가 있었다.
  Future<void> _saveImage() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final bytes = await _captureCardBytes();
      if (bytes == null) {
        if (!mounted) return;
        AppToast.show(context, '카드를 준비하는 중입니다. 잠시 후 다시 시도해 주세요.');
        return;
      }
      // [REQ-05 — 신통방통_저장기능_정상화_개발지시서_v1.0] 실패 원인을
      // 구분해 안내한다(과거에는 모든 실패가 "권한을 확인해주세요"로
      // 뭉뚱그려져, 저장 공간 부족 사용자가 엉뚱한 설정을 뒤지게 됨).
      final result = await saveImageBytesToGalleryDetailed(
        bytes,
        name: 'guinji_result_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      AppToast.show(
        context,
        result.isSuccess
            ? (kIsWeb ? '카드 파일 다운로드를 요청했어요.' : '카드 이미지를 갤러리에 저장했어요.')
            : (result.failureMessage ?? '저장에 실패했어요. 잠시 후 다시 시도해주세요.'),
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, '이미지 저장에 실패했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  // ignore: unused_element
  Future<void> _captureAndShare(int guin) async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final bytes = await _captureCardBytes();
      if (bytes == null) {
        if (!mounted) return;
        AppToast.show(context, '카드를 준비하는 중입니다. 잠시 후 다시 시도해 주세요.');
        return;
      }

      if (!mounted) return;
      await ShareService.shareImageDirectly(context, '${widget.ownerName}님의 귀인지도', bytes);
    } catch (_) {
      // [근본 수정 — 2026-12] 이미지 첨부 공유(shareXFiles)가 실패했을 때의
      // 텍스트 전용 폴백에서 예전에는 `Share.share()`를 직접 호출했다.
      // `share_plus_web.dart`가 웹에서 canShare() 미지원 시 `mailto:`
      // 스킴을 자체적으로 새 탭에 열려고 시도해 net::ERR_UNKNOWN_URL_SCHEME
      // 에러 화면을 유발하는 것을 확인했다(core/util/safe_share.dart 문서
      // 참고). 공통 헬퍼로 교체해 웹에서는 곧바로 클립보드 복사로 폴백한다.
      if (!mounted) return;
      AppToast.show(context, '결과 이미지를 준비하지 못했어요. 다시 시도해주세요.', isError: true);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// [2027-02 귀인지도 링크 공유 추가] 기존 스크린샷 공유(RepaintBoundary→
  /// PNG→Share.shareXFiles)는 그대로 유지하고, 별도로 서버 공유 시스템
  /// (`/api/public/share` → `/r/{shareId}`)에 연결되는 "링크 공유"를
  /// 추가한다.
  ///
  /// [공개 가능 여부 서버 검증] `POST /api/public/share`는 JWT 인증을
  /// 요구하므로(`requireUser`), 이 메서드를 호출할 수 있는 것은 오직
  /// **로그인한 본인**뿐이다. 이 화면의 [widget.people]은 항상 호출부
  /// (랭킹 화면)가 [GuinjiProvider.people] — 즉 "로그인한 본인 소유"
  /// 귀인지도 데이터만 전달하므로, 타인의 비공개 귀인지도를 이 경로로
  /// 공유할 방법 자체가 없다(서버 JWT 소유자 확인 = 공개 가능 여부 검증).
  /// payload에는 기존 비식별 원칙(이름 비노출, 관계유형별 인원수만)을
  /// 그대로 적용해 집계값만 담는다 — 원본 생년월일/실명 등은 절대 포함하지
  /// 않는다.
  ///
  /// [2026-10-13 V2 6종 전환] 공유 payload의 관계유형 집계를 구 5종
  /// (guin/oreunpal/horang)에서 V2 6종(CHEON_GWII/HAP/SANG_SAENG/
  /// SANG_GEUK/BI_HWA/CHUNG)으로 전환한다. 집계 대상인 [widget.people]의
  /// `relation` 필드는 [GuinjiPerson.fromServerJson]에서 이미 서버 응답
  /// `relation.relationType`을 그대로 옮겨 담은 값이므로(`guinji_person.dart`
  /// 참고), 여기서는 그 값을 유형별로 세기만 할 뿐 클라이언트가 관계를
  /// 재판정하지 않는다.
  ///
  /// [웹 하위호환 — 수정 불필요] admin_web `RelationshipView`는 레거시
  /// `guin/oreunpal/horang` 키가 있으면 카드형 집계로, 없으면 `highlights`
  /// 리스트로 폴백 렌더링하도록 이미 설계돼 있다(`service-result-view.tsx`
  /// §RelationshipView). 이번 전환으로 신규 공유분은 그 키를 보내지 않으므로
  /// 자동으로 `highlights` 폴백 경로를 타며, 기존에 이미 생성된 레거시
  /// 공유 링크는 여전히 `guin/oreunpal/horang` payload 그대로 보존되어
  /// 카드형 렌더가 깨지지 않는다 — 웹 쪽 코드 변경이 필요 없다.
  Future<void> _shareViaLink() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final mapId = context.read<GuinjiProvider>().mapId;
      final people = widget.people;

      // 서버가 내려준 relationType(V2 6종) 값을 유형별로 집계만 한다.
      final relationCounts = <String, int>{
        for (final key in guinjiRelationOrder)
          key: people.where((p) => p.relation == key).length,
      };
      final cheonGwii = relationCounts['CHEON_GWII'] ?? 0;

      await ShareService.shareResult(
        context,
        resultType: ShareResultType.relationship,
        title: '${widget.ownerName}님의 귀인지도 · 신통방통',
        description: '내 주변 귀인 $cheonGwii명을 포함해 신통방통이 관계유형을 찾아줬어요.',
        payload: {
          // [앱·웹 공유 구조 확정] admin_web 전용 렌더러가 관계유형별
          // 인원수를 카드형 집계로 보여줄 수 있도록 구조화 필드를
          // 추가한다(비식별 원칙 유지 — 이름 비노출, 인원수 집계만).
          'kind': 'relationship',
          'ownerName': widget.ownerName,
          'relationCounts': relationCounts,
          'category': '귀인지도',
          'summary': '내 주변 귀인 $cheonGwii명을 포함해 신통방통이 관계유형을 찾아줬어요.',
          'highlights': [
            for (final key in guinjiRelationOrder)
              '${guinjiRelationMetaOf(key).label} ${relationCounts[key]}명',
          ],
        },
        sourceRefId: mapId,
        originalResultKey: _cardKey,
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// "공유하기" 버튼 탭.
  ///
  /// [신통방통 앱·웹 공유 근본 정상화 — 2026-11] 과거에는 웹만
  /// [_shareViaLink]( /r/{id} 서버 공유 링크 생성 )를 쓰고 앱은
  /// [_captureAndShare](이미지만 OS 공유 시트로 전송, 공유 링크 없음)를
  /// 써서 — 앱에서 공유받은 사람은 애초에 특정 결과로 돌아올 링크 자체가
  /// 없었다(§3-A 위반). `ShareService.shareResult()`가 이제 플랫폼 공통으로
  /// 서버 공유 링크를 만들고 앱에서는 이미지+`/r/{id}` 딥링크를 함께
  /// 전송하도록 고쳐졌으므로, 여기서도 플랫폼 분기 없이 항상
  /// [_shareViaLink]만 사용한다. (레거시 [_captureAndShare]는 더 이상
  /// 호출되지 않지만, 과거 코드 경로 회귀 추적을 위해 일단 남겨둔다.)
  Future<void> _showShareOptions(int guin) async {
    if (_capturing) return;
    await _shareViaLink();
  }

  @override
  Widget build(BuildContext context) {
    final people = widget.people;
    // [V2 전환] 폐기된 12종 코드(JORYEOK/JAGEUKJE) 하드코딩 비교를
    // V2 6종(SANG_SAENG/SANG_GEUK)으로 교체. 기존 "조력/자극제" 의미에
    // 가장 가까운 V2 유형으로 매핑했다.
    final guin = people.where((p) => p.relation == 'CHEON_GWII').length;
    final oreunpal = people.where((p) => p.relation == 'SANG_SAENG').length;
    final horang = people.where((p) => p.relation == 'SANG_GEUK').length;

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const _MonoLabel('RESULT · SHARE CARD'),
                      _IconButton(
                        icon: Icons.more_horiz,
                        onPressed: () =>
                            AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: _TheCard(
                          ownerName: widget.ownerName,
                          guin: guin,
                          oreunpal: oreunpal,
                          horang: horang,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _GhostButton(
                          label: _capturing ? '준비하는 중' : '이미지 저장',
                          onPressed: _capturing ? () {} : _saveImage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PrimaryButton(
                          label: _capturing ? '준비하는 중' : '공유하기',
                          onPressed: _capturing
                              ? () {}
                              : () => _showShareOptions(guin),
                        ),
                      ),
                    ],
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

/// 카드 본체 — 240×320(3:4), 회전 마법진 배경 + 통계 + 인용구.
class _TheCard extends StatelessWidget {
  const _TheCard({
    required this.ownerName,
    required this.guin,
    required this.oreunpal,
    required this.horang,
  });

  final String ownerName;
  final int guin;
  final int oreunpal;
  final int horang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 320,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GuinjiColors.lavender.withValues(alpha: 0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 60,
            offset: Offset(0, 20),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(GuinjiColors.backgroundSoft, GuinjiColors.aqua, 0.1)!,
            GuinjiColors.backgroundDeep,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.0),
                  radius: 0.9,
                  colors: [
                    GuinjiColors.lavender.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),
          // 회전 마법진 — WishRoomSigilRing 재사용(opacity 0.5 근사).
          const Positioned(
            top: 78,
            left: 20,
            child: WishRoomSigilRing(
              size: 200,
              color: GuinjiColors.lavender,
              opacity: 0.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _MonoLabel(
                      'SINTONG · GUINJI',
                      color: GuinjiColors.lavender,
                      fontSize: 7,
                    ),
                    _MonoLabel('N°01', fontSize: 7),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$ownerName의 지도에는',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontSize: 10,
                    color: GuinjiColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '귀인 $guin명',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: -0.6,
                    color: GuinjiColors.lavender,
                    shadows: [
                      Shadow(color: GuinjiColors.glowShadow, blurRadius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '오른팔 $oreunpal · 호랑이 선생 $horang',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontSize: 10,
                    color: GuinjiColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: GuinjiColors.surfaceCardBorder),
                      bottom: BorderSide(color: GuinjiColors.surfaceCardBorder),
                    ),
                  ),
                  child: const Text(
                    '"간절히 원하면,\n온 우주가 도와준다"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontStyle: FontStyle.italic,
                      fontSize: 10,
                      height: 1.4,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: _MonoLabel('SINTONG BANGTONG · 신통방통', fontSize: 7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: GuinjiColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.lavender,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: GuinjiColors.glowShadow, blurRadius: 16),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: GuinjiColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
