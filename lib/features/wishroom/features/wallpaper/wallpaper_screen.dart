// S-01~S-07 배경화면 — docs/WALLPAPER.md · app2/wallpaper2.jsx 1:1 이식.
// WallpaperScreen(S-02 메인) · WPFullPreview(S-03) · WPMaking(S-04 iOS 진행) ·
// WPIosDone(S-05 iOS 저장완료) · WPApplied(적용 시뮬레이션: 잠금↔홈) · WPEntryCard(S-01).
//
// [픽셀 일치 3원칙] 배경화면 미리보기(WPCanvas 대체)는 네이티브 Canvas 렌더러를
// 새로 만들지 않고, docs/WALLPAPER.md §3 "같은 좌표" 원칙대로 기존 RoomScene을
// WrCanvasScaler로 감싸 그대로 쓴다 — room+equip+level에서 미리보기/실제 배경화면이
// 같은 결과를 내는 것이 FR-W-11 보장의 핵심이다(room_scene.dart 주석 참고).
//
// [플랫폼 방침 — 사용자 확정] 이 앱은 안드로이드 전용으로 빌드/배포된다(ios/ 폴더에
// 커스텀 네이티브 코드가 없음 확인됨). Android는 WishRoomWallpaperService.kt +
// WallpaperPlugin.kt로 실제 OS 라이브 배경화면이 완전히 동작하는 프로덕션 코드다.
// iOS Live Photo는 PHAssetCreationRequest 저장에 필요한 Xcode 프로젝트/Swift 빌드
// 파이프라인 자체가 이 프로젝트에 없어 실제 구현이 불가능하므로, 디자인 핸드오프의
// 화면 흐름(S-04/S-05)만 1:1로 보존하고 마지막 저장 단계만 시뮬레이션으로 유지한다
// — 이 방침은 사용자에게 명시적으로 확인받았다(2026-10-02, "iOS는 시뮬레이션으로
// 간다"는 agent 제안에 "응"으로 확정 응답).
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';
import 'wallpaper_service.dart';
import '../../core/wr_nav_pill.dart';
import '../../core/wr_toast.dart';

