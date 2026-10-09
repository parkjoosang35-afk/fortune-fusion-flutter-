// lib/features/guinji/widgets/guinji_arrival_overlay.dart
// [귀인지도_최종_핸드오프.html s01 변경파일총괄표 — 신규] 05-4 지인 도착
// 애니메이션(`guinji-arrival.jsx` `CArrivalScreen`/`Arrival` 1:1 이식).
//
// [배치] 지도(M, `/guinji-map/m`)를 보고 있을 때 새 멤버가 감지되면
// 재생한다 — 별도 화면으로 이동하지 않고, 호출부(`guinji_map_result_screen.dart`)가
// 자신의 Stack 맨 위에 이 위젯을 겹쳐 띄운다(핸드오프 "지도를 보고 있을 때
// 재생"이라는 설명과 일치 — 지도 자체를 가리지 않고 그 위에 효과만 더한다).
//
// [감지 방식] 핸드오프 s05-4: "FCM 데이터 메시지 type=guinji_member_joined,
// memberId 또는 지도 화면에서 30초마다 GET /maps/me 비교. 본 사람은
// SharedPreferences: seenMemberIds에 저장". 이번 구현은 [GuinjiArrivalSeenStore]로
// seenMemberIds 영속화 + "지도 화면 진입/새로고침 시점에 비교" 부분만 우선
// 구현한다 — FCM 데이터 메시지 수신과 30초 주기 폴링은 엔진/서버 변경이
// 필요 없는 순수 클라이언트 보강이라 후속 작업으로 남긴다([확인 필요]).
//
// [최대 3명 순차 + 나머지 페이드] 핸드오프: "4.7초 간격으로 최대 3명까지
// 순서대로 재생하고, 나머지는 한 번에 페이드 인합니다."
//
// [접근성] `MediaQuery.disableAnimations`(동작 줄이기)가 켜져 있으면 유성·
// 충격파·흔들림을 생략하고 페이드만 재생한다(핸드오프 명시 사항).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../character/guinji_character.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import 'guinji_animated_graph.dart' show parseGuinjiBirthLabel;
import 'guinji_animation_spec.dart';
import 'guinji_map_widgets.dart';

/// [SharedPreferences: seenMemberIds] 핸드오프 1:1 — 이미 도착 애니메이션을
/// 재생한(또는 재생할 필요 없이 이미 알고 있던) memberId 집합을 로컬에
/// 영속화한다. 여러 지도를 가진 계정이 없으므로(1인 1지도) 키를 전역
/// 단일 키로 둔다.
class GuinjiArrivalSeenStore {
  GuinjiArrivalSeenStore._();

  static const _prefsKey = 'guinji_arrival_seen_member_ids';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet();
  }

  static Future<void> markSeen(Iterable<String> memberIds) async {
    final ids = memberIds.toList();
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet();
    existing.addAll(ids);
    await prefs.setStringList(_prefsKey, existing.toList());
  }

  /// 현재 지도 참여자 [people] 중 아직 "본 적 없는"(=seenMemberIds에 없는)
  /// 사람만 "새로 도착"으로 판정한다. 호출부가 반환값으로 애니메이션을
  /// 재생한 뒤에는 반드시 [markSeen]을 호출해 다음 조회부터 중복 재생되지
  /// 않게 해야 한다.
  ///
  /// [최초 방문 특수 처리] seenMemberIds가 완전히 비어 있으면(이 기기에서
  /// 이 지도를 처음 보는 경우) 이미 N명이 참여해 있었더라도 전원을
  /// "축하 애니메이션 없이 조용히" 기록만 하고 빈 리스트를 반환한다 —
  /// 그렇지 않으면 오래전부터 있던 지인 전원이 도착 애니메이션으로
  /// 쏟아지는 어색한 경험이 된다(핸드오프가 가정하는 "그사이 들어온
  /// 사람"은 이전에 한 번이라도 본 적 있는 지도를 전제로 한다).
  static Future<List<GuinjiPerson>> findNewArrivals(
    List<GuinjiPerson> people,
  ) async {
    if (people.isEmpty) return const [];
    final seen = await load();
    if (seen.isEmpty) {
      await markSeen(people.map((p) => p.id));
      return const [];
    }
    return people.where((p) => !seen.contains(p.id)).toList();
  }
}

