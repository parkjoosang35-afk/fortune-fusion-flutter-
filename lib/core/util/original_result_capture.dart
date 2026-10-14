import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'image_gallery_saver.dart';
import '../widgets/app_toast.dart';

/// 실제 화면에 배치된 전체 본문만 캡처한다. 텍스트 재구성/스크롤 스티치 없음.
Future<Uint8List> captureOriginalResult(
  GlobalKey key, {
  List<GlobalKey> leadingKeys = const [],
  List<GlobalKey> trailingKeys = const [],
  List<GlobalKey> overlayKeys = const [],
}) async {
  // [웹 공유 LateInitializationError 대응 — 2026-10 재발] 프레임 대기 자체가
  // 일부 환경에서 실패해도 이미 그려진 마지막 프레임으로 계속 진행한다.
  // 과거(d0c39a74/d68ee136/f5447ec) 안전망 적용 후에도 웹 릴리스(AOT) 빌드
  // 에서 동일 토스트가 재발 — 코드 전수 추적 결과 우리 코드에 해당 메시지와
  // 일치하는 `late` 변수가 전혀 없어, 캡처 영역 내부에 배치된 AdSense
  // `HtmlElementView`(플랫폼 뷰, platform_view 비동기 등록)가 아직 완전히
  // 자리잡기 전에 `toImage()`가 호출되는 타이밍 경쟁이 유력한 원인으로
  // 추정된다. 기존 테스트 하네스(widget test의 수동 pump 사이클)와의
  // 호환을 위해 endOfFrame 대기 자체는 1회로 유지하고, 그 뒤에 짧은
  // 유예시간만 추가해 플랫폼 뷰 합성이 안정될 시간을 더 준다(부작용 없음 —
  // 수십~백 ms 지연만 추가, runAsync 환경의 실제 타이머에서만 유효).
  try {
    await WidgetsBinding.instance.endOfFrame;
  } catch (_) {}
  try {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  } catch (_) {}
  final bodyIndex = leadingKeys.length;
  final boundaries = <RenderRepaintBoundary?>[];
  final parts = [...leadingKeys, key, ...trailingKeys];
  for (var index = 0; index < parts.length; index++) {
    final object = parts[index].currentContext?.findRenderObject();
    final ready = object is RenderRepaintBoundary && !object.debugNeedsPaint && object.hasSize;
    if (!ready && index == bodyIndex) {
      throw StateError('결과 화면 준비가 끝난 뒤 다시 시도해주세요.');
    }
    boundaries.add(ready ? object as RenderRepaintBoundary : null);
  }
  final body = boundaries[bodyIndex]!;
  final width = body.size.width;
  final height = boundaries.fold<double>(
    0,
    (total, part) => total + (part?.size.height ?? 0),
  );
  // 긴 결과는 픽셀 비율을 낮춰 메모리 한도 안에서 전체 본문을 보존한다.
  final ratio = width > 0 && height > 0
      ? (24000000 / (width * height)).clamp(0.01, 2.25).toDouble()
      : 0.0;
  final pixelRatio = ratio > 0 ? math.sqrt(ratio) : 0.0;
  if (width <= 0 ||
      height <= 0 ||
      pixelRatio < 0.25 ||
      boundaries.whereType<RenderRepaintBoundary>().any((part) => (part.size.width - width).abs() > 0.5)) {
    throw StateError('전체 페이지 크기 또는 저장 한도를 확인해주세요.');
  }
  final overlays = <RenderRepaintBoundary>[];
  for (final overlay in overlayKeys) {
    final object = overlay.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary ||
        object.debugNeedsPaint ||
        object.size.width > width ||
        object.size.height > body.size.height) {
      continue;
    }
    overlays.add(object);
  }
  final overlayImages = <ui.Image>[];
  final slots = List<ui.Image?>.filled(boundaries.length, null);
  ui.Picture? picture;
  ui.Image? combined;
  try {
    // [실기기 대응 — 본문 우선] 본문 캡처 성공이 곧 결과 보장. 상단·하단·겹침
    // 영역은 추가로 시도하고 하나가 실패해도 무시하고 진행한다.
    slots[bodyIndex] = await body.toImage(pixelRatio: pixelRatio);
    for (var i = 0; i < boundaries.length; i++) {
      if (i == bodyIndex) continue;
      try {
        final boundary = boundaries[i];
        if (boundary != null) slots[i] = await boundary.toImage(pixelRatio: pixelRatio);
      } catch (_) {}
    }
    for (final overlay in overlays) {
      try {
        overlayImages.add(await overlay.toImage(pixelRatio: pixelRatio));
      } catch (_) {}
    }
    final captured = slots.whereType<ui.Image>().toList();
    if (captured.length == 1 && overlayImages.isEmpty) {
      combined = captured.single;
    } else {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      double y = 0;
      double overlayTop = 0;
      for (var i = 0; i < slots.length; i++) {
        final image = slots[i];
        if (image == null) continue;
        if (i == bodyIndex) overlayTop = y;
        canvas.drawImage(image, Offset(0, y), Paint());
        y += image.height;
      }
      for (final overlay in overlayImages) {
        canvas.drawImage(overlay, Offset(0, overlayTop), Paint());
      }
      picture = recorder.endRecording();
      combined = await picture.toImage(slots[bodyIndex]!.width, y.toInt());
    }
    final data = await combined.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('전체 이미지 변환 실패');
    return data.buffer.asUint8List();
  } finally {
    if (picture != null) combined?.dispose();
    for (final image in slots) {
      image?.dispose();
    }
    for (final image in overlayImages) {
      image.dispose();
    }
    picture?.dispose();
  }
}