/// 지금 활성 플랫폼. 이 프로젝트는 Android 전용 빌드이므로 상수로 둔다(§4 공통 —
/// ios/ 폴더에 실제 네이티브 빌드 파이프라인이 없어 Live Photo 경로는 화면
/// 흐름만 보존하고 비활성 처리). 추후 iOS 네이티브 빌드가 추가되면 Platform.isIOS로 교체.
const bool _kIosFlow = false;

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});
  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  String? _roomId;
  bool _full = false;
  MakingState? _mk;
  ({String kind, String? target, Uint8List? thumb})? _done;
  final _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final p = context.read<WishRoomProvider>();
    _roomId = p.room?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      p.loadWallpaperStatus();
      if (p.archiveRooms.isEmpty) p.loadArchive();
    });
  }

  WishRoom? _roomFor(WishRoomProvider p) {
    final r = p.room;
    if (r != null && r.id == _roomId) return r;
    for (final a in p.archiveRooms) {
      if (a.id == _roomId) return a;
    }
    return null;
  }

  Future<void> _applyAndroid(WishRoomProvider p, WishRoom room, String target) async {
    // §4 Android — BOTH: ACTION_CHANGE_LIVE_WALLPAPER 시스템 미리보기로 이동(네이티브가
    // 이미 syncManifest로 최신 상태를 쥐고 있음). HOME/LOCK: 정지 프레임을 캡처해
    // WallpaperManager.setBitmap(FLAG_SYSTEM|FLAG_LOCK)으로 직접 설정(Q5 확정 가정).
    bool nativeOk;
    if (target == 'BOTH') {
      nativeOk = await WallpaperService.requestChangeLiveWallpaper();
    } else {
      final bytes = await _captureStillFrame();
      nativeOk = bytes != null && await WallpaperService.setStaticWallpaper(bytes, target: target);
    }
    if (!mounted) return;
    if (!nativeOk && target == 'BOTH') {
      // 웹 프리뷰 등 네이티브 채널이 없는 환경에서도 디자인 검수 흐름은 계속 보여준다.
    }
    final ok = await p.setWallpaper(room.id, platform: 'android', target: target, version: 1);
    if (!mounted) return;
    if (ok) {
      setState(() => _done = (kind: 'android', target: target, thumb: null));
    } else if (p.lastError != null) {
      WrToast.show(context, p.lastError!.message);
    }
  }

  Future<Uint8List?> _captureStillFrame() async {
    try {
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _makeIOS(WishRoomProvider p, WishRoom room) async {
    // iOS Live Photo 파이프라인은 이 프로젝트에 네이티브 빌드 기반이 없어 실제
    // PHAssetCreationRequest 저장은 불가능하다 — S-04/S-05 화면 흐름(디자인 검수용)만
    // 1:1 재현하고, 마지막 저장 단계만 시뮬레이션으로 대체한다. 사용자 확정 방침:
    // Android는 완전한 프로덕션 코드, iOS는 네이티브 빌드 인프라 부재로 시뮬레이션.
    final state = MakingState();
    setState(() => _mk = state);
    await Future.delayed(const Duration(milliseconds: 500));
    for (var i = 1; i <= 8; i++) {
      if (state.cancelled) return;
      await Future.delayed(const Duration(milliseconds: 90));
      if (mounted) setState(() => state.p = i * 4);
    }
    if (state.cancelled) return;
    if (mounted) setState(() { state.stage = 1; state.p = 60; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (state.cancelled) return;
    final thumb = await _captureStillFrame();
    if (mounted) setState(() { state.stage = 2; state.p = 94; state.thumb = thumb; });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || state.cancelled) return;
    final ok = await p.setWallpaper(room.id, platform: 'ios', target: 'BOTH', version: 1);
    if (!mounted) return;
    setState(() => _mk = null);
    if (ok) {
      setState(() => _done = (kind: 'ios', target: null, thumb: thumb));
    } else if (p.lastError != null) {
      WrToast.show(context, p.lastError!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        body: Consumer<WishRoomProvider>(builder: (context, p, __) {
          final room = _roomFor(p);
          final st = p.wallpaperStatus;
          final isSet = st.isSet && st.roomId == _roomId;
          final fulfilled = room?.status == RoomStatus.ARCHIVED;

          return Stack(children: [
            SafeArea(
            child: Column(children: [
              // app2/wallpaper2.jsx › TopBar(title="소원방 배경화면") nav 기본값 true로
              // NavPill(뒤로가기+신통방통 홈)이 좌측에 온다. [버그수정 — 전수감사] 기존엔
              // 단순 뒤로가기 아이콘만 있고 "신통방통 홈" 버튼이 없었다.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(children: [
                  WrNavPill(onBack: () => Navigator.of(context).maybePop(), onExitHome: () => wrExitHome(context)),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Text('소원방 배경화면', style: WrF.display(16)),
                    if (room != null) Text('${room.levelName} · v1', style: WrF.mono()),
                  ])),
                  const SizedBox(width: 48),
                ]),
              ),
              Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 40), children: [
                // ── 미리보기 카드 9:19.5 + 설명 ──
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(
                    onTap: room == null ? null : () => setState(() => _full = true),
                    child: Container(
                      width: 150,
                      height: 150 * 19.5 / 9,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: const Color(0xFF12060E),
                        border: Border.all(color: const Color(0xFF3A2C38), width: 6),
                        boxShadow: const [
                          BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 16)),
                          BoxShadow(color: Color(0x2EF2628F), blurRadius: 40),
                        ],
                      ),
                      child: Stack(fit: StackFit.expand, children: [
                        if (room != null)
                          RepaintBoundary(key: _previewKey, child: WrCanvasScaler(child: RoomScene(room: room, items: p.items, frozen: true, lowFx: true)))
                        else
                          const Center(child: Icon(Icons.auto_awesome, color: Colors.white24, size: 40)),
                        const Positioned(
                          left: 0, right: 0, bottom: 8,
                          child: Text('눌러서 크게 보기', textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Color(0xCCFFF6EC))),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_kIosFlow ? 'IOS · LIVE PHOTO' : 'ANDROID · LIVE WALLPAPER', style: WrF.mono(color: WrC.blossom2)),
                    const SizedBox(height: 6),
                    Text('내 소원방을 그대로,\n매일 보이는 곳에', style: WrF.display(18, height: 1.35)),
                    const SizedBox(height: 8),
                    Text('버튼도 광고도 없이, 소원방만 보여요. 촛불이 흔들리고 꽃잎이 내려요.',
                        style: WrF.body(12.5, color: WrC.muted, height: 1.65)),
                    const SizedBox(height: 10),
                    if (room != null)
                      Wrap(spacing: 5, runSpacing: 5, children: [
                        _chip('Lv.${room.level}'),
                        if (fulfilled) _chip('이루어짐'),
                      ]),
                  ]))),
                ]),
                const SizedBox(height: 16),

                // ── 설정 상태 카드 ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: WrDeco.card,
                  child: Row(children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSet ? const Color(0xFF7BE0A8) : Colors.white.withValues(alpha: .25),
                      boxShadow: isSet ? const [BoxShadow(color: Color(0xFF7BE0A8), blurRadius: 10)] : null,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        isSet
                            ? (st.platform == 'ios' ? 'Live Photo 로 저장됨' : '배경화면으로 설정됨 · ${_targetLabel(st.target)}')
                            : '아직 배경화면이 아니에요',
                        style: WrF.body(13, w: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSet
                            ? (st.needsUpdate ? '소원방이 자랐어요 · v${st.version} → v${st.latestVersion}'
                                : st.autoSynced ? '소원방이 바뀌면 자동으로 따라 바뀌어요' : 'v${st.version} · 최신 모습이에요')
                            : '소원방이 자랄 때마다 배경화면도 함께 자라요',
                        style: WrF.body(10.5, color: WrC.muted),
                      ),
                    ])),
                    if (isSet && st.needsUpdate) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: WrC.blossom, borderRadius: BorderRadius.circular(999)),
                      child: const Text('N', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── 주 버튼 ──
                if (!_kIosFlow) ...[
                  SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                    onPressed: room == null ? null : () => _applyAndroid(p, room, 'BOTH'),
                    style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text(isSet ? '다시 설정하기' : '홈 화면 + 잠금 화면에 설정', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  )),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: SizedBox(height: 40, child: OutlinedButton(
                      onPressed: room == null ? null : () => _applyAndroid(p, room, 'HOME'),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: WrC.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('홈 화면에만', style: WrF.body(13.5, color: WrC.fg, w: FontWeight.w700)),
                    ))),
                    const SizedBox(width: 8),
                    Expanded(child: SizedBox(height: 40, child: OutlinedButton(
                      onPressed: room == null ? null : () => _applyAndroid(p, room, 'LOCK'),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: WrC.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('잠금 화면에만', style: WrF.body(13.5, color: WrC.fg, w: FontWeight.w700)),
                    ))),
                  ]),
                ] else ...[
                  SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                    onPressed: room == null ? null : () => _makeIOS(p, room),
                    style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text(isSet && st.needsUpdate ? '새 모습으로 Live Photo 다시 만들기' : 'Live Photo 만들어 저장',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  )),
                  const SizedBox(height: 8),
                  Text('잠금 화면에서 깨울 때마다 소원방이 움직여요', textAlign: TextAlign.center, style: WrF.body(12, color: WrC.muted, height: 1.6)),
                ],
                if (isSet && st.platform == 'android')
                  Padding(padding: const EdgeInsets.only(top: 10), child: Center(child: GestureDetector(
                    onTap: () => setState(() => _done = (kind: 'android', target: st.target, thumb: null)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: WrDeco.chip,
                      child: Text('적용된 모습 다시 보기', style: WrF.body(12, color: WrC.fg)),
                    ),
                  ))),

                // ── S-06 보존된 소원방 ──
                const SizedBox(height: 22),
                Text('보존된 소원방', style: WrF.display(14)),
                const SizedBox(height: 4),
                Text('이루어진 소원방도 배경화면으로 둘 수 있어요', style: WrF.body(12, color: WrC.muted)),
                const SizedBox(height: 10),
                if (p.room != null)
                  _WPRoomRow(room: p.room!, items: p.items, on: _roomId == p.room!.id, set: isSet && st.roomId == p.room!.id,
                      onTap: () => setState(() => _roomId = p.room!.id), label: '지금 밝히는 소원방'),
                ...p.archiveRooms.map((r) => Padding(padding: const EdgeInsets.only(top: 8), child: _WPRoomRow(
                    room: r, items: p.items, on: _roomId == r.id, set: isSet && st.roomId == r.id,
                    onTap: () => setState(() => _roomId = r.id), label: '이루어진 소원방'))),
                if (p.archiveRooms.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: WrC.line, style: BorderStyle.solid)),
                  alignment: Alignment.center,
                  child: Text('소원이 이루어지면 이곳에 머물러요', style: WrF.body(12, color: WrC.muted)),
                )),
              ])),
            ]),
            ),
            if (_full && room != null)
              WPFullPreview(room: room, items: p.items, onClose: () => setState(() => _full = false)),
            if (_mk != null)
              WPMaking(state: _mk!, onCancel: () { _mk!.cancelled = true; setState(() => _mk = null); }),
            if (_done != null && _done!.kind == 'ios' && room != null)
              WPIosDone(thumb: _done!.thumb, room: room, items: p.items, onClose: () => setState(() => _done = null)),
            if (_done != null && _done!.kind == 'android' && room != null)
              WPApplied(room: room, items: p.items, target: _done!.target, onClose: () => setState(() => _done = null)),
          ]);
        }),
      ),
    );
  }

  Widget _chip(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: WrDeco.chip,
      child: Text(t, style: WrF.body(10.5, color: WrC.fg)));

  String _targetLabel(String? t) => switch (t) { 'BOTH' => '홈 + 잠금', 'HOME' => '홈 화면', 'LOCK' => '잠금 화면', _ => '' };
}

