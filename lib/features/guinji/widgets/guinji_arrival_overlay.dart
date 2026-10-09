// lib/features/guinji/widgets/guinji_arrival_overlay.dart
// [귀인지도_최종_핸드오프.html s01 변경파일총괄표 — 신규] 05-4 지인 도착
// 애니메이션(`guinji-arrival.jsx` `CArrivalScreen`/`Arrival`/`Dust`/
// `Sparks`/`CountUp` 1:1 이식). [재작성 — 1차 구현 디자인 불일치 수정]
// 1차 구현에서 빠뜨렸던 요소를 전부 복원한다: 푸시 토스트, 금빛 먼지,
// 빈 슬롯 "+" 하이라이트, 전체화면 충돌 플래시, 화면 흔들림, 중심/소유자
// 글로우의 도착 인원 비례 강화, 헤더 문구, 인장 낙관 좌표/크기, "지인
// 초대하기" 버튼 — 모두 원본 JSX 수치·문구 그대로.
//
// [배치] 지도(M, `/guinji-map/m`)를 보고 있을 때 새 멤버가 감지되면
// 재생한다 — 별도 화면으로 이동하지 않고, 호출부(`guinji_map_result_screen.dart`)가
// 자신의 Stack 맨 위에 이 위젯을 겹쳐 띄운다. 원본 프로토타입은 전체
// 화면 자체(CPhone)가 이 연출이므로, 배경은 지도 화면과 동일한
// `GmColors.bg` 단색(반투명 딤 없음)으로 맞춰 이질감이 없게 한다.
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
import 'dart:ui' show ImageFilter;

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

/// 사람 1명의 시각 요소(캐릭터 얼굴/유형색/한자) — 토스트·슬롯 하이라이트·
/// 비행 연출 여러 곳에서 공통으로 쓰므로 한 번만 계산해 재사용한다.
class _PersonVisual {
  const _PersonVisual({required this.character, required this.color, required this.hanja});

  final GuinjiCharacter? character;
  final Color color;
  final String hanja;
}

_PersonVisual _visualFor(GuinjiPerson person) {
  final meta = guinjiRelationMetaOf(person.relation);
  final birth = parseGuinjiBirthLabel(person.birth);
  final character = birth == null ? null : GuinjiCharacter.of(birth: birth, stableKey: person.id);
  return _PersonVisual(character: character, color: meta.color, hanja: meta.hanja);
}

/// 핸드오프 각 사람 기준 누적 시점(ms) — `guinji-arrival.jsx` `Arrival()`의
/// `COMET=0, HIT=900, POP=960, STAMP=1350, LINE=1700, PULSE=2350, DONE=2900`을
/// 그대로 사용한다(네이밍은 [ArrivalTiming] 상수와 동일한 값).
const int _kHit = 900;
const int _kPop = 960;
const int _kStamp = 1350;
const int _kLine = 1700;
const int _kPulse = 2350;
const int _kDone = 2900;

