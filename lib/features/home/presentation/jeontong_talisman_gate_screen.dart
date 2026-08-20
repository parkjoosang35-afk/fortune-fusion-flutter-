// ============================================================
// [부적게이트 · TalismanGate] — "운세" 섹션 진입 게이트 화면
//
// 원본: 사용자 업로드 `부적게이트_핸드오프.zip`(React `TalismanGate.jsx`,
// 573줄 + README.md 169줄)을 Flutter/Dart로 포팅. "운세(사주) 화면 진입
// 직전에 표시되는 인터랙티브 게이트 — 부적을 탭하면 축복 문구가 뜨는
// 애니메이션"이라는 원본 목적 그대로: 홈/전체보기/운세허브의 "운세"
// 진입점을 탭한 "직후", 정통사주 69종 목록([JeontongEightyMatrix.
// browseRoute] → [JeontongEightyScreen])을 보여주기 "직전"에만 표시된다.
//
// [원상복구 - 중요] 카테고리를 이미 선택한 뒤의 결과 계산 로딩
// ([JeontongEightyLoadingScreen], 8초, 만세력 계산)과는 완전히 별개의
// 위치다. 이 게이트는 categoryId를 전혀 알지 못하며(아직 사용자가
// 카테고리를 고르기 전 시점), 종료 후에는 항상 목록 화면
// ([JeontongEightyMatrix.browseRoute])으로만 이동한다. 결과 화면
// ([resultRoute])으로 직접 이동하지 않는다.
//
// [사용자 확정 답변 반영]
// Q1: (원안 폐기) 만세력 로딩(8초)과는 순서상 무관 — 이 게이트는 그보다
//     앞선 "운세 진입" 시점 1회에만 등장한다. 첫 노출 3초/세션 재진입
//     1.5초.
// Q2: 세션(30분) 내 재진입 시 단축 — [JeontongGateSession] 참고.
// Q3: 축복 문구 12종은 §9 정책에 맞춰 재작성된
//     [kJeontongGateBlessings]를 그대로 사용(범용 문구 없음).
// Q4: SKIP 버튼 없음(showSkip=false 상당) — 대신 탭 1회당 남은 시간을
//     [JeontongGateSession.tapAccelerationMs](300ms)만큼 앞당긴다.
//
// [디자인 격리] README 시각 스펙(먹색 배경/홍색 부적/금색 글로우)을 그대로
// 재현하되, 팔레트는 이 화면 전용 [_GatePalette]로 완전히 격리한다 —
// 앱 전역 UnifiedColors/HanjiColors는 건드리지 않는다(§ naming collision
// 회피 원칙과 동일한 이유). 폰트는 신규 의존성을 추가하지 않고 이미
// pubspec.yaml에 있는 google_fonts(notoSansKr/ibmPlexMono)를 재사용한다
// (README가 지정한 Noto Serif KR + IBM Plex Mono와 동일 계열 — notoSansKr는
// 이미 이 프로젝트의 HanjiTextStyles가 한자 인장을 렌더링하는 데 검증된
// 폰트다).
//
// [미구현 명시 - README 원본과 동일하게 이관] prefers-reduced-motion 대응,
// 스크린리더 라벨(Semantics), 키보드 접근은 원본 README에도 "향후 과제"로
// 명시되어 있고, 이 포팅에서도 동일하게 범위 밖으로 둔다.
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/jeontong_eighty_matrix.dart';
import '../domain/jeontong_gate_session.dart';

/// 부적게이트 전용 격리 팔레트 — README 시각 스펙 그대로.
class _GatePalette {
  _GatePalette._();

  // 배경 (먹색)
  static const Color bgOuter = Color(0xFF2A1B2E);
  static const Color bgMid = Color(0xFF14091A);
  static const Color bgInner = Color(0xFF08040E);

  // 부적 (홍색)
  static const Color talismanTop = Color(0xFFD0271F);
  static const Color talismanMid = Color(0xFFB01818);
  static const Color talismanBottom = Color(0xFF8E1010);