/// S-04 Live Photo 진행 상태 — WallpaperScreen과 WPMaking이 함께 참조하므로
/// (library_private_types_in_public_api 방지) 비공개 접두사 없이 노출한다.
class MakingState {
  int stage = 0;
  int p = 0;
  Uint8List? thumb;
  bool cancelled = false;
}

class _WPRoomRow extends StatelessWidget {
  const _WPRoomRow({required this.room, required this.items, required this.on, required this.set, required this.onTap, required this.label});
  final WishRoom room; final List<WrItem> items; final bool on, set; final VoidCallback onTap; final String label;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), color: WrC.card,
          border: Border.all(color: on ? WrC.blossom2 : WrC.cardBorder),
          boxShadow: on ? const [BoxShadow(color: Color(0x40F2628F), blurRadius: 18)] : null,
        ),
        child: Row(children: [
          Container(
            width: 46, height: 72, clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: WrC.bg1),
            // G-4 RoomThumb — [버그수정 — 전수감사] items:const[] 고정으로 장식이 전혀 반영되지 않던 버그.
            // [버그수정 — 전수감사] app2/wallpaper2.jsx › WPRoomRow(): `<RoomThumb ... focus={.45}
            // zoom={1}/>` — 세로가 긴 46×72 썸네일 전용 비율(focus:.22,zoom:1.5는 다른
            // 가로형 카드 값)과 불일치했다. ARCHIVED(완성)는 `{...r,...s,brightness:1}`도 반영.
            child: Stack(children: [
              Positioned.fill(child: RoomThumb(room: room, items: items, w: 46, h: 72, focus: .45, zoom: 1,
                brightnessOverride: room.status == RoomStatus.ARCHIVED ? 1 : null)),
              if (room.status == RoomStatus.ARCHIVED) const Positioned(right: 2, bottom: 2, child: _MiniSeal()),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$label · Lv.${room.level}', style: WrF.body(10.5, w: FontWeight.w700, color: room.status == RoomStatus.ARCHIVED ? WrC.glow : WrC.blossom2)),
            const SizedBox(height: 3),
            Text(room.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: WrF.body(13, w: FontWeight.w700)),
            if (room.status == RoomStatus.ARCHIVED && room.completedAt != null)
              Text('${_fmt(room.completedAt!)} 이루어짐', style: WrF.body(10.5, color: WrC.muted)),
          ])),
          if (set) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF7BE0A8))),
            child: const Text('사용 중', style: TextStyle(fontSize: 10, color: Color(0xFFAEF0C8))),
          )
          else Padding(padding: const EdgeInsets.only(right: 6), child: Text(on ? '◉' : '○', style: TextStyle(color: on ? WrC.blossom2 : WrC.muted, fontSize: 16))),
        ]),
      ),
    );
  }

  String _fmt(DateTime t) => '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
}

