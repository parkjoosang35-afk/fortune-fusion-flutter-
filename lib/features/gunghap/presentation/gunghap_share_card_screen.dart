// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_share_card_screen.dart
// [궁합지도 핸드오프 v4 — S24 결과 공유 카드] 00_DEV_MAPPING.md §5 S24
// 명세(구조표 18, 전용 화면) 구현. GunghapResultScreen이 이미 쓰고 있는
// 검증된 캡처/저장 패턴(`captureOriginalResult`/`saveImageBytesToGalleryDetailed`,
// 귀인지도 `guinji_result_card_screen.dart`와 동일 구조)을 그대로 재사용한다.
//
// [S24 명세 — 00_DEV_MAPPING.md 571-577줄]
// AppBar(← · 「결과 공유」) · 세그먼트(세로형 9:16 / 정사각 1:1) ·
// 카드(세로 250w / 정사각 300w, r24, 이중 테두리, 모서리 ✦4개, radial
// 보라32%+핑크16% 배경 + #F4F0F8→#FAF8FC) · mono「SINTONG BANGTONG」+
// 로고「궁합지도」+「{나}✦{상대}」(24/19 900)+「{한자}·{분야}{·세부(세로만)}」+
// 중앙 GHScoreRing128/96(뒤 StarMap 55%)+인용「"{한 줄 요약}"」+
// 하단박스「우리 궁합도 확인해 보세요·sintong.app/map」, 점선민트
// 「✓생년월일과 태어난 시간, 상세 풀이는 공유 이미지에 담기지 않아요.」,
// Footer(카카오「카카오톡으로 공유」+2열 Secondary「이미지 저장」(RepaintBoundary)/
// 「링크 복사」).
//
// [설계 결정 — 이번 턴]
// · "한 줄 요약" 슬롯: 서버에 전용 summary 필드가 없으므로(gunghap_data.dart/
//   gunghap_repository.dart 확인 완료) 이미 결과 화면이 쓰는 `relationTypeDesc`를
//   그대로 재사용한다(guinji_guest_result_screen.dart 주석에서도 동일하게
//   "한 줄 요약" 역할로 재사용된 선례가 있다).
// · 카카오 공유: 궁합 결과는 로그인 전용·소유자 전용 리소스라 서버에
//   결과 전용 OG 이미지 생성 라우트가 없다(gunghap_share_kakao.dart 상단
//   주석 재확인). FeedTemplate은 imageUrl이 필수이므로, 이미 검증된
//   `shareGunghapInvite`와 동일하게 TextTemplate 기반으로 단순화한다 —
//   카카오톡 설치 시 텍스트+링크를 공유 시트로 보내고, 미설치/웹/실패 시
//   `safeShareText`(공용 폴백)로 넘어간다. 새 서버 API를 추가하지 않는다.
// · "링크 복사": 궁합 결과 자체는 비공개(소유자 전용)이므로 그 결과를
//   그대로 여는 공개 링크가 서버에 없다. 대신 "우리 궁합도 확인해
//   보세요" 하단 박스가 안내하는 궁합지도 홈 진입 링크
//   (`EnvConfig.adminApiBaseUrl`)를 복사한다 — 디자인 카피의 의도(상대를
//   궁합지도로 초대)와 일치한다.
// · StarMap 배경: `StarMap`이 `AspectRatio(4/3)`으로 고정돼 있어, 카드
//   전체(9:16/1:1)를 채우는 배경으로 쓰려면 `SizedBox.expand` +
//   `FittedBox(fit: BoxFit.cover)`로 감싸 카드 크기에 맞게 확대한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

import '../../../core/config/env_config.dart';
import '../../../core/util/original_result_capture.dart';
import '../../../core/util/safe_share.dart';
import '../../../core/util/save_filename.dart';
import '../../../core/widgets/app_toast.dart';
import '../domain/gunghap_data.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_score_ring.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';