/// 인물 슬롯/얼굴 반지름(핸드오프 `R = 23`).
const double _kFaceRadius = 23;

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
    return (_sequential.length - 1) * ArrivalTiming.between.inMilliseconds + _kDone + 900;
  }

  /// index [i]의 사람 기준 로컬 경과시간(= 핸드오프 `now - t0`).
  int _localElapsed(int i) {
    if (_reduceMotion) return _kDone + 1;
    return _elapsedMs - i * ArrivalTiming.between.inMilliseconds;
  }

  /// 핸드오프 `arrived = seq.filter(s => now >= s.at + 900).length` —
  /// 이미 충돌(HIT)을 지난 사람 수. [_restRevealed]면 나머지도 즉시
  /// "연결된" 것으로 합산해 헤더 인원수가 정확히 커지게 한다.
  int get _arrivedCount {
    var n = 0;
    for (var i = 0; i < _sequential.length; i++) {
      if (_localElapsed(i) >= _kHit) n++;
    }
    if (_restRevealed) n += _rest.length;
    return n;
  }

  /// 핸드오프 `toastFor = seq.find(s => now>=s.at-900 && now<s.at+2200)` —
  /// 도착 0.9초 전부터 2.2초 후까지(총 3.1초) 토스트가 노출될 사람.
  (GuinjiPerson, int)? get _toast {
    for (var i = 0; i < _sequential.length; i++) {
      final e = _localElapsed(i);
      if (e >= -ArrivalTiming.toastLead.inMilliseconds && e < 2200) {
        return (_sequential[i], e);
      }
    }
    return null;
  }

  /// 핸드오프 `shaking = seq.some(s => now>=s.at+900 && now<s.at+1250)`.
  bool get _shaking {
    if (_reduceMotion) return false;
    for (var i = 0; i < _sequential.length; i++) {
      final e = _localElapsed(i);
      if (e >= _kHit && e < _kHit + 350) return true;
    }
    return false;
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

  /// 지금 화면에 "결과 카드"로 보여줄 마지막 정착(settle) 완료 도착자
  /// (핸드오프 `settled[settled.length-1]`).
  GuinjiPerson? get _settledLast {
    GuinjiPerson? last;
    for (var i = 0; i < _sequential.length; i++) {
      if (_localElapsed(i) >= _kDone) {
        last = _sequential[i];
      }
    }
    return last;
  }

  /// 작은 흔들림(핸드오프 `gjaShake 300ms`: ±2px) — 현재 프레임 시각을
  /// 기준으로 근사한다(픽셀 단위 일치보다 "흔들리는 느낌" 재현이 목적).
  Offset get _shakeOffset {
    if (!_shaking) return Offset.zero;
    final t = _elapsedMs.toDouble();
    return Offset(2 * math.sin(t * 0.9), -1 * math.cos(t * 1.3));
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
    final arrived = _arrivedCount;
    final toast = _toast;
    final shakeOffset = _shakeOffset;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: last != null ? widget.onClose : null,
      // [핸드오프 CPhone 배경] 반투명 딤이 아닌 지도 화면과 동일한 단색
      // 배경 — 원본 프로토타입은 전체 화면 자체가 이 연출이라 딤 효과가
      // 없다.
      child: ColoredBox(
        color: GmColors.bg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 중심 배경 글로우 — 도착 인원이 늘수록 밝아짐(핸드오프
            // `radial-gradient(circle, rgba(255,255,255,${0.06+arrived*0.04}))`).
            Positioned(
              left: cx - 130,
              top: cy - 130,
              width: 260,
              height: 260,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: (0.06 + arrived * 0.04).clamp(0.0, 1.0)),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.65],
                    ),
                  ),
                ),
              ),
            ),

            // 흔들리는 본체(지도·슬롯·얼굴 등) — 충돌 순간 ±2px 흔들림.
            Transform.translate(
              offset: shakeOffset,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 중심 → 빈 슬롯 점선 가이드라인(아직 도착 전인 슬롯만).
                  CustomPaint(
                    painter: _GuideLinesPainter(
                      center: Offset(cx, cy),
                      slots: slots,
                      sequential: _sequential,
                      localElapsedOf: _localElapsed,
                    ),
                  ),

                  // 빈 슬롯 "+" 표시(다가오는 중이면 유형색으로 확대·발광).
                  for (var i = 0; i < slots.length; i++)
                    _buildSlotMarker(i, slots[i]),

                  // 금빛 먼지(도착 후 계속 떠오름).
                  CustomPaint(
                    painter: _DustPainter(
                      center: Offset(cx, cy),
                      elapsedMs: _elapsedMs,
                      visible: arrived > 0 && !_reduceMotion,
                    ),
                  ),

                  // 나(소유자) — 도착 인원이 늘수록 금빛 글로우 강화.
                  Positioned(
                    left: cx - 36,
                    top: cy - 36,
                    child: _OwnerAvatar(facePath: widget.ownerFacePath, arrived: arrived),
                  ),

                  // 아직 아무도 도착하지 않았을 때 안내 문구(핸드오프
                  // `CEmpty` 1:1).
                  if (arrived == 0)
                    Positioned(
                      top: cy + 180,
                      left: 24,
                      right: 24,
                      child: const Text(
                        '링크를 받은 지인이 생년월일을 입력하면\n이곳에 한 명씩 연결돼요',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: GmText.ui, fontSize: 15, height: 1.6, color: GmColors.muted),
                      ),
                    ),

                  // 각 도착자의 비행·충돌·연결 연출.
                  for (var i = 0; i < _sequential.length; i++)
                    _ArrivalFlight(
                      key: ValueKey('arrival_${_sequential[i].id}'),
                      person: _sequential[i],
                      slot: slots[i % slots.length],
                      center: Offset(cx, cy),
                      fromLeft: i.isOdd,
                      localElapsedMs: _localElapsed(i),
                      reduceMotion: _reduceMotion,
                      screenSize: size,
                    ),

                  // 나머지(4명째~)는 핸드오프 명세대로 한 번에 페이드 인만
                  // ("최대 3명 순차" 범위를 넘는 추가 인원 — 원본 데모는
                  // 2명 고정이라 등장하지 않지만, 실제 지도는 인원 수가
                  // 가변적이므로 핸드오프 문구를 그대로 살려 보강한다).
                  if (_restRevealed && _rest.isNotEmpty)
                    Positioned(
                      top: cy + 170,
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

                  // 헤더(핸드오프 1:1 문구).
                  Positioned(
                    top: 56,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '귀인 지도',
                          style: TextStyle(
                            fontFamily: GmText.display,
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.6,
                            color: GmColors.fg,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          arrived > 0 ? '$arrived명과 연결되어 있어요' : '아직 연결된 사람이 없어요',
                          style: TextStyle(
                            fontFamily: GmText.ui,
                            fontSize: 13.5,
                            color: arrived > 0 ? GmColors.gold : GmColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 결과 카드(정착 완료) 또는 "지인 초대하기"(아직 아무도 정착
            // 전) — 핸드오프 `{last ? <카드> : <지인 초대하기 버튼>}`.
            if (last != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 32,
                child: _ArrivalResultCard(
                  person: last,
                  onOpen: () => widget.onOpenRelation(last),
                  reduceMotion: _reduceMotion,
                ),
              )
            else
              Positioned(
                left: 24,
                right: 24,
                bottom: 40,
                child: GmRoseButton(label: '지인 초대하기', onPressed: widget.onClose),
              ),

            // 푸시 토스트 — 도착 0.9초 전부터 3.1초간 상단 노출(핸드오프
            // 1:1 문구 "{이름}님이 지도에 들어왔어요 · 방금 · 생년월일을
            // 입력했어요").
            if (toast != null)
              _ArrivalToast(key: ValueKey('toast_${toast.$1.id}'), person: toast.$1, localElapsedMs: toast.$2),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotMarker(int i, Offset slot) {
    // 이 슬롯에 배정된 도착자(최대 `_sequential.length`개 슬롯만 사용).
    final personIndex = i < _sequential.length ? i : -1;
    if (personIndex < 0) {
      // 배정되지 않은 빈 슬롯 — 항상 수수한 점선 "+"만 표시.
      return Positioned(
        left: slot.dx - 23,
        top: slot.dy - 23,
        child: _SlotPlusMark(color: Colors.white.withValues(alpha: 0.22), highlighted: false),
      );
    }
    final e = _localElapsed(personIndex);
    // 핸드오프: `now >= target.at + 900`이면 슬롯 자체를 제거(얼굴로 대체됨).
    if (e >= _kHit) return const SizedBox.shrink();
    // 핸드오프: `incoming = now >= target.at && now < target.at+900`.
    final incoming = e >= 0 && e < _kHit;
    final color = _visualFor(_sequential[personIndex]).color;
    return Positioned(
      left: slot.dx - 23,
      top: slot.dy - 23,
      child: _SlotPlusMark(
        color: incoming ? color : Colors.white.withValues(alpha: 0.22),
        highlighted: incoming,
      ),
    );
  }
}

/// 빈 슬롯 "+" 마커 — 핸드오프: 점선 원 46×46 + "+" 글자, 다가오는 중이면
/// 유형색 테두리·확대(1.15배)·발광.
class _SlotPlusMark extends StatelessWidget {
  const _SlotPlusMark({required this.color, required this.highlighted});

  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: highlighted ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1),
          boxShadow: highlighted
              ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20)]
              : const [],
        ),
        child: Text(
          '+',
          style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// 중심 → 아직 도착 전인 슬롯으로 이어지는 점선 가이드(핸드오프
/// `<line stroke="#fff" strokeOpacity=".12" strokeDasharray="3 5"/>`).
class _GuideLinesPainter extends CustomPainter {
  _GuideLinesPainter({
    required this.center,
    required this.slots,
    required this.sequential,
    required this.localElapsedOf,
  });

  final Offset center;
  final List<Offset> slots;
  final List<GuinjiPerson> sequential;
  final int Function(int index) localElapsedOf;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12);
    for (var i = 0; i < slots.length; i++) {
      final personIndex = i < sequential.length ? i : -1;
      if (personIndex >= 0 && localElapsedOf(personIndex) >= _kHit) continue;
      _dashedLine(canvas, center, slots[i], paint);
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 3.0, gapLen = 5.0;
    final total = (b - a).distance;
    final dir = (b - a) / (total == 0 ? 1 : total);
    var dist = 0.0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * math.min(dist + dashLen, total);
      canvas.drawLine(start, end, paint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _GuideLinesPainter oldDelegate) => true;
}

/// 금빛 먼지 — 핸드오프 `Dust`: 16개, 계속 위로 떠오르며 페이드.
class _DustPainter extends CustomPainter {
  _DustPainter({required this.center, required this.elapsedMs, required this.visible});

  final Offset center;
  final int elapsedMs;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final cx = center.dx;
    final cy = center.dy;
    for (var i = 0; i < 16; i++) {
      final baseLeft = cx - 110 + ((i * 53) % 220);
      final baseTop = cy + 40 + ((i * 29) % 90);
      final dur = 3200 + (i % 5) * 500;
      final delay = (i % 8) * 380;
      final effective = elapsedMs - delay;
      if (effective < 0) continue;
      final p = (effective % dur) / dur;
      double opacity;
      if (p < 0.15) {
        opacity = (p / 0.15);
      } else {
        opacity = 1 - ((p - 0.15) / 0.85);
      }
      opacity = opacity.clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      final dy = -120 * Curves.easeOut.transform(p);
      final d = 2.0 + (i % 2);
      canvas.drawCircle(
        Offset(baseLeft, baseTop + dy),
        d / 2,
        Paint()
          ..color = GmColors.gold.withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs || oldDelegate.visible != visible;
}

/// 푸시 토스트 — 핸드오프 1:1: 상단, 둥근 알약, 블러 배경, 얼굴+텍스트.
/// `gjaToast` 키프레임(0%: y -120%·op0 → 12%: y0·op1 → 82%: y0·op1 →
/// 100%: y -120%·op0, 총 3100ms)을 로컬 경과시간으로 근사한다.
class _ArrivalToast extends StatelessWidget {
  const _ArrivalToast({super.key, required this.person, required this.localElapsedMs});

  final GuinjiPerson person;

  /// [GuinjiArrivalOverlay._toast]가 넘겨준 로컬 경과시간(-900~2200ms 범위).
  final int localElapsedMs;

  @override
  Widget build(BuildContext context) {
    // 전체 노출 구간을 0..1로 정규화(시작 -900ms, 끝 +2200ms, 총 3100ms).
    final t = ((localElapsedMs + 900) / 3100).clamp(0.0, 1.0);
    double opacity;
    double translateFactor; // 0 = 제자리, 1 = 위로 사라짐.
    if (t < 0.12) {
      final p = t / 0.12;
      opacity = p;
      translateFactor = 1 - p;
    } else if (t < 0.82) {
      opacity = 1;
      translateFactor = 0;
    } else {
      final p = (t - 0.82) / 0.18;
      opacity = 1 - p;
      translateFactor = p;
    }
    final visual = _visualFor(person);

    return Positioned(
      top: 54,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -40 * translateFactor),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xE01E1E20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: visual.color, width: 1.5),
                            ),
                            child: visual.character == null
                                ? Container(
                                    color: visual.color.withValues(alpha: 0.22),
                                    alignment: Alignment.center,
                                    child: Text(
                                      visual.hanja,
                                      style: TextStyle(
                                        fontFamily: GmText.display,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: visual.color,
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    visual.character!.face,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: visual.color.withValues(alpha: 0.22)),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${person.name}님이 지도에 들어왔어요',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: GmText.ui,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: GmColors.fg,
                                  ),
                                ),
                                const Text(
                                  '방금 · 생년월일을 입력했어요',
                                  style: TextStyle(fontFamily: GmText.ui, fontSize: 12.5, color: GmColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 나(소유자) 아바타 — 도착 인원이 늘수록 금빛 글로우가 강해진다(핸드오프
/// `glow={rgba(233,196,106,${0.15+arrived*0.15})}`).
class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({required this.facePath, required this.arrived});

  final String facePath;
  final int arrived;

  @override
  Widget build(BuildContext context) {
    final glowAlpha = (0.15 + arrived * 0.15).clamp(0.0, 1.0);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
            boxShadow: [BoxShadow(color: GmColors.gold.withValues(alpha: glowAlpha), blurRadius: 28)],
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
        const SizedBox(height: 7),
        const Text('나', style: TextStyle(fontFamily: GmText.ui, fontSize: 12.5, color: GmColors.muted)),
      ],
    );
  }
}

/// 도착자 1인의 전체 연출(핸드오프 `Arrival` 1:1 이식) — 유성 비행 →
/// 충돌(전체화면 플래시·충격파 3겹·불꽃 22개) → 얼굴 팝 → 인장 낙관 →
/// 연결선 → 중심으로 흐르는 기운(pulse).
class _ArrivalFlight extends StatelessWidget {
  const _ArrivalFlight({
    super.key,
    required this.person,
    required this.slot,
    required this.center,
    required this.fromLeft,
    required this.localElapsedMs,
    required this.reduceMotion,
    required this.screenSize,
  });

  final GuinjiPerson person;
  final Offset slot;
  final Offset center;
  final bool fromLeft;
  final int localElapsedMs;
  final bool reduceMotion;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    final e = localElapsedMs;
    if (e < 0) return const SizedBox.shrink();
    final visual = _visualFor(person);
    final color = visual.color;

    if (reduceMotion) {
      // 동작 줄이기: 유성/충격 생략, 얼굴만 제자리에서 페이드 인.
      return Positioned(
        left: slot.dx - _kFaceRadius,
        top: slot.dy - _kFaceRadius,
        child: _ArrivalFace(character: visual.character, color: color, name: person.name, hanja: visual.hanja),
      );
    }

    final from = fromLeft ? Offset(screenSize.width + 40, -60) : const Offset(-40, -80);
    final ctrl = Offset(
      (from.dx + slot.dx) / 2 + (fromLeft ? -80 : 80),
      math.min(from.dy, slot.dy) - 60,
    );

    return Stack(
      children: [
        // 유성 꼬리 — 충돌 전까지만.
        if (e < _kHit + 40)
          CustomPaint(
            painter: _CometPainter(
              from: from,
              ctrl: ctrl,
              to: slot,
              progress: (e / _kHit).clamp(0.0, 1.0),
              color: color,
            ),
          ),
        // 충돌: 전체 화면 플래시(핸드오프 `inset:-200` radial-gradient) +
        // 충격파 3겹 + 불꽃.
        if (e >= _kHit && e < _kHit + 1600)
          Positioned.fill(
            child: CustomPaint(
              painter: _ImpactPainter(
                center: slot,
                color: color,
                localMs: e - _kHit,
                screenSize: screenSize,
              ),
            ),
          ),
        // 연결선 — 슬롯 → 중심.
        if (e >= _kLine)
          CustomPaint(
            painter: _ConnectLinePainter(
              from: slot,
              to: center,
              color: color,
              done: e >= _kDone,
              progress: ((e - _kLine) / 650).clamp(0.0, 1.0),
            ),
          ),
        // 중심으로 흐르는 기운(pulse) — 선을 따라 중심으로 작은 빛 3개
        // + 중심 링 파동(핸드오프 `gjaCore`).
        if (e >= _kPulse && e < _kPulse + 900)
          CustomPaint(
            painter: _PulsePainter(
              from: slot,
              to: center,
              color: color,
              localMs: e - _kPulse,
            ),
          ),
        if (e >= _kPulse + 500 && e < _kPulse + 1600)
          Positioned(
            left: center.dx - 36,
            top: center.dy - 36,
            child: _CoreRing(color: color, localMs: e - (_kPulse + 500)),
          ),
        // 얼굴 + 이름/유형.
        if (e >= _kPop)
          Positioned(
            left: slot.dx - _kFaceRadius,
            top: slot.dy - _kFaceRadius,
            child: _ArrivalFace(
              character: visual.character,
              color: color,
              name: person.name,
              hanja: visual.hanja,
              glow: e < _kDone,
            ),
          ),
        // 인장 낙관(핸드오프 좌표: `x + R*0.95, y - R*0.9`, 크기 30×30).
        if (e >= _kStamp && e < _kDone + 400)
          Positioned(
            left: slot.dx + _kFaceRadius * 0.95,
            top: slot.dy - _kFaceRadius * 0.9,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  const BoxShadow(color: GmColors.bg, blurRadius: 0, spreadRadius: 2),
                  BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 20),
                ],
              ),
              child: Text(
                visual.hanja,
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: GmColors.onFg,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 중심 링 파동(핸드오프 `gjaCore`: scale 1→2.6, opacity .9→0, 900ms).
class _CoreRing extends StatelessWidget {
  const _CoreRing({required this.color, required this.localMs});

  final Color color;
  final int localMs;

  @override
  Widget build(BuildContext context) {
    final t = (localMs / 900).clamp(0.0, 1.0);
    final scale = 1 + t * 1.6;
    final opacity = (0.9 * (1 - t)).clamp(0.0, 0.9);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: opacity), width: 2),
        ),
      ),
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
              BoxShadow(color: color.withValues(alpha: glow ? 0.67 : 0.27), blurRadius: glow ? 30 : 12),
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
  _ImpactPainter({
    required this.center,
    required this.color,
    required this.localMs,
    required this.screenSize,
  });

  final Offset center;
  final Color color;
  final int localMs;
  final Size screenSize;

  @override
  void paint(Canvas canvas, Size size) {
    // 전체 화면 플래시(0~700ms) — 핸드오프 `inset:-200` radial-gradient를
    // 화면 대각선 길이 기준 반지름으로 재현.
    if (localMs < 700) {
      final flashOpacity = (0.35 * (1 - localMs / 700)).clamp(0.0, 0.35);
      final radius = screenSize.longestSide;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: flashOpacity), color.withValues(alpha: 0)],
            stops: const [0, 0.4],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
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