class _MiniSeal extends StatelessWidget {
  const _MiniSeal();
  @override
  Widget build(BuildContext context) => Container(
      width: 16, height: 16, alignment: Alignment.center,
      decoration: const BoxDecoration(color: WrC.accent, shape: BoxShape.circle),
      child: const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 9, color: Color(0xFFFFF9E8))));
}

// ─────────────────── S-03 전체 미리보기(정지 프레임 · 안전영역) ───────────────────
class WPFullPreview extends StatefulWidget {
  const WPFullPreview({super.key, required this.room, required this.items, required this.onClose});
  final WishRoom room; final List<WrItem> items; final VoidCallback onClose;
  @override
  State<WPFullPreview> createState() => _WPFullPreviewState();
}

class _WPFullPreviewState extends State<WPFullPreview> {
  bool _safe = true;
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
      WrCanvasScaler(child: RoomScene(room: widget.room, items: widget.items, frozen: true)),
      if (_safe) ...[
        Positioned(left: 0, right: 0, top: 0, height: 0.14 * MediaQuery.of(context).size.height, child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xE6A0DCFF), width: 1.5)),
            color: Color(0x3878C8FF),
          ),
          alignment: Alignment.bottomRight,
          padding: const EdgeInsets.only(right: 12, bottom: 6),
          child: const Text('SAFE TOP · 14% · 시계', style: TextStyle(fontFamily: 'IBMPlexMonoWish', fontSize: 9, color: Color(0xFFCDEEFF))),
        )),
        Positioned(left: 0, right: 0, bottom: 0, height: 0.08 * MediaQuery.of(context).size.height, child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xE6A0DCFF), width: 1.5)),
            color: Color(0x3878C8FF),
          ),
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 12, top: 6),
          child: const Text('SAFE BOTTOM · 8% · 독', style: TextStyle(fontFamily: 'IBMPlexMonoWish', fontSize: 9, color: Color(0xFFCDEEFF))),
        )),
      ],
      Positioned(left: 14, right: 14, bottom: MediaQuery.of(context).size.height * .1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(onTap: () => setState(() => _safe = !_safe), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: WrDeco.chip,
          child: Text(_safe ? '안전영역 숨기기' : '안전영역 보기', style: WrF.body(12.5, w: FontWeight.w700)),
        )),
        const SizedBox(width: 8),
        GestureDetector(onTap: widget.onClose, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: WrDeco.chip,
          child: Text('✕ 닫기', style: WrF.body(12.5, w: FontWeight.w700)),
        )),
      ])),
    ]));
  }
}