class GunghapShareCardScreen extends StatefulWidget {
  const GunghapShareCardScreen({
    super.key,
    required this.resultId,
    required this.ownerName,
    required this.guestName,
    required this.major,
    required this.subDisplay,
    this.score,
    this.relationTypeDesc,
  });

  final String resultId;
  final String ownerName;
  final String guestName;
  final GHMajor major;

  /// 사용자가 고른 세부 주제명(없으면 [major.name]과 동일 — 호출부에서
  /// 이미 `subName ?? major.name`으로 계산해 전달한다).
  final String subDisplay;
  final int? score;

  /// 카드 인용구 슬롯 — [relationTypeDesc]를 "한 줄 요약"으로 재사용한다
  /// (설계 결정 — 파일 상단 주석 참고). null이면 인용 영역을 생략한다.
  final String? relationTypeDesc;

  @override
  State<GunghapShareCardScreen> createState() => _GunghapShareCardScreenState();
}

class _GunghapShareCardScreenState extends State<GunghapShareCardScreen> {
  bool _isSquare = false;
  final _cardKey = GlobalKey();
  bool _savingImage = false;
  bool _copyingLink = false;
  bool _kakaoSharing = false;

  // [S24 — 이미지 저장] GunghapResultScreen._saveImage와 완전히 동일한
  // 구조. 카드 레이어(_cardKey)만 캡처 대상이 다르다.
  Future<void> _saveImage() async {
    if (_savingImage) return;
    setState(() => _savingImage = true);
    try {
      await saveOriginalResult(
        context,
        _cardKey,
        name: buildSaveFileName('gunghap_share', widget.resultId),
      );
    } finally {
      if (mounted) setState(() => _savingImage = false);
    }
  }

  // [S24 — 링크 복사] 설계 결정 참고(파일 상단 주석). 궁합지도 홈 진입
  // 링크를 복사한다 — 서버에 결과 공개 링크가 없으므로 결과 자체가
  // 아니라 "나도 궁합 보러 가기" 동선을 전달한다.
  Future<void> _copyLink() async {
    if (_copyingLink) return;
    setState(() => _copyingLink = true);
    try {
      await Clipboard.setData(
        ClipboardData(text: EnvConfig.adminApiBaseUrl),
      );
      if (!mounted) return;
      AppToast.show(context, '링크를 복사했어요.');
    } finally {
      if (mounted) setState(() => _copyingLink = false);
    }
  }