/// 지인 도착 애니메이션 오버레이 — 호출부가 `Stack`의 마지막 자식으로
/// 겹쳐 띄운다(`Positioned.fill` 권장). 애니메이션이 끝나고 사용자가
/// 결과 카드를 닫거나 "왜 그런지 보기"를 누르면 [onOpenRelation]/
/// [onClose]로 스스로를 제거해 달라고 알린다(이 위젯 자신은 상태를
/// 들고 있지 않는다 — 호출부가 `_pendingArrivals`를 비우는 식으로 제거).
class GuinjiArrivalOverlay extends StatefulWidget {
  const GuinjiArrivalOverlay({
    super.key,
    required this.arrivals,
    required this.onOpenRelation,
    required this.onClose,
    this.ownerFacePath = 'assets/images/guinji/chars/f30_face.jpg',
  });

  /// 이번에 새로 도착한 사람들(최대 3명은 순차 비행 애니메이션,
  /// 그 이상은 핸드오프 명세대로 "한 번에 페이드 인").
  final List<GuinjiPerson> arrivals;

  /// 마지막 도착자의 결과 카드 "왜 그런지 보기"를 누르면 호출된다.
  final ValueChanged<GuinjiPerson> onOpenRelation;

  /// 배경을 탭하거나 자동 종료 시점에 호출 — 호출부는 이 콜백에서
  /// 오버레이를 Stack에서 제거해야 한다.
  final VoidCallback onClose;

  /// [핸드오프 `GJ.charFor(me)`] "나"(소유자) 얼굴 — 이 위젯 호출 지점에는
  /// 실제 소유자 생년월일이 전달되지 않으므로(엔진/모델 변경 금지 원칙),
  /// `guinji_deep_intro_screen.dart`와 동일한 데모 자산을 재사용한다.
  final String ownerFacePath;

  @override
  State<GuinjiArrivalOverlay> createState() => _GuinjiArrivalOverlayState();
}

/// 각 도착자의 로컬 타임라인 길이(핸드오프 `DONE=2900` + 여유 900ms).
const int _kCycleMs = 3800;

