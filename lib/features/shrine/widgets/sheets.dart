// 신당(THE SHRINE) v4.0 설정 시트 / 엔딩 카드 저장 — [provider 포팅]
// 원본(신규 zip): lib/features/shrine/widgets/sheets.dart
// (flutter_riverpod WidgetRef/Consumer 기반)
// ─────────────────────────────────────────────────────────────
// showSettingsSheet(context, ref) → showSettingsSheet(context)로 변경.
// ref.watch(shrineProvider)/ref.read(shrineProvider.notifier) 호출은
// Consumer<ShrineSessionProvider>(provider.state / provider 자체의
// update/unlinkMember/resetData 메서드)로 대체한다.
// 레이아웃·문구·수치는 원본과 100% 동일하게 유지, API 치환만 수행했다.
// saveEndingCard()는 riverpod 의존이 없어 로직 그대로 포팅했다.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';

/// 설정 시트 — 상단 모서리 22px (이 화면만 현대 UI 어휘)
void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99000000),
    builder: (_) => Consumer<ShrineSessionProvider>(
      builder: (ctx, provider, __) {
        final st = provider.state;
        final t = T(1);
        Widget row(String l, String sub, Widget trailing) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: C.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l, style: t.ui(14)),
                    if (sub.isNotEmpty)
                      Text(sub, style: t.ui(11.5, c: C.faint)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        );
        Widget sw(bool v, VoidCallback f) => Switch(
          value: v,
          onChanged: (_) => f(),
          activeColor: C.fg,
          activeTrackColor: C.red,
          inactiveTrackColor: const Color(0x1FEFE4D2),
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B0D0B), Color(0xFF0A0505)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet)),
            border: Border(top: BorderSide(color: C.goldLine)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SETTINGS · 設定', style: t.mono),
              const SizedBox(height: 6),
              Text('신당의 결을 맞추세요', style: t.display(18)),
              const SizedBox(height: 14),
              row(
                '소리',
                '저음 · 방울 · 문 · 속삭임 · 심장 박동',
                sw(
                  st.sound,
                  () => provider.update((s) => s.copy(sound: !s.sound)),
                ),
              ),
              row(
                '움직임 줄이기',
                '연출 생략, 흔들림·입자 끄기',
                sw(
                  st.reduce,
                  () => provider.update((s) => s.copy(reduce: !s.reduce)),
                ),
              ),
              // [U8-4 포팅] 진동 — 원본 shrine-app.jsx
              // <Sw on={app.haptic} k={() => app.setPref({ haptic: !app.haptic })} label="진동" />
              row(
                '진동',
                '선택·인장·클라이맥스 등에 가볍게 울림',
                sw(
                  st.haptic,
                  () => provider.update((s) => s.copy(haptic: !s.haptic)),
                ),
              ),
              row(
                '클라이맥스 제한 시간',
                '향이 다 타기 전에 선택',
                sw(
                  st.timer,
                  () => provider.update((s) => s.copy(timer: !s.timer)),
                ),
              ),
              row(
                '글자 크기',
                '',
                SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: .92, label: Text('작게')),
                    ButtonSegment(value: 1, label: Text('보통')),
                    ButtonSegment(value: 1.12, label: Text('크게')),
                  ],
                  selected: {st.ts},
                  onSelectionChanged: (v) =>
                      provider.update((s) => s.copy(ts: v.first)),
                  showSelectedIcon: false,
                ),
              ),
              if (st.memberId != null)
                row(
                  '신통방통 연결 끊기',
                  '프로필 · 사주 캐시 삭제 (부적·결말 기록은 유지)',
                  OutlinedButton(
                    onPressed: () {
                      provider.unlinkMember();
                      Navigator.pop(ctx);
                    },
                    child: const Text('끊기'),
                  ),
                ),
              row(
                '처음 오신 분께 안내',
                '조작 안내 카드를 다시 봅니다',
                OutlinedButton(
                  onPressed: () {
                    provider.update((s) => s.copy(coached: false));
                    Navigator.pop(ctx);
                  },
                  child: const Text('다시 보기'),
                ),
              ),
              row(
                '기록 지우기',
                '이름 · 진행 · 모은 결말 · 부적함',
                OutlinedButton(
                  onPressed: () {
                    provider.resetData();
                    Navigator.pop(ctx);
                  },
                  child: const Text('지우기'),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '이 이야기는 허구의 창작물입니다. 실제 무속 상담이나 초자연적 능력을 주장하지 않습니다.',
                style: t.ui(11, c: C.faint),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// 결말 카드 1080×1920 PNG → 갤러리 저장 (웹 renderCard 와 동일 레이아웃)
/// riverpod 의존이 없어 원본 그대로 포팅(WidgetRef 매개변수 자체가 없었음).
Future<void> saveEndingCard(
  BuildContext context,
  Ending e,
  String? name,
) async {
  const w = 1080.0, h = 1920.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = C.bg);
  final data = await rootBundle.load('assets/shrine/img/${e.art}.jpg');
  final img = (await (await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
  )).getNextFrame()).image;
  final ih = h * .66;
  final r = (w / img.width) > (ih / img.height)
      ? w / img.width
      : ih / img.height;
  final dst = Rect.fromLTWH(
    (w - img.width * r) / 2,
    0,
    img.width * r,
    img.height * r,
  );
  c.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    Paint(),
  );
  c.drawRect(
    Rect.fromLTWH(0, 0, w, ih + 2),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, ih * .45), Offset(0, ih), [
        const Color(0x00070404),
        C.bg,
      ]),
  );
  void text(String s, TextStyle st, double y) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: st),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 120);
    tp.paint(c, Offset((w - tp.width) / 2, y));
  }

  c.save();
  c.translate(w / 2, 1290);
  c.rotate(-.08);
  c.drawRect(
    const Rect.fromLTWH(-56, -56, 112, 112),
    Paint()
      ..color = C.red
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 30),
  );
  c.drawRect(const Rect.fromLTWH(-56, -56, 112, 112), Paint()..color = C.red);
  c.restore();
  text(
    '結',
    GoogleFonts.notoSerifKr(
      fontSize: 60,
      fontWeight: FontWeight.w900,
      color: C.btnText,
    ),
    1250,
  );
  text(
    '엔딩 ${e.code}. ${e.name}',
    GoogleFonts.gowunBatang(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      color: C.gold,
    ),
    1395,
  );
  text(
    e.line,
    GoogleFonts.notoSerifKr(
      fontSize: 60,
      fontWeight: FontWeight.w900,
      color: C.fg,
      height: 1.4,
    ),
    1480,
  );
  text(
    '${name ?? '당신'}님의 이야기',
    GoogleFonts.gowunBatang(fontSize: 30, color: C.muted),
    1710,
  );
  text(
    '신당  神堂',
    GoogleFonts.eastSeaDokdo(fontSize: 80, color: const Color(0xFFF4EBDE)),
    1790,
  );
  final png = await (await rec.endRecording().toImage(
    w.toInt(),
    h.toInt(),
  )).toByteData(format: ui.ImageByteFormat.png);
  await Gal.putImageBytes(png!.buffer.asUint8List(), name: '신당_엔딩${e.code}');
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('결말 이미지를 저장했습니다')));
  }
}