  // [S24 — 카카오톡 공유] 설계 결정 참고(파일 상단 주석). 결과 전용 OG
  // 이미지 라우트가 없어 FeedTemplate 대신 TextTemplate으로 단순화한다
  // (gunghap_share_kakao.dart의 `shareGunghapInvite`와 동일한 폴백
  // 원칙: 미설치/웹/실패 시 `safeShareText`).
  Future<void> _shareKakao() async {
    if (_kakaoSharing) return;
    final link = EnvConfig.adminApiBaseUrl;
    final scoreText = widget.score != null ? '${widget.score}점 · ' : '';
    final message =
        '${widget.ownerName}님과 ${widget.guestName}님의 ${widget.subDisplay} 결과\n'
        '$scoreText${widget.major.hanja} · ${widget.major.name}\n'
        '우리 궁합도 확인해 보세요 › $link';

    if (kIsWeb) {
      await safeShareText(
        context,
        message,
        subject: '궁합지도 결과 공유 · 귀인지도',
        copiedMessage: '공유 메시지를 복사했어요. 원하는 앱에 붙여넣어 전달해 주세요.',
        failedMessage: '공유 시트를 열 수 없어 메시지를 복사했어요.',
      );
      return;
    }

    setState(() => _kakaoSharing = true);
    try {
      final available = await ShareClient.instance.isKakaoTalkSharingAvailable();
      if (available) {
        final shareUri = await ShareClient.instance.shareDefault(
          template: TextTemplate(
            text: message,
            link: Link(
              webUrl: Uri.parse(link),
              mobileWebUrl: Uri.parse(link),
            ),
          ),
        );
        await ShareClient.instance.launchKakaoTalk(shareUri);
        return;
      } else if (kDebugMode) {
        debugPrint('[GunghapShareCard] 카카오톡 미설치/공유 불가 — 공통 폴백으로 전환');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GunghapShareCard] 카카오톡 공유 실패: $e — 공통 폴백으로 전환');
      }
    } finally {
      if (mounted) setState(() => _kakaoSharing = false);
    }
    if (!mounted) return;
    await safeShareText(
      context,
      message,
      subject: '궁합지도 결과 공유 · 귀인지도',
      copiedMessage: '공유 메시지를 복사했어요. 카카오톡 등 원하는 앱에 붙여넣어 전달해 주세요.',
      failedMessage: '공유 시트를 열 수 없어 메시지를 복사했어요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GHScreen(
      appBar: GHAppBar(
        title: '결과 공유',
        onBack: () => Navigator.of(context).pop(),
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GHButton(
            label: _kakaoSharing ? '…' : '카카오톡으로 공유',
            variant: GHButtonVariant.kakao,
            onPressed: _kakaoSharing ? null : _shareKakao,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GHButton(
                  label: _savingImage ? '…' : '이미지 저장',
                  variant: GHButtonVariant.secondary,
                  onPressed: _savingImage ? null : _saveImage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GHButton(
                  label: _copyingLink ? '…' : '링크 복사',
                  variant: GHButtonVariant.secondary,
                  onPressed: _copyingLink ? null : _copyLink,
                ),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _FormatSegment(
            isSquare: _isSquare,
            onChanged: (v) => setState(() => _isSquare = v),
          ),
          const SizedBox(height: 24),
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: _ShareCard(
                square: _isSquare,
                ownerName: widget.ownerName,
                guestName: widget.guestName,
                major: widget.major,
                subDisplay: widget.subDisplay,
                score: widget.score,
                quote: widget.relationTypeDesc,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _DashedPrivacyNotice(),
        ],
      ),
    );
  }
}

/// [S24 — 세그먼트] 「세로형 9:16」 / 「정사각 1:1」 2분할 토글.
class _FormatSegment extends StatelessWidget {
  const _FormatSegment({required this.isSquare, required this.onChanged});
  final bool isSquare;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: GHSpace.segmentHeight,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: GHColors.fieldBg,
      borderRadius: BorderRadius.circular(GHRadius.segment),
    ),
    child: Row(
      children: [
        Expanded(child: _SegmentItem(label: '세로형 9:16', active: !isSquare, onTap: () => onChanged(false))),
        Expanded(child: _SegmentItem(label: '정사각 1:1', active: isSquare, onTap: () => onChanged(true))),
      ],
    ),
  );
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: GHMotion.press,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? GHColors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(GHRadius.segmentItem),
        boxShadow: active ? GHShadow.card : null,
      ),
      child: Text(
        label,
        style: GHText.ui(
          size: 13,
          weight: FontWeight.w700,
          color: active ? GHColors.accent : GHColors.muted,
        ),
      ),
    ),
  );
}