  // 글로우/텍스트 (금색)
  static const Color goldDeep = Color(0xFFD4A24C);
  static const Color gold = Color(0xFFE8C368);
  static const Color goldPale = Color(0xFFF5E6B8);
}

/// 팔괘(八卦) — 카운트다운 진행률에 비례해 회전하는 배경 한자.
const List<String> _kBaguaGlyphs = ['乾', '兌', '離', '震', '巽', '坎', '艮', '坤'];

class JeontongTalismanGateScreen extends StatefulWidget {
  const JeontongTalismanGateScreen({super.key});

  @override
  State<JeontongTalismanGateScreen> createState() =>
      _JeontongTalismanGateScreenState();
}

class _JeontongTalismanGateScreenState extends State<JeontongTalismanGateScreen>
    with TickerProviderStateMixin {
  static const _tickInterval = Duration(milliseconds: 50);
  static const Size _talismanSize = Size(220, 300);

  late final AnimationController _baguaCtrl;
  late final math.Random _random;

  int _totalMs = JeontongGateSession.firstShowDurationMs;
  int _remainingMs = JeontongGateSession.firstShowDurationMs;
  Timer? _countdownTimer;

  int _tapCount = 0;
  String? _currentBlessing;
  Timer? _blessingTimer;
  final List<String> _recentBlessings = [];

  double _tiltX = 0; // -1..1
  double _tiltY = 0; // -1..1

  final List<_ParticleBurst> _bursts = [];

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _totalMs = JeontongGateSession.markShownAndGetDurationMs();
    _remainingMs = _totalMs;

    // 팔괘 회전 배경 — 장식용 연속 회전(카운트다운과 별개, 가볍게 반복).
    _baguaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _countdownTimer = Timer.periodic(_tickInterval, _onTick);
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    setState(() {
      _remainingMs -= _tickInterval.inMilliseconds;
      if (_remainingMs <= 0) {
        _remainingMs = 0;
        _finish();
      }
    });
  }

  void _onTapTalisman(TapUpDetails details, Size localSize) {
    if (_navigated) return;
    _tapCount += 1;

    // [Q4] SKIP 대신 탭 가속 — 남은 시간을 앞당긴다(0 밑으로는 내려가지
    // 않게 clamp, 이번 tick에서 바로 종료되지 않도록 최소 1틱은 남긴다).
    setState(() {
      _remainingMs = (_remainingMs - JeontongGateSession.tapAccelerationMs)
          .clamp(_tickInterval.inMilliseconds, _totalMs);
    });

    final blessing = _pickBlessing();
    _showBlessing(blessing);
    _spawnBurst(details.localPosition, localSize);
  }

  String _pickBlessing() {
    // 원본 pickBlessing() — 최근 노출된 문구는 가능하면 피해 반복 체감을
    // 줄인다(문구 전체를 다 썼으면 초기화).
    final pool = kJeontongGateBlessings
        .where((b) => !_recentBlessings.contains(b))
        .toList();
    final source = pool.isNotEmpty ? pool : kJeontongGateBlessings;
    final picked = source[_random.nextInt(source.length)];
    _recentBlessings.add(picked);
    if (_recentBlessings.length > 4) {
      _recentBlessings.removeAt(0);
    }
    return picked;
  }

  void _showBlessing(String text) {
    _blessingTimer?.cancel();
    setState(() => _currentBlessing = text);
    _blessingTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _currentBlessing = null);
    });
  }

  void _spawnBurst(Offset origin, Size localSize) {
    final specs = List.generate(24, (i) {
      final angle = (2 * math.pi / 24) * i + _random.nextDouble() * 0.3;
      final distance = 40.0 + _random.nextDouble() * 60.0;
      final isCoin = i.isEven;
      return _ParticleSpec(angle: angle, distance: distance, isCoin: isCoin);
    });
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final burst = _ParticleBurst(
      origin: origin,
      specs: specs,
      controller: controller,
    );
    setState(() => _bursts.add(burst));
    controller.forward().whenCompleteOrCancel(() {
      controller.dispose();
      if (!mounted) return;
      setState(() => _bursts.remove(burst));
    });
  }

  void _finish() {
    if (_navigated) return;
    _navigated = true;
    _countdownTimer?.cancel();
    // [화면 전환] 0.6초 정도의 짧은 페이드 후 정통사주 69종 목록 화면으로
    // 교체 이동. 이 게이트는 "운세" 진입 직후 1회만 등장하는 인트로이며,
    // categoryId는 아직 선택되지 않았으므로 목록 화면([browseRoute])으로만
    // 이동한다(뒤로가기 시 게이트를 다시 보지 않고 곧장 이전 화면으로
    // 돌아가도록 pushReplacementNamed 사용).
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(JeontongEightyMatrix.browseRoute);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _blessingTimer?.cancel();
    _baguaCtrl.dispose();
    for (final b in _bursts) {
      b.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalMs == 0 ? 0.0 : 1 - (_remainingMs / _totalMs);
    final secondsLeft = (_remainingMs / 1000).ceil().clamp(0, 99);

    return Scaffold(
      backgroundColor: _GatePalette.bgInner,
      body: AnimatedOpacity(
        opacity: _navigated ? 0 : 1,
        duration: const Duration(milliseconds: 600),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 배경 (먹색 방사 그라데이션)
            const _GateBackground(),
            // 2. 팔괘 회전 배경 (진행률에 비례)
            AnimatedBuilder(
              animation: _baguaCtrl,
              builder: (context, _) =>
                  _BaguaRing(rotationTurns: _baguaCtrl.value + progress * 0.5),
            ),
            // 3. 본문
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    '今 日 之 運',
                    style: _monoStyle(color: _GatePalette.goldDeep, size: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '결과를 여는 부적',
                    style: _seriflikeStyle(
                      color: _GatePalette.goldPale,
                      size: 18,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Listener(
                    onPointerMove: (event) =>
                        _onPointerMove(event.localPosition, _talismanSize),
                    child: GestureDetector(
                      onTapUp: (details) =>
                          _onTapTalisman(details, _talismanSize),
                      child: SizedBox(
                        width: _talismanSize.width,
                        height: _talismanSize.height,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _Talisman(tiltX: _tiltX, tiltY: _tiltY),
                            for (final burst in _bursts)
                              AnimatedBuilder(
                                animation: burst.controller,
                                builder: (context, _) => CustomPaint(
                                  size: _talismanSize,
                                  painter: _ParticlePainter(
                                    origin: burst.origin,
                                    specs: burst.specs,
                                    t: burst.controller.value,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _currentBlessing == null
                        ? const SizedBox(height: 28, key: ValueKey('empty'))
                        : _BlessingBadge(
                            key: ValueKey(_currentBlessing),
                            text: _currentBlessing!,
                          ),
                  ),
                  const Spacer(),
                  _GateFooter(
                    progress: progress,
                    secondsLeft: secondsLeft,
                    tapCount: _tapCount,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPointerMove(Offset localPos, Size size) {
    final dx = (localPos.dx / size.width) * 2 - 1;
    final dy = (localPos.dy / size.height) * 2 - 1;
    setState(() {
      _tiltX = dx.clamp(-1.0, 1.0);
      _tiltY = dy.clamp(-1.0, 1.0);
    });
  }
}

TextStyle _monoStyle({required Color color, required double size}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Courier'],
    fontSize: size,
    letterSpacing: 3.0,
    fontWeight: FontWeight.w500,
    color: color,
  );
}

TextStyle _seriflikeStyle({
  required Color color,
  required double size,
  FontWeight weight = FontWeight.w600,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0.2,
  );
}

// ─── 배경 ────────────────────────────────────────────────
class _GateBackground extends StatelessWidget {
  const _GateBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [
            _GatePalette.bgOuter,
            _GatePalette.bgMid,
            _GatePalette.bgInner,
          ],
          stops: [0, 0.55, 1],
        ),
      ),
    );
  }
}

// ─── 팔괘 회전 링 ────────────────────────────────────────
class _BaguaRing extends StatelessWidget {
  const _BaguaRing({required this.rotationTurns});
  final double rotationTurns;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: rotationTurns * 2 * math.pi,
          child: SizedBox(
            width: 320,
            height: 320,
            child: Stack(
              children: [
                for (int i = 0; i < _kBaguaGlyphs.length; i++) _bagatGlyphAt(i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bagatGlyphAt(int i) {
    final angle = (2 * math.pi / _kBaguaGlyphs.length) * i;
    const radius = 150.0;
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);
    return Positioned(
      left: 160 + dx - 12,
      top: 160 + dy - 12,
      child: Opacity(
        opacity: 0.14,
        child: Text(
          _kBaguaGlyphs[i],
          style: const TextStyle(
            fontSize: 22,
            color: _GatePalette.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── 부적 본체 ───────────────────────────────────────────
class _Talisman extends StatelessWidget {
  const _Talisman({required this.tiltX, required this.tiltY});
  final double tiltX;
  final double tiltY;

  @override
  Widget build(BuildContext context) {
    // README 스펙 — 마우스/터치 이동에 반응하는 3D 틸트(±15°).
    final rotX = tiltY * (15 * math.pi / 180);
    final rotY = -tiltX * (15 * math.pi / 180);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(rotX)
        ..rotateY(rotY),
      child: Container(
        width: 180,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _GatePalette.talismanTop,
              _GatePalette.talismanMid,
              _GatePalette.talismanBottom,
            ],
          ),
          border: Border.all(
            color: _GatePalette.goldDeep.withValues(alpha: 0.6),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: _GatePalette.goldDeep.withValues(alpha: 0.45),
              blurRadius: 34,
              spreadRadius: 2,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '神通',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: _GatePalette.goldPale,
                shadows: [
                  Shadow(
                    color: _GatePalette.gold.withValues(alpha: 0.8),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '萬事亨通',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                color: _GatePalette.goldDeep.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 축복 명패 ───────────────────────────────────────────
class _BlessingBadge extends StatelessWidget {
  const _BlessingBadge({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: _GatePalette.bgOuter.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _GatePalette.goldDeep.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _GatePalette.goldPale,
        ),
      ),
    );
  }
}

// ─── 하단 UI (카운트다운 + 안내 + 탭 카운트) ────────────────
class _GateFooter extends StatelessWidget {
  const _GateFooter({
    required this.progress,
    required this.secondsLeft,
    required this.tapCount,
  });

  final double progress;
  final int secondsLeft;
  final int tapCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 2.6,
                backgroundColor: _GatePalette.goldDeep.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation(_GatePalette.gold),
              ),
              Text(
                '$secondsLeft',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _GatePalette.goldPale,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$secondsLeft초 후 정통사주 목록으로 이동합니다',
          style: TextStyle(
            fontSize: 12,
            color: _GatePalette.goldPale.withValues(alpha: 0.7),
          ),
        ),
        if (tapCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            '福 · 축복 $tapCount회 받음',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _GatePalette.gold,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 파티클 ──────────────────────────────────────────────
class _ParticleSpec {
  const _ParticleSpec({
    required this.angle,
    required this.distance,
    required this.isCoin,
  });

  final double angle;
  final double distance;
  final bool isCoin;
}

class _ParticleBurst {
  _ParticleBurst({
    required this.origin,
    required this.specs,
    required this.controller,
  });

  final Offset origin;
  final List<_ParticleSpec> specs;
  final AnimationController controller;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.origin,
    required this.specs,
    required this.t,
  });

  final Offset origin;
  final List<_ParticleSpec> specs;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - t).clamp(0.0, 1.0);
    for (final spec in specs) {
      final dist = spec.distance * t;
      final dx = origin.dx + math.cos(spec.angle) * dist;
      final dy = origin.dy + math.sin(spec.angle) * dist - (t * t * 30);
      final paint = Paint()
        ..color = (spec.isCoin ? _GatePalette.gold : _GatePalette.goldPale)
            .withValues(alpha: fade);
      final radius = spec.isCoin ? 3.2 : 1.6;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
