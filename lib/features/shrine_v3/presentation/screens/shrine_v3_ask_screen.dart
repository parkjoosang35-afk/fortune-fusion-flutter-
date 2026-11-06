import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/shrine_order.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/shrine_asset_path.dart';
import '../widgets/unique_talisman_overlay.dart';
import 'shrine_v3_result_screen.dart';

/// 신당(THE SHRINE) v3 — 07 부탁 연출.
///
/// README/HTML 프로토타입 `Ask` 컴포넌트와 동일한 6단계 상태 전이(0 듣기→
/// 1 쓰기→2 다씀(탭 대기)→3 태우기→4 받기→5 완료)를 Timer 기반으로
/// 재현한다. 이 화면은 결제가 이미 끝난 뒤(05에서 결제 게이트 통과 +
/// [ShrineV3Provider.createOrder] 성공)에만 진입하므로, 여기서는 서버
/// 호출을 전혀 하지 않고 이미 발급된 [order]를 그대로 표시만 한다.
class ShrineV3AskScreen extends StatefulWidget {
  const ShrineV3AskScreen({super.key, required this.order});
  final ShrineOrder order;

  @override
  State<ShrineV3AskScreen> createState() => _ShrineV3AskScreenState();
}

class _ShrineV3AskScreenState extends State<ShrineV3AskScreen> {
  int _p = 0; // 0 듣기, 1 쓰기, 2 탭 대기, 3 태우기, 4 받기, 5 완료
  double _burn = 0;
  final List<Timer> _timers = [];
  Timer? _burnTimer;
  VideoPlayerController? _video;
  String _vidName = 'write';

  static const _say = [
    '서연님의 소망, 잘 들었습니다.',
    '한 획 한 획, 소망을 옮겨 적습니다.',
    '다 썼습니다. 부적을 눌러 하늘에 올려 보내십시오.',
    '불길이 소망을 하늘로 데려갑니다.',
    '태운 것은 끝이 아닙니다. 서연님 몫으로 한 장 더 옮겨 적었습니다.',
    '받으십시오. 세상에 한 장뿐인 부적입니다.',
  ];
  static const _lab = ['듣기', '쓰기', '태우기', '받기'];

  @override
  void initState() {
    super.initState();
    _loadVideo('write');
    _timers.add(Timer(const Duration(milliseconds: 1400), () => _setPhase(1)));
  }

  int get _step => _p == 0 ? 0 : (_p <= 2 ? 1 : (_p == 3 ? 2 : 3));

  Future<void> _loadVideo(String name) async {
    final old = _video;
    final controller = VideoPlayerController.asset(shrineSceneVideo(name));
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      await controller.setLooping(name != 'give');
      await controller.play();
      setState(() {
        _video = controller;
        _vidName = name;
      });
    } catch (_) {
      // 영상 로드 실패해도 연출 자체는 계속 진행(정적 배경으로 대체).
      if (mounted) setState(() => _vidName = name);
    }
    await old?.dispose();
  }

  void _setPhase(int p) {
    if (!mounted) return;
    setState(() => _p = p);
    if (p == 1) {
      _loadVideo('write');
      _timers.add(
        Timer(const Duration(milliseconds: 5200), () => _setPhase(2)),
      );
    } else if (p == 3) {
      _loadVideo('burn');
      _burn = 0;
      _burnTimer = Timer.periodic(const Duration(milliseconds: 60), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _burn = (_burn + 0.018).clamp(0, 1));
        if (_burn >= 1) {
          t.cancel();
          _timers.add(
            Timer(const Duration(milliseconds: 900), () => _setPhase(4)),
          );
        }
      });
    } else if (p == 4) {
      _loadVideo('give');
      _timers.add(
        Timer(const Duration(milliseconds: 4200), () => _setPhase(5)),
      );
    }
  }

  void _onTap() {
    if (_p == 2) _setPhase(3);
  }

  void _skip() {
    for (final t in _timers) {
      t.cancel();
    }
    _burnTimer?.cancel();
    _setPhase(5);
  }

  void _goResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ShrineV3ResultScreen(order: widget.order),
      ),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _burnTimer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.order.talisman;
    return Scaffold(
      backgroundColor: ShrineV3Colors.ink,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_video != null && _video!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _video!.value.size.width,
                  height: _video!.value.size.height,
                  child: VideoPlayer(_video!),
                ),
              )
            else
              Image.asset(
                shrineSceneImage(_vidName == 'burn' ? 'paper' : _vidName),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: ShrineV3Colors.ink),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
            // 쓰기/다씀/태우기(p 1~3) 구간 — 프로토타입 `GenImg`처럼 실제 부적
            // 원본 이미지를 그대로 보여준다(§기존 버그: 색상 박스 + 이름
            // 텍스트 placeholder만 뜨던 것을 수정 — 이미지 로드 실패 시에만
            // 한자 placeholder로 대체).
            if (_p >= 1 && _p <= 3)
              Center(
                child: Opacity(
                  opacity: _p == 3 ? (1 - _burn).clamp(0.0, 1.0) : 1,
                  child: Container(
                    width: 140,
                    height: 322,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        shrineAssetPath(
                          (t.thumbPath != null && t.thumbPath!.isNotEmpty)
                              ? t.thumbPath!
                              : t.imagePath,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: ShrineV3Colors.paper,
                          alignment: Alignment.center,
                          child: Text(
                            t.hanja,
                            style: ShrineV3TextStyles.title.copyWith(
                              fontSize: 40,
                              color: ShrineV3Colors.seal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_p == 2)
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(top: 200),
                  child: Text(
                    '부적을 눌러 태우기',
                    style: ShrineV3TextStyles.ui.copyWith(
                      color: ShrineV3Colors.paper,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            // [사용자 버그 리포트 — 디자인 핸드오프 불일치 #4] "부적 받기
            // 버튼 위치가 이상하게 바뀌었어요" — 원인은 부적 자체가 HTML
            // `.recv3`(top:150px, 화면 상단 고정)와 달리 `Center`로 화면
            // 수직 중앙에 떠 있었기 때문(그 아래 캡션/스테퍼/버튼까지 전부
            // 밀려 보임). `top: 150`에 가깝게 비율로 고정하고, HTML
            // `.seal3`(부적 우측하단에 겹치는 44×44px, -8deg 회전, 글자
            // 1자 배지 — 재물부 계열이면 '財')도 추가로 재현한다.
            if (_p >= 4)
              Positioned(
                top: 150,
                left: 0,
                right: 0,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UniqueTalismanOverlay(
                        order: widget.order,
                        width: 110,
                        useThumb: true,
                      ),
                      Positioned(
                        right: -16,
                        bottom: -12,
                        child: Transform.rotate(
                          angle: -8 * 3.1415926535 / 180,
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ShrineV3Colors.seal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t.hanja.isNotEmpty ? t.hanja.characters.first : '符',
                              style: ShrineV3TextStyles.title.copyWith(
                                color: const Color(0xFFFFF8EC),
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '민세레나',
                      style: ShrineV3TextStyles.ui.copyWith(
                        color: ShrineV3Colors.gold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _say[_p],
                      style: ShrineV3TextStyles.body.copyWith(
                        color: ShrineV3Colors.paper,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(_lab.length, (i) {
                        final on = _step >= i;
                        return Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 3,
                                color: on
                                    ? ShrineV3Colors.gold
                                    : Colors.white24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _lab[i],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: on
                                      ? ShrineV3Colors.gold
                                      : Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    if (_p == 5) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _goResult,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ShrineV3Colors.seal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('부적 받기 ›'),
                        ),
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _skip,
                          child: const Text(
                            '건너뛰기',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