/// [S24 — 공유 카드 본체] 세로(250×444, 9:16) / 정사각(300×300, 1:1).
class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.square,
    required this.ownerName,
    required this.guestName,
    required this.major,
    required this.subDisplay,
    required this.score,
    required this.quote,
  });

  final bool square;
  final String ownerName;
  final String guestName;
  final GHMajor major;
  final String subDisplay;
  final int? score;
  final String? quote;

  @override
  Widget build(BuildContext context) {
    final width = square ? 300.0 : 250.0;
    final height = square ? 300.0 : 444.0;
    final ringSize = square ? 96.0 : 128.0;
    final showSub = !square && subDisplay != major.name;
    final band = score != null ? GHBand.of(score!) : null;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GHRadius.card + 4),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4F0F8), Color(0xFFFAF8FC)],
        ),
        border: Border.all(color: GHColors.line, width: GHBorder.width),
        boxShadow: GHShadow.xl,
      ),
      child: Stack(
        children: [
          // ── radial 보라32% + 핑크16% 배경 워시 ──
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.7),
                    radius: 1.1,
                    colors: [Color(0x528B6FD8), Color(0x008B6FD8)],
                  ),
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.7, 0.9),
                      radius: 1.1,
                      colors: [Color(0x29EC8AA6), Color(0x00EC8AA6)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── 중앙 StarMap 55% 배경(카드 전체를 채우도록 cover 확대) ──
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 320,
                      height: 240,
                      child: StarMap(
                        aName: ownerName,
                        bName: guestName,
                        rings: false,
                        draw: true,
                        labels: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── 이중 테두리 안쪽 보더 ──
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GHRadius.card - 2),
                    border: Border.all(
                      color: GHColors.accent.withValues(alpha: .28),
                      width: GHBorder.width,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── 모서리 ✦4개 장식 ──
          const Positioned(top: 10, left: 12, child: _CornerStar()),
          const Positioned(top: 10, right: 12, child: _CornerStar()),
          const Positioned(bottom: 10, left: 12, child: _CornerStar()),
          const Positioned(bottom: 10, right: 12, child: _CornerStar()),
          // ── 본문 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    GHMono('SINTONG BANGTONG', color: GHColors.violetText),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: GHColors.accent),
                        const SizedBox(width: 5),
                        Text('궁합지도', style: GHText.cardTitle(size: 13, color: GHColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$ownerName ✦ $guestName',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GHText.title(size: square ? 19 : 24, color: GHColors.fg),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      showSub
                          ? '${major.hanja} · ${major.name} · $subDisplay'
                          : '${major.hanja} · ${major.name}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GHText.ui(size: 12.5, weight: FontWeight.w600, color: GHColors.muted),
                    ),
                  ],
                ),
                if (score != null && band != null)
                  GHScoreRing(score: score!, size: ringSize, sub: band.label, animate: false)
                else
                  const SizedBox.shrink(),
                Column(
                  children: [
                    if (quote != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '"$quote"',
                          textAlign: TextAlign.center,
                          maxLines: square ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: GHText.ui(size: 12.5, height: 1.55, color: GHColors.fg),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: GHColors.card.withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GHColors.lineSoft),
                      ),
                      child: Column(
                        children: [
                          Text('우리 궁합도 확인해 보세요', style: GHText.ui(size: 11.5, weight: FontWeight.w700, color: GHColors.fg)),
                          const SizedBox(height: 2),
                          GHMono('sintong.app/map', color: GHColors.muted),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerStar extends StatelessWidget {
  const _CornerStar();
  @override
  Widget build(BuildContext context) =>
      Text('✦', style: TextStyle(fontSize: 12, color: GHColors.accent.withValues(alpha: .55)));
}

/// [S24 — 점선 민트 안내] 「✓ 생년월일과 태어난 시간, 상세 풀이는 공유
/// 이미지에 담기지 않아요.」 S16 `_DashedMintNotice`(gunghap_guest_result_
/// screen.dart)와 동일한 `CustomPaint` 점선 박스 구조를 재사용한다.
class _DashedPrivacyNotice extends StatelessWidget {
  const _DashedPrivacyNotice();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedRectPainter(color: GHColors.mint, radius: 14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✓', style: TextStyle(fontSize: 13, color: GHColors.mint, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '생년월일과 태어난 시간, 상세 풀이는 공유 이미지에 담기지 않아요.',
              style: GHText.ui(size: 12, height: 1.6, color: GHColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color, required this.radius});
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
      ..strokeWidth = GHBorder.width;
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
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
