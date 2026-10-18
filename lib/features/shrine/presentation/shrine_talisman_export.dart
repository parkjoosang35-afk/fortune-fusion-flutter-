// shrine_talisman_export.dart — 신당 소지부 PNG 내보내기(저장·공유).
// 레퍼런스: 신당 디자인 핸드오프 export/talisman_export.dart.
//
// [통합 Fix 07] 레퍼런스 구현은 RenderView/PipelineOwner/BuildOwner를 직접
// 조립해 화면 밖에서 렌더링했으나(renderWidget()), 이 프로젝트는 이미 동일
// 목적의 더 단순하고 검증된 패턴 — RepaintBoundary를 화면 밖 좌표
// (Positioned(left:-9999)) 에 실제로 상시 마운트해 두었다가 toImage()로
// 캡처하는 방식 — 을 여러 결과 화면(원래 결과 페이지 캡처 등,
// core/util/original_result_capture.dart / wallpaper_screen.dart)에서 쓰고
// 있으므로 그 패턴을 그대로 재사용한다(표준 불변 제약: 기존 엔진 재구현
// 금지). 저장은 lib/core/util/image_gallery_saver.dart(Android: gal 패키지로
// 실제 갤러리 저장, Web: 브라우저 다운로드)를, 공유는 이미 pubspec에 존재하는
// share_plus의 Share.shareXFiles()를 그대로 재사용한다(신규 의존성 추가 없음,
// image_gallery_saver_plus 등 신당 스타터 전용 패키지는 도입하지 않는다).
//
// A5 인쇄(PDF) 내보내기는 이번 범위(受·用 2단계)에 포함되지 않아 포팅하지
// 않는다 — 필요 시 pdf/printing 패키지(이미 pubspec에 존재)로 추후 추가 가능.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/util/image_gallery_saver.dart';
import '../domain/shrine_rite_data.dart';
import '../domain/shrine_session.dart';
import '../domain/shrine_tokens.dart';
import 'widgets/shrine_bujeok.dart';

class ShrineTalismanExport {
  ShrineTalismanExport._();

  /// 화면·PNG가 공유하는 1080×1920 레이아웃 — 같은 [ShrineBujeok] 위젯을
  /// 그대로 사용한다(신당_개발지시서_v1.4.pdf §7.4 "화면에서 본 그 부적이
  /// 그대로 종이가 되어야 함").
  static Widget pngLayout(ShrineSession s, {bool hideName = false}) {
    final topic = shrineTopics[s.topic]!;
    return SizedBox(
      width: 1080,
      height: 1920,
      child: DecoratedBox(
        decoration: const BoxDecoration(
            gradient: RadialGradient(
                center: Alignment(0, -.08), radius: .75, colors: [Color(0xFF3A160E), ShrineColor.bg])),
        child: Stack(children: [
          Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: Center(child: Text('所持符 · ${topic.hanja}', style: ShrineType.mono(size: 24)))),
          Positioned(
              top: 260,
              left: 240,
              width: 600,
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      boxShadow: [BoxShadow(color: Color(0x38FFAA5A), blurRadius: 120)]),
                  child: ShrineBujeok(
                      name: hideName ? '' : s.name, birth: s.birth, hour: s.hour, topic: topic))),
          Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Column(children: [
                Text(hideName ? topic.name : '${s.displayName}님의 ${topic.name}',
                    style: ShrineType.say(1, size: 40, w: FontWeight.w700)),
                const SizedBox(height: 24),
                Text('神堂 · 창작 연출물', style: ShrineType.mono(c: ShrineColor.faint, size: 22)),
              ])),
        ]),
      ),
    );
  }

  /// [exportKey]가 가리키는 RepaintBoundary를 PNG 바이트로 캡처한다.
  /// [ShrineTalismanLayer]가 화면 밖에 상시 마운트해 두므로 호출 시점에는
  /// 보통 이미 최소 한 프레임 그려진 상태다.
  static Future<Uint8List?> capture(GlobalKey exportKey) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {}
    final obj = exportKey.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary || obj.debugNeedsPaint) return null;
    final image = await obj.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// 캡처 + 갤러리 저장(프로젝트 기존 gal 패턴). 성공 시 캡처된 PNG 바이트를
  /// 반환한다(공유 시트 미리보기 등에 재사용 가능), 실패하면 null.
  static Future<Uint8List?> savePng(GlobalKey exportKey, {required String topicKey}) async {
    final bytes = await capture(exportKey);
    if (bytes == null) return null;
    final ok = await saveImageBytesToGallery(bytes,
        name: 'sindang_${topicKey}_${DateTime.now().millisecondsSinceEpoch}');
    return ok ? bytes : null;
  }

  /// PNG 바이트를 OS 공유 시트로 전달한다(share_plus, 신규 의존성 없음).
  /// 이미지 첨부 공유는 웹에서도 mailto: 버그와 무관하게 안전하게 동작한다
  /// (core/util/safe_share.dart 문서 참고 — shareXFiles는 실패 시 파일
  /// 다운로드로 폴백).
  static Future<bool> share(Uint8List bytes) async {
    try {
      final result = await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'sindang.png')],
        text: '神堂 · 창작 연출물',
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  }
}

/// 화면 밖(−9999, −9999)에 항상 마운트해 두는 숨은 레이어. 사용자 눈에는
/// 보이지 않지만 실제로 레이아웃·페인트되므로 RepaintBoundary.toImage()로
/// 언제든 즉시 캡처할 수 있다(여러 결과 화면이 쓰는 오프스크린 캡처 패턴
/// 재사용 — 새로운 렌더 파이프라인을 직접 조립하지 않는다).
class ShrineTalismanLayer extends StatelessWidget {
  final GlobalKey exportKey;
  final ShrineSession session;
  final bool hideName;
  const ShrineTalismanLayer(
      {super.key, required this.exportKey, required this.session, this.hideName = false});
  @override
  Widget build(BuildContext context) => Positioned(
      left: -9999,
      top: -9999,
      width: 1080,
      height: 1920,
      child: IgnorePointer(
          child: RepaintBoundary(
              key: exportKey, child: ShrineTalismanExport.pngLayout(session, hideName: hideName))));
}