class _GuinjiArrivalOverlayState extends State<GuinjiArrivalOverlay>
    with SingleTickerProviderStateMixin {
  late final List<GuinjiPerson> _sequential;
  late final List<GuinjiPerson> _rest;
  late final Ticker _ticker;

  int _elapsedMs = 0;
  bool _restRevealed = false;
  bool _reduceMotion = false;
  bool _dependenciesReady = false;

  int get _totalSequentialMs {
    if (_sequential.isEmpty) return 0;
    return (_sequential.length - 1) * ArrivalTiming.between.inMilliseconds +
        _kCycleMs;
  }

  @override
  void initState() {
    super.initState();
    final maxSeq = ArrivalTiming.maxSequential;
    _sequential = widget.arrivals.take(maxSeq).toList();
    _rest = widget.arrivals.length > maxSeq
        ? widget.arrivals.sublist(maxSeq)
        : const [];
    _ticker = createTicker((elapsed) {
      final ms = elapsed.inMilliseconds;
      if (!_restRevealed && ms > _totalSequentialMs + 250) {
        setState(() {
          _restRevealed = true;
          _elapsedMs = ms;
        });
      } else {
        setState(() => _elapsedMs = ms);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesReady) {
      _dependenciesReady = true;
      _reduceMotion = MediaQuery.of(context).disableAnimations;
      HapticFeedback.mediumImpact();
      if (_reduceMotion) {
        // 동작 줄이기: 비행/충격 연출 없이 바로 결과만 노출(페이드만).
        setState(() {
          _elapsedMs = _totalSequentialMs + 1;
          _restRevealed = true;
        });
      } else {
        _ticker.start();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 지금 화면에 "결과 카드"로 보여줄 마지막 정착(settle) 완료 도착자.
  GuinjiPerson? get _settledLast {
    GuinjiPerson? last;
    for (var i = 0; i < _sequential.length; i++) {
      final localStart = i * ArrivalTiming.between.inMilliseconds;
      final e = _reduceMotion ? 999999 : _elapsedMs - localStart;
      if (e >= ArrivalTiming.card.inMilliseconds) {
        last = _sequential[i];
      }
    }
    return last;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = math.min(size.height * 0.38, 300.0);
    final slots = List.generate(6, (i) {
      final angle = -math.pi / 2 + i * math.pi / 3 + 0.2;
      return Offset(cx + math.cos(angle) * 125, cy + math.sin(angle) * 135);
    });

    final last = _settledLast;
    final total = _sequential.length + _rest.length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: last != null ? widget.onClose : null,
      child: Container(
        color: GmColors.bg.withValues(alpha: 0.72),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 중심(나) + 빈 슬롯 점선(아직 도착 전 자리).
            CustomPaint(
              painter: _ArrivalSlotsPainter(
                center: Offset(cx, cy),
                slots: slots,
                sequential: _sequential,
                reduceMotion: _reduceMotion,
                elapsedMs: _elapsedMs,
              ),
            ),
            Positioned(
              left: cx - 36,
              top: cy - 36,
              child: _OwnerAvatar(facePath: widget.ownerFacePath),
            ),

            // 각 도착자의 비행·충돌·연결 연출.
            for (var i = 0; i < _sequential.length; i++)
              _ArrivalFlight(
                key: ValueKey('arrival_${_sequential[i].id}'),
                person: _sequential[i],
                slot: slots[i % slots.length],
                center: Offset(cx, cy),
                fromLeft: i.isOdd,
                localElapsedMs: _reduceMotion
                    ? ArrivalTiming.card.inMilliseconds + 1
                    : _elapsedMs - i * ArrivalTiming.between.inMilliseconds,
                reduceMotion: _reduceMotion,
                screenWidth: size.width,
              ),

            // 나머지(4명째~)는 핸드오프 명세대로 한 번에 페이드 인만.
            if (_restRevealed && _rest.isNotEmpty)
              Positioned(
                top: cy + 160,
                left: 24,
                right: 24,
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    '${_rest.length}명이 더 연결되었어요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: GmText.ui,
                      fontSize: 13,
                      color: GmColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // 상단 진행 안내.
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Text(
                    '귀인 지도',
                    style: TextStyle(
                      fontFamily: GmText.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: GmColors.fg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    total == 1 ? '새 귀인이 도착했어요' : '$total명의 귀인이 도착했어요',
                    style: const TextStyle(
                      fontFamily: GmText.ui,
                      fontSize: 13,
                      color: GmColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // 결과 카드 — 마지막으로 정착한 사람 기준(핸드오프 `last`).
            if (last != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 32,
                child: _ArrivalResultCard(
                  person: last,
                  onOpen: () => widget.onOpenRelation(last),
                  reduceMotion: _reduceMotion,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 나(소유자) 아바타 — `guinji_deep_intro_screen.dart`의 `_IntroFace`와
/// 동일한 원형+폴백 패턴을 재사용한다(별도 위젯으로 중복 정의 — private
/// 클래스라 교차 파일 재사용이 불가능해 최소 복제).
class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({required this.facePath});

  final String facePath;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Image.asset(
            facePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: GmColors.gold.withValues(alpha: 0.2),
              alignment: Alignment.center,
              child: const Text(
                '我',
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: GmColors.gold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text('나', style: TextStyle(fontFamily: GmText.ui, fontSize: 12, color: GmColors.muted)),
      ],
    );
  }
}

/// 빈 슬롯 점선(아직 비행 중/도착 전 자리에만 보임) + 중심-슬롯 점선.
class _ArrivalSlotsPainter extends CustomPainter {
  _ArrivalSlotsPainter({
    required this.center,
    required this.slots,
    required this.sequential,
    required this.reduceMotion,
    required this.elapsedMs,
  });

  final Offset center;
  final List<Offset> slots;
  final List<GuinjiPerson> sequential;
  final bool reduceMotion;
  final int elapsedMs;

  @override
  void paint(Canvas canvas, Size size) {
    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < slots.length; i++) {
      // 이 슬롯에 배정된 도착자가 이미 "충돌(HIT)"을 지났으면 더 이상
      // 빈 슬롯을 그리지 않는다(핸드오프: 도착 후 슬롯은 사라짐).
      final personIndex = sequential.length > i ? i : -1;
      if (personIndex >= 0) {
        final localStart = personIndex * ArrivalTiming.between.inMilliseconds;
        final e = reduceMotion ? 999999 : elapsedMs - localStart;
        if (e >= ArrivalTiming.impact.inMilliseconds) continue;
      }
      _dashedCircle(canvas, slots[i], 23, dashed);
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const dashCount = 18;
    for (var i = 0; i < dashCount; i++) {
      final a0 = i / dashCount * 2 * math.pi;
      final a1 = a0 + (2 * math.pi / dashCount) * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a0,
        a1 - a0,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArrivalSlotsPainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs;
}

/// 도착자 1인의 전체 연출(핸드오프 `Arrival` 1:1 이식) — 유성 비행 →
/// 충돌(플래시·링·불꽃) → 얼굴 팝 → 인장 낙관 → 연결선 → 중심으로 흐르는
/// 기운(pulse).
class _ArrivalFlight extends StatelessWidget {
  const _ArrivalFlight({
    super.key,
    required this.person,
    required this.slot,
    required this.center,
    required this.fromLeft,
    required this.localElapsedMs,
    required this.reduceMotion,
    required this.screenWidth,
  });

  final GuinjiPerson person;
  final Offset slot;
  final Offset center;
  final bool fromLeft;
  final int localElapsedMs;
  final bool reduceMotion;
  final double screenWidth;

  static const _hit = 900;
  static const _pop = 960;
  static const _stamp = 1350;
  static const _line = 1700;
  static const _pulse = 2350;
  static const _done = 2900;

  @override
  Widget build(BuildContext context) {
    final e = localElapsedMs;
    if (e < 0) return const SizedBox.shrink();
    final meta = guinjiRelationMetaOf(person.relation);
    final color = meta.color;
    final birth = parseGuinjiBirthLabel(person.birth);
    final character =
        birth == null ? null : GuinjiCharacter.of(birth: birth, stableKey: person.id);

    if (reduceMotion) {
      // 동작 줄이기: 유성/충격 생략, 얼굴만 제자리에서 페이드 인.
      return Positioned(
        left: slot.dx - 23,
        top: slot.dy - 23,
        child: _ArrivalFace(character: character, color: color, name: person.name, hanja: meta.hanja),
      );
    }

    final from = fromLeft ? Offset(screenWidth + 40, -60) : const Offset(-40, -80);
    final ctrl = Offset(
      (from.dx + slot.dx) / 2 + (fromLeft ? -80 : 80),
      math.min(from.dy, slot.dy) - 60,
    );

    return Stack(
      children: [
        // 유성 꼬리 — 충돌 전까지만.
        if (e < _hit + 40)
          CustomPaint(
            painter: _CometPainter(
              from: from,
              ctrl: ctrl,
              to: slot,
              progress: (e / _hit).clamp(0.0, 1.0),
              color: color,
            ),
          ),
        // 충돌 플래시 + 링 3겹 + 불꽃.
        if (e >= _hit && e < _hit + 1600)
          CustomPaint(
            painter: _ImpactPainter(
              center: slot,
              color: color,
              localMs: e - _hit,
            ),
          ),
        // 연결선 — 슬롯 → 중심.
        if (e >= _line)
          CustomPaint(
            painter: _ConnectLinePainter(
              from: slot,
              to: center,
              color: color,
              done: e >= _done,
              progress: ((e - _line) / 650).clamp(0.0, 1.0),
            ),
          ),
        // 중심으로 흐르는 기운(pulse) — 선을 따라 중심으로 작은 빛 3개.
        if (e >= _pulse && e < _pulse + 900)
          CustomPaint(
            painter: _PulsePainter(
              from: slot,
              to: center,
              color: color,
              localMs: e - _pulse,
            ),
          ),
        // 얼굴 + 이름/유형.
        if (e >= _pop)
          Positioned(
            left: slot.dx - 23,
            top: slot.dy - 23,
            child: AnimatedScale(
              scale: 1,
              duration: const Duration(milliseconds: 1),
              child: _ArrivalFace(
                character: character,
                color: color,
                name: person.name,
                hanja: meta.hanja,
                glow: e < _done,
              ),
            ),
          ),
        // 인장 낙관.
        if (e >= _stamp && e < _done + 400)
          Positioned(
            left: slot.dx + 23 * 0.95,
            top: slot.dy - 23 * 0.9 - 15,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GmColors.bg, width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16)],
              ),
              child: Text(
                meta.hanja,
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: GmColors.onFg,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ArrivalFace extends StatelessWidget {
  const _ArrivalFace({
    required this.character,
    required this.color,
    required this.name,
    required this.hanja,
    this.glow = true,
  });

  final GuinjiCharacter? character;
  final Color color;
  final String name;
  final String hanja;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color, blurRadius: 0, spreadRadius: 1.5),
              if (glow) BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 24),
            ],
          ),
          child: character == null
              ? Container(
                  color: color.withValues(alpha: 0.22),
                  alignment: Alignment.center,
                  child: Text(
                    hanja,
                    style: TextStyle(
                      fontFamily: GmText.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: color,
                    ),
                  ),
                )
              : Image.asset(
                  character!.face,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: color.withValues(alpha: 0.22),
                    alignment: Alignment.center,
                    child: Text(
                      hanja,
                      style: TextStyle(
                        fontFamily: GmText.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: color,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontFamily: GmText.ui, fontSize: 11, color: GmColors.fg),
        ),
      ],
    );
  }
}

class _CometPainter extends CustomPainter {
  _CometPainter({
    required this.from,
    required this.ctrl,
    required this.to,
    required this.progress,
    required this.color,
  });

  final Offset from;
  final Offset ctrl;
  final Offset to;
  final double progress;
  final Color color;

  Offset _quadBezier(double t) {
    final u = 1 - t;
    return Offset(
      u * u * from.dx + 2 * u * t * ctrl.dx + t * t * to.dx,
      u * u * from.dy + 2 * u * t * ctrl.dy + t * t * to.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 꼬리 6겹 — 진행도보다 살짝 뒤처진 위치에 작아지는 점을 그려 꼬리 효과.
    for (var k = 0; k < 6; k++) {
      final t = (progress - k * 0.025).clamp(0.0, 1.0);
      final p = _quadBezier(Curves.easeIn.transform(t));
      final r = 5.0 - k * 0.65;
      final paint = Paint()
        ..color = (k == 0 ? Colors.white : color).withValues(alpha: 1 - k * 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + k * 0.5);
      canvas.drawCircle(p, r.clamp(1.0, 5.0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CometPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ImpactPainter extends CustomPainter {
  _ImpactPainter({required this.center, required this.color, required this.localMs});

  final Offset center;
  final Color color;
  final int localMs;

  @override
  void paint(Canvas canvas, Size size) {
    // 플래시(0~700ms).
    if (localMs < 700) {
      final flashOpacity = (0.35 * (1 - localMs / 700)).clamp(0.0, 0.35);
      canvas.drawCircle(
        center,
        160,
        Paint()
          ..color = color.withValues(alpha: flashOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      );
    }
    // 충격파 3겹(0/140/300ms 지연, 1100ms 지속).
    for (final delay in [0, 140, 300]) {
      final e = localMs - delay;
      if (e < 0 || e > 1100) continue;
      final t = e / 1100;
      final radius = 24 + t * (24 * (3.4 + delay / 300 * 1.3));
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2 - delay / 300 * 0.5).clamp(0.5, 2.0)
          ..color = color.withValues(alpha: (1 - t) * 0.9),
      );
    }
    // 불꽃 22개.
    if (localMs < 760) {
      final t = (localMs / 760).clamp(0.0, 1.0);
      for (var i = 0; i < 22; i++) {
        final angle = (i / 22) * 2 * math.pi + (i % 3) * 0.2;
        final dist = 70 * (0.55 + ((i * 37) % 10) / 20) * Curves.easeOut.transform(t);
        final p = Offset(center.dx + math.cos(angle) * dist, center.dy + math.sin(angle) * dist);
        final size_ = (2 + (i % 3)).toDouble();
        canvas.drawCircle(
          p,
          size_ * (1 - t * 0.9),
          Paint()..color = (i % 4 == 0 ? Colors.white : color).withValues(alpha: (1 - t)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter oldDelegate) => oldDelegate.localMs != localMs;
}

class _ConnectLinePainter extends CustomPainter {
  _ConnectLinePainter({
    required this.from,
    required this.to,
    required this.color,
    required this.done,
    required this.progress,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final bool done;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final end = Offset.lerp(from, to, Curves.easeOut.transform(progress))!;
    canvas.drawLine(
      from,
      end,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      from,
      end,
      Paint()
        ..color = (done ? Colors.white : color).withValues(alpha: done ? 0.3 : 0.95)
        ..strokeWidth = done ? 1 : 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectLinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.done != done;
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.from, required this.to, required this.color, required this.localMs});

  final Offset from;
  final Offset to;
  final Color color;
  final int localMs;

  @override
  void paint(Canvas canvas, Size size) {
    for (final delay in [0, 110, 220]) {
      final e = localMs - delay;
      if (e < 0 || e > 520) continue;
      final t = e / 520;
      final p = Offset.lerp(from, to, Curves.easeIn.transform(t))!;
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = Colors.white.withValues(alpha: 1 - t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) => oldDelegate.localMs != localMs;
}

/// 결과 카드 — 핸드오프 `CArrivalScreen`의 하단 카드(`{이름}님은 나에게 /
/// {유형}` + 점수 카운트업 + "왜 그런지 보기").
class _ArrivalResultCard extends StatefulWidget {
  const _ArrivalResultCard({
    required this.person,
    required this.onOpen,
    required this.reduceMotion,
  });

  final GuinjiPerson person;
  final VoidCallback onOpen;
  final bool reduceMotion;

  @override
  State<_ArrivalResultCard> createState() => _ArrivalResultCardState();
}

class _ArrivalResultCardState extends State<_ArrivalResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<int> _count;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 1100),
    );
    _count = IntTween(begin: 0, end: widget.person.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _ArrivalResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationMetaOf(widget.person.relation);
    final color = meta.color;
    return Container(
      key: ValueKey(widget.person.id),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: GmColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 32, offset: const Offset(0, 10)),
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 30),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.person.name}님은 나에게',
                      style: const TextStyle(fontFamily: GmText.ui, fontSize: 11.5, color: GmColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.label,
                      style: TextStyle(
                        fontFamily: GmText.display,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedBuilder(
                    animation: _count,
                    builder: (context, _) => Text(
                      '${_count.value}',
                      style: const TextStyle(
                        fontFamily: GmText.display,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: GmColors.fg,
                      ),
                    ),
                  ),
                  const Text('케미 점수', style: TextStyle(fontFamily: GmText.ui, fontSize: 10, color: GmColors.dim)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          GmRoseButton(label: '왜 그런지 보기', onPressed: widget.onOpen),
        ],
      ),
    );
  }
}