// ─────────────────── S-04 Live Photo 생성 진행(iOS) ───────────────────
class WPMaking extends StatelessWidget {
  const WPMaking({super.key, required this.state, required this.onCancel});
  final MakingState state; final VoidCallback onCancel;
  static const _labels = ['소원방을 그리는 중', '움직임을 담는 중', '사진에 저장하는 중'];
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GestureDetector(onTap: () {}, child: Container(color: const Color(0x99000000))),
      Center(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: WrDeco.sheet,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96, height: 96 * 19.5 / 9, clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF1A0A14),
                border: Border.all(color: const Color(0xFF3A2C38), width: 3)),
            child: state.thumb != null ? Image.memory(state.thumb!, fit: BoxFit.cover)
                : const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(colors: [Color(0x59FFD28C), Colors.transparent]))),
          ),
          const SizedBox(height: 14),
          Text('LIVE PHOTO · ${(state.stage + 1).toString().padLeft(2, '0')} / 03', style: WrF.mono(color: WrC.blossom2)),
          const SizedBox(height: 6),
          Text(_labels[state.stage], style: WrF.display(18)),
          const SizedBox(height: 14),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
              value: state.p / 100, minHeight: 8, backgroundColor: const Color(0x14FFFFFF),
              valueColor: const AlwaysStoppedAnimation(WrC.glow))),
          const SizedBox(height: 8),
          Text('${state.p}%', style: WrF.display(14, color: WrC.glow)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onCancel, style: OutlinedButton.styleFrom(side: BorderSide(color: WrC.line)), child: const Text('그만두기')),
        ]),
      )),
    ]);
  }
}

