import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:characters/characters.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/shrine_order.dart';
import 'shrine_asset_path.dart';

/// README/HTML 프로토타입 `saveTalisman()`의 `<canvas>` 합성 알고리즘을
/// `dart:ui` Canvas로 그대로 옮긴 것 — 1080×1920 PNG 1장을 만들어
/// [saveImageBytesToGallery]/공유 경로에 그대로 넘길 수 있게 한다.
///
/// [서버 전담 원칙] 여기서 그리는 이름/사주/소망/날짜/일련번호는 전부
/// [ShrineOrder]에 이미 담긴 서버 계산값을 그대로 쓸 뿐이다 — 이 함수가
/// 새로 계산하는 값은 하나도 없다.
Future<Uint8List> buildTalismanSaveImageBytes(ShrineOrder order) async {
  const width = 1080.0;
  const height = 1920.0;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    const ui.Rect.fromLTWH(0, 0, width, height),
  );

  // 배경 그라디언트(#faf3e0 → #efe4c8, 세로).
  final bgPaint = ui.Paint()
    ..shader = ui.Gradient.linear(
      const ui.Offset(0, 0),
      const ui.Offset(0, height),
      [const ui.Color(0xFFFAF3E0), const ui.Color(0xFFEFE4C8)],
    );
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, width, height), bgPaint);

  const tw = 470.0;
  const th = 1360.0;
  const tx = (width - tw) / 2;
  const ty = 150.0;

  // 부적 이미지 로드(없으면 틀만 그리고 진행 — 자산 누락이 저장 자체를
  // 막지 않게 한다).
  ui.Image? talismanImage;
  try {
    final assetPath = shrineAssetPath(
      order.talisman.thumbPath ?? order.talisman.imagePath,
    );
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    talismanImage = frame.image;
  } catch (_) {
    talismanImage = null;
  }

  // 부적 뒤 그림자 받침(#e8c86a) — JS의 shadowBlur 40 근사.
  canvas.drawRect(
    const ui.Rect.fromLTWH(tx, ty, tw, th),
    ui.Paint()
      ..color = const ui.Color(0xFFE8C86A)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 20),
  );

  if (talismanImage != null) {
    final iw = talismanImage.width.toDouble();
    final ih = talismanImage.height.toDouble();
    // JS: sc = max(tw/sw, th/sh) — cover 크롭(중앙 기준).
    final sc = (tw / iw) > (th / ih) ? (tw / iw) : (th / ih);
    final cw = tw / sc;
    final ch = th / sc;
    final srcRect = ui.Rect.fromLTWH((iw - cw) / 2, (ih - ch) / 2, cw, ch);
    final dstRect = const ui.Rect.fromLTWH(tx, ty, tw, th);
    canvas.drawImageRect(talismanImage, srcRect, dstRect, ui.Paint());
  }

  // 이름 + 사주 세로쓰기(우측) — 반투명 금색 바탕.
  const vx = tx + tw * 0.86;
  double vy = ty + th * 0.30;
  canvas.drawRect(
    ui.Rect.fromLTWH(vx - 26, vy - 26, 52, 620),
    ui.Paint()..color = const ui.Color(0x99F3D98A),
  );

  void drawCenteredText(
    String text, {
    required double x,
    required double y,
    required String fontFamily,
    required double fontSize,
    required ui.FontWeight weight,
    required ui.Color color,
  }) {
    final span = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: fontFamily,
        fontWeight: weight,
        textAlign: ui.TextAlign.center,
      ),
    )
      ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize))
      ..addText(text);
    final paragraph = span.build()
      ..layout(const ui.ParagraphConstraints(width: 300));
    // ParagraphBuilder는 좌상단 기준이라 텍스트를 중앙(x)에 맞추기 위해
    // 폭 300 중앙(150)을 x로 오도록 보정한다.
    canvas.drawParagraph(paragraph, ui.Offset(x - 150, y - fontSize * 0.75));
  }

  for (final ch in order.ownerName.characters) {
    drawCenteredText(
      ch,
      x: vx,
      y: vy,
      fontFamily: 'Pretendard',
      fontSize: 38,
      weight: ui.FontWeight.w900,
      color: const ui.Color(0xFF8F120B),
    );
    vy += 46;
  }
  vy += 20;
  for (final ch in order.sajuPillars.replaceAll(' ', '').characters) {
    drawCenteredText(
      ch,
      x: vx,
      y: vy,
      fontFamily: 'NotoSerifKR',
      fontSize: 28,
      weight: ui.FontWeight.w800,
      color: const ui.Color(0xFF8F120B),
    );
    vy += 34;
  }

  // 일련번호 도장(좌측 하단, -0.1rad 회전).
  canvas.save();
  canvas.translate(tx + tw * 0.2, ty + th * 0.86);
  canvas.rotate(-0.1);
  canvas.drawRect(
    const ui.Rect.fromLTWH(-58, -36, 116, 72),
    ui.Paint()..color = const ui.Color(0xD9F3D98A),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(-58, -36, 116, 72),
    ui.Paint()
      ..color = const ui.Color(0xFFA3170E)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 5,
  );
  drawCenteredText(
    '神堂',
    x: 0,
    y: -12,
    fontFamily: 'NotoSerifKR',
    fontSize: 22,
    weight: ui.FontWeight.w900,
    color: const ui.Color(0xFFA3170E),
  );
  drawCenteredText(
    order.serial.replaceFirst('神堂 ', ''),
    x: 0,
    y: 14,
    fontFamily: 'NotoSerifKR',
    fontSize: 18,
    weight: ui.FontWeight.w800,
    color: const ui.Color(0xFFA3170E),
  );
  canvas.restore();

  // 하단 footer: 부적 이름 / 소망 / 날짜+일련번호.
  drawCenteredText(
    order.talisman.name,
    x: width / 2,
    y: ty + th + 90,
    fontFamily: 'NotoSerifKR',
    fontSize: 54,
    weight: ui.FontWeight.w900,
    color: const ui.Color(0xFF1F150C),
  );
  drawCenteredText(
    '"${order.wish}"',
    x: width / 2,
    y: ty + th + 152,
    fontFamily: 'Pretendard',
    fontSize: 30,
    weight: ui.FontWeight.w700,
    color: const ui.Color(0xFF4A3A2A),
  );
  drawCenteredText(
    '${order.issuedDateKey} · 神堂 ${order.serial.replaceFirst('神堂 ', '')} · 세상에 한 장뿐인 부적',
    x: width / 2,
    y: ty + th + 206,
    fontFamily: 'IBMPlexMono',
    fontSize: 22,
    weight: ui.FontWeight.w600,
    color: const ui.Color(0xFF7A6852),
  );

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width.toInt(), height.toInt());
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('부적 이미지 변환에 실패했어요.');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
    talismanImage?.dispose();
  }
}
