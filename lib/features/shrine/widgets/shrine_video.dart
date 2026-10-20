// 영상 레이어 — 웹 프로토타입에서 실제로 겪은 버그를 Flutter에 맞게 옮긴 규칙
//  1) 반드시 무음(setVolume(0))으로 시작 → 웹(Flutter Web)에서도 자동재생 허용
//  2) 1회 재생 영상은 끝난 뒤 다시 재생하지 않는다
//  3) 안전 타이머 6.8s: 영상이 끝내 재생되지 않아도 onEnd 를 호출해 흐름을 멈추지 않는다
//  4) 초기화 실패 시 포스터 이미지로 대체
//  5) 다음 화면 영상은 precache(아래 ShrineVideoCache)로 미리 initialize
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/tokens.dart';

class ShrineVideo extends StatefulWidget {
  final String name;          // assets/shrine/vid/{name}.mp4
  final String poster;        // assets/shrine/img/{poster}.jpg
  final bool loop;
  final VoidCallback? onEnd;
  final ValueChanged<double>? onProgress; // 0~1 (부적 태우기 마스크 동기화용)
  final BoxFit fit;
  const ShrineVideo({super.key, required this.name, required this.poster, this.loop = true, this.onEnd, this.onProgress, this.fit = BoxFit.cover});
  @override
  State<ShrineVideo> createState() => _ShrineVideoState();
}

class _ShrineVideoState extends State<ShrineVideo> {
  VideoPlayerController? _c;
  bool _failed = false, _ended = false;
  Timer? _safety;

  @override
  void initState() {
    super.initState();
    _c = ShrineVideoCache.take(widget.name) ?? VideoPlayerController.asset('assets/shrine/vid/${widget.name}.mp4');
    _init();
    if (!widget.loop && widget.onEnd != null) _safety = Timer(Dur.videoSafety, _finish);
  }

  Future<void> _init() async {
    try {
      final c = _c!;
      if (!c.value.isInitialized) await c.initialize();
      await c.setVolume(0);
      await c.setLooping(widget.loop);
      c.addListener(_tick);
      await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      if (widget.onEnd != null) Future.delayed(const Duration(milliseconds: 800), _finish);
    }
  }

  void _tick() {
    final v = _c!.value;
    if (!v.isInitialized || v.duration == Duration.zero) return;
    widget.onProgress?.call(v.position.inMilliseconds / v.duration.inMilliseconds);
    if (!widget.loop && !_ended && v.position >= v.duration - const Duration(milliseconds: 60)) _finish();
  }

  void _finish() {
    if (_ended) return;
    _ended = true; // 2) 재시도 금지
    _safety?.cancel();
    widget.onEnd?.call();
  }

  @override
  void dispose() {
    _safety?.cancel();
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = Image.asset('assets/shrine/img/${widget.poster}.jpg', fit: widget.fit, width: double.infinity, height: double.infinity);
    final c = _c;
    if (_failed || c == null || !c.value.isInitialized) return poster;
    return Stack(fit: StackFit.expand, children: [
      poster,
      // [신당 전체 화면 입력 차단 결함수정] Flutter Web에서 VideoPlayer는
      // 실제 DOM <video> 엘리먼트(PlatformView)로 렌더링되는데, 기본적으로
      // pointer-events: auto라 화면 전체를 덮은 채 그 위에 캔버스로 그려지는
      // 모든 버튼(예: EntryScreen "지금 신당으로 들어가기")의 탭을 가로채
      // 버린다. 이 영상은 순수 배경 장식용이므로 IgnorePointer로 감싸
      // 입력을 완전히 투과시킨다 — 모든 ShrineVideo 사용처(entry/door/talk/
      // write/burn/hall 등 18개 화면 전체)에 공통 적용되는 근본 수정.
      IgnorePointer(
        child: FittedBox(fit: widget.fit, clipBehavior: Clip.hardEdge,
          child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))),
      ),
    ]);
  }
}

/// 다음 화면 영상 미리 받기 (웹의 <link rel=preload as=video> 대응)
class ShrineVideoCache {
  static final _m = <String, VideoPlayerController>{};
  static Future<void> precache(List<String> names) async {
    for (final n in names) {
      if (_m.containsKey(n)) continue;
      final c = VideoPlayerController.asset('assets/shrine/vid/$n.mp4');
      _m[n] = c;
      unawaited(c.initialize().catchError((_) {}));
    }
  }
  static VideoPlayerController? take(String n) => _m.remove(n);
}