Future<bool> saveOriginalResult(
  BuildContext context,
  GlobalKey key, {
  required String name,
  List<GlobalKey> leadingKeys = const [],
  List<GlobalKey> trailingKeys = const [],
  List<GlobalKey> overlayKeys = const [],
}) async {
  try {
    final bytes = await captureOriginalResult(
      key,
      leadingKeys: leadingKeys,
      trailingKeys: trailingKeys,
      overlayKeys: overlayKeys,
    );
    final saved = await saveImageBytesToGallery(bytes, name: name);
    if (!saved) throw StateError('저장 권한 또는 다운로드 설정을 확인해주세요.');
    if (context.mounted) {
      AppToast.show(
        context,
        kIsWeb ? '원래 결과 페이지 파일 다운로드를 요청했어요.' : '원래 결과 페이지를 갤러리에 저장했어요.',
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      AppToast.show(context, '전체 저장 실패: $error', isError: true);
    }
    return false;
  }
}

/// 고정 높이 장면은 배경·오버레이·카드를 포함한 실제 장면 전체를 캡처한다.
/// 스크롤 본문에 사용하면 화면 밖 항목이 빠지므로 그 경우 OriginalResultBody 사용.
class OriginalResultScene extends StatelessWidget {
  const OriginalResultScene({
    super.key,
    required this.captureKey,
    required this.background,
    required this.child,
  });
  final GlobalKey captureKey;
  final Color background;
  final Widget child;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: captureKey,
    child: ColoredBox(color: background, child: child),
  );
}

/// 화면에 쓰는 동일한 자식 위젯을 전체 높이로 배치하여 화면 밖 본문도 그린다.
class OriginalResultBody extends StatelessWidget {
  const OriginalResultBody({
    super.key,
    required this.captureKey,
    required this.child,
    required this.background,
    this.padding = EdgeInsets.zero,
    this.frame,
  });
  final GlobalKey captureKey;
  final Widget child;
  final Color background;
  final EdgeInsetsGeometry padding;
  final Widget Function(Widget child)? frame;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: RepaintBoundary(
      key: captureKey,
      child:
          frame?.call(
            ColoredBox(
              color: background,
              child: Padding(padding: padding, child: child),
            ),
          ) ??
          ColoredBox(
            color: background,
            child: Padding(padding: padding, child: child),
          ),
    ),
  );
}
