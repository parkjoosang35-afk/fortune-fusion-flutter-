import 'dart:ui' as ui;
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
  // [실기기 LateInitializationError 대응] 프레임 대기 자체가 일부 환경에서
  // 실패해도 이미 그려진 마지막 프레임으로 계속 진행한다.
  try {
    await WidgetsBinding.instance.endOfFrame;
  } catch (_) {}
  final bodyIndex = leadingKeys.length;
  final boundaries = <RenderRepaintBoundary>[];
  for (final part in [...leadingKeys, key, ...trailingKeys]) {
    final object = part.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary || object.debugNeedsPaint) {
      throw StateError('결과 화면 준비가 끝난 뒤 다시 시도해주세요.');
    }
    boundaries.add(object);
  }
  const ratio = 1.5;
  final width = boundaries.last.size.width;
  final height = boundaries.fold<double>(
    0,
    (total, part) => total + part.size.height,
  );
  if (width <= 0 ||
      height <= 0 ||
      width * height * ratio * ratio > 24000000 ||
      boundaries.any((part) => (part.size.width - width).abs() > 0.5)) {
    throw StateError('전체 페이지 크기 또는 저장 한도를 확인해주세요.');
  }
  final overlays = <RenderRepaintBoundary>[];
  for (final overlay in overlayKeys) {
    final object = overlay.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary ||
        object.debugNeedsPaint ||
        object.size.width > width ||
        object.size.height > boundaries[bodyIndex].size.height) {
      throw StateError('겹침 영역 준비가 끝난 뒤 다시 시도해주세요.');
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
    slots[bodyIndex] = await boundaries[bodyIndex].toImage(pixelRatio: ratio);
    for (var i = 0; i < boundaries.length; i++) {
      if (i == bodyIndex) continue;
      try {
        slots[i] = await boundaries[i].toImage(pixelRatio: ratio);
      } catch (_) {}
    }
    for (final overlay in overlays) {
      try {
        overlayImages.add(await overlay.toImage(pixelRatio: ratio));
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