// ─────────────────── S-05 저장 완료 · 설정 안내(iOS) ───────────────────
class WPIosDone extends StatelessWidget {
  const WPIosDone({super.key, required this.thumb, required this.room, required this.items, required this.onClose});
  final Uint8List? thumb; final WishRoom room; final List<WrItem> items; final VoidCallback onClose;
  static const _steps = [
    ('설정 앱', '배경화면 → 새로운 배경화면 추가'),
    ('사진', 'Live Photo 선택'),
    ('소원방', '방금 저장된 소원방 선택'),
    ('재생 버튼', '켜두면 깨울 때마다 움직여요'),
    ('추가', '배경화면 세트로 설정'),
  ];
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GestureDetector(onTap: onClose, child: Container(color: const Color(0x99000000))),
      Align(alignment: Alignment.bottomCenter, child: Container(
        margin: const EdgeInsets.all(10), padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: WrDeco.sheet,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 64, height: 64 * 19.5 / 9, clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF3A2C38), width: 2)),
              child: thumb != null ? Image.memory(thumb!, fit: BoxFit.cover) : const ColoredBox(color: Color(0xFF1A0A14)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SAVED · 사진 앱', style: WrF.mono(color: WrC.blossom2)),
              const SizedBox(height: 4),
              Text('소원방을\n사진에 담았어요', style: WrF.display(19, height: 1.35)),
            ])),
          ]),
          const SizedBox(height: 12),
          Text('iPhone 은 배경화면을 직접 바꿀 수 없어서, 아래 순서로 한 번만 설정해 주세요.',
              style: WrF.body(12.5, color: WrC.muted, height: 1.6)),
          const SizedBox(height: 10),
          ...List.generate(_steps.length, (i) {
            final (a, b) = _steps[i];
            return Padding(padding: const EdgeInsets.only(bottom: 6), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: WrC.card,
                  border: Border.all(color: i == 3 ? const Color(0x80F5CF6A) : WrC.cardBorder)),
              child: Row(children: [
                Container(width: 22, height: 22, alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i == 3 ? WrC.glow : const Color(0x40F2628F)),
                  child: Text('${i + 1}', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 11, color: i == 3 ? const Color(0xFF2A1A14) : Colors.white))),
                const SizedBox(width: 10),
                Expanded(child: Text.rich(TextSpan(children: [
                  TextSpan(text: a, style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' · $b'),
                ]), style: WrF.body(12, height: 1.45))),
              ]),
            ));
          }),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => showDialog(context: context, barrierColor: Colors.transparent, builder: (_) => WPApplied(room: room, items: items, target: 'LOCK', ios: true, onClose: () => Navigator.of(context).pop())),
              style: OutlinedButton.styleFrom(side: BorderSide(color: WrC.line)), child: const Text('잠금 화면 보기'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
              child: const Text('확인', style: TextStyle(color: Colors.white)))),
          ]),
        ]),
      )),
    ]);
  }
}

// ─────────────────── 적용 시뮬레이션 — 잠금 화면 ↔ 홈 화면 ───────────────────
// [방침] Android: syncManifest()로 네이티브가 이미 실제 OS 배경화면을 그리고 있으므로,
// 여기서는 "설정이 잘 적용됐는지" 사용자에게 보여주는 확인 연출이다(실동작은 네이티브).
// iOS: 네이티브 빌드 기반이 없어 이 오버레이 자체가 곧 전체 시뮬레이션이다.
class WPApplied extends StatefulWidget {
  const WPApplied({super.key, required this.room, required this.items, required this.target, this.ios = false, required this.onClose});
  final WishRoom room; final List<WrItem> items; final String? target; final bool ios; final VoidCallback onClose;
  @override
  State<WPApplied> createState() => _WPAppliedState();
}

class _WPAppliedState extends State<WPApplied> {
  late String _scene = widget.target == 'HOME' ? 'home' : 'lock';
  late DateTime _clock = DateTime.now();
  Timer? _clockTimer;
  bool _playing = true;
  Timer? _playTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) { if (mounted) setState(() => _clock = DateTime.now()); });
    if (widget.ios) _armPlay();
  }

  void _armPlay() {
    setState(() => _playing = true);
    _playTimer?.cancel();
    _playTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _playing = false); });
  }

  @override
  void dispose() { _clockTimer?.cancel(); _playTimer?.cancel(); super.dispose(); }

  static const _apps = ['메시지', '사진', '카메라', '날씨', '캘린더', '지도', '음악', '메모'];

  @override
  Widget build(BuildContext context) {
    final showWp = _scene == 'lock' ? widget.target != 'HOME' : widget.target != 'LOCK';
    final hh = _clock.hour, mm = _clock.minute.toString().padLeft(2, '0');
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return Material(color: Colors.black, child: GestureDetector(
      onTap: () { if (widget.ios && _scene == 'lock') _armPlay(); },
      child: Stack(fit: StackFit.expand, children: [
        if (showWp)
          (widget.ios && !_playing)
              ? WrCanvasScaler(child: RoomScene(room: widget.room, items: widget.items, frozen: true))
              : WrCanvasScaler(child: RoomScene(room: widget.room, items: widget.items))
        else
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF223344), Color(0xFF111122)]))),
        if (_scene == 'lock') IgnorePointer(child: Stack(children: [
          Positioned(top: 64, left: 0, right: 0, child: Column(children: [
            Text('${_clock.month}월 ${_clock.day}일 ${days[_clock.weekday % 7]}요일', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            Text('$hh:$mm', style: const TextStyle(color: Colors.white, fontSize: 84, height: 1, fontWeight: FontWeight.w700)),
          ])),
          if (widget.ios) Positioned(top: 210, left: 0, right: 0, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: WrDeco.chip,
            child: Text(_playing ? '◉ LIVE · 재생 중' : '화면을 눌러 다시 깨우기', style: const TextStyle(fontSize: 11, color: Colors.white)))),
          ),
        ])) else IgnorePointer(child: Padding(padding: const EdgeInsets.only(top: 70, left: 22, right: 22), child: Wrap(
          spacing: 8, runSpacing: 18,
          children: _apps.map((a) => SizedBox(width: 58, child: Column(children: [
            Container(width: 58, height: 58, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: Colors.white.withValues(alpha: .16))),
            const SizedBox(height: 5),
            Text(a, style: const TextStyle(fontSize: 11, color: Colors.white)),
          ]))).toList(),
        ))),
        Positioned(left: 0, right: 0, bottom: _scene == 'lock' ? 110 : 128, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!widget.ios && widget.target == 'BOTH') Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
            onTap: () => setState(() => _scene = _scene == 'lock' ? 'home' : 'lock'),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: WrDeco.chip,
              child: Text(_scene == 'lock' ? '↑ 홈 화면 보기' : '↓ 잠금 화면 보기', style: WrF.body(12.5, w: FontWeight.w700))))),
          GestureDetector(onTap: widget.onClose, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: WrDeco.chip,
            child: Text('소원방으로', style: WrF.body(12.5, w: FontWeight.w700)))),
        ])),
        Positioned(top: 58, right: 14, child: Text(widget.ios ? 'SIMULATION · iOS' : 'SIMULATION · ANDROID', style: WrF.mono(color: Colors.white54))),
      ]),
    ));
  }
}

// ─────────────────── S-01 진입 카드(RoomMenu · 소원방 돌보기 시트) ───────────────────
class WPEntryCard extends StatelessWidget {
  const WPEntryCard({super.key, required this.room});
  final WishRoom room;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<WishRoomProvider>();
    final st = p.wallpaperStatus;
    final set = st.isSet && st.roomId == room.id;
    final hot = room.level >= 3 && !set;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WallpaperScreen())),
      child: Container(
        width: double.infinity, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), color: WrC.card,
          border: Border.all(color: hot ? const Color(0x8CF5CF6A) : WrC.cardBorder),
          boxShadow: hot ? const [BoxShadow(color: Color(0x2EF5CF6A), blurRadius: 20)] : null,
        ),
        child: Row(children: [
          Container(
            width: 34, height: 60, clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF3A2C38), width: 2)),
            // G-4 RoomThumb — [버그수정 — 전수감사] items:const[] 고정으로 장식이 전혀 반영되지 않던 버그.
            // [버그수정 — 전수감사] app2/wallpaper2.jsx › WPEntryCard(): `<RoomThumb ... focus={.45}
            // zoom={1}/>` — 세로형 34×60 썸네일에 다른 카드의 focus/zoom 값이 섞여 있었다.
            child: RoomThumb(room: room, items: p.items, w: 34, h: 60, focus: .45, zoom: 1),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('배경화면으로 설정', style: WrF.body(13.5, w: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(set ? '설정됨 · 소원방과 함께 자라요' : hot ? '지금 소원방이 가장 예쁠 때예요' : '앱을 열지 않아도 매일 보여요',
                style: WrF.body(11, color: WrC.muted)),
          ])),
          if (set) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF7BE0A8))),
            child: const Text('설정됨', style: TextStyle(fontSize: 10, color: Color(0xFFAEF0C8))),
          )
          else Text('›', style: TextStyle(color: WrC.blossom2, fontSize: 15)),
        ]),
      ),
    );
  }
}
