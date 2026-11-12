import 'package:flutter/widgets.dart';

/// [신통방통 전역 핀치 확대 시스템 — Gesture Controller]
///
/// ## 왜 GestureRecognizer/GestureDetector가 아니라 순수 Listener인가
///
/// Flutter의 "제스처"(탭/드래그/스케일 등)는 경기장(Gesture Arena) 방식으로
/// 해석된다 — 같은 지점을 지나는 여러 레코그나이저(예: 이 엔진 + 그 아래
/// ListView의 스크롤, 버튼의 탭)가 후보로 등록되고, 그중 하나가 승리를
/// 선언하면 나머지는 패배 처리되어 이벤트를 더 이상 받지 못한다.
/// `InteractiveViewer`가 내부적으로 쓰는 `ScaleGestureRecognizer`를 화면
/// 전체에 상시 걸어두면, 이 레코그나이저가 정확히 언제 승리를 선언해야
/// 하는지(1손가락일 때는 절대 안 되고, 2손가락일 때만)가 매우 미묘해서,
/// 탭(버튼) 쪽의 "경기장 스윕(sweep)" 처리와 충돌해 간헐적으로 버튼이
/// 안 눌리는 회귀가 생길 위험이 있다 — 이는 실기기 다중 터치 환경에서만
/// 재현되는 경우가 많아 사전 검증이 극히 어렵다.
///
/// 이 엔진은 그 위험을 원천 차단하기 위해 **경기장에 전혀 참여하지 않는
/// [Listener]** 만 사용한다. [Listener]는 탭/드래그 같은 "해석된 제스처"가
/// 아니라 원시(raw) 포인터 이벤트를 그냥 관찰만 하는 위젯이라, 그 지점의
/// 다른 모든 위젯(버튼의 탭 레코그나이저, 리스트의 스크롤 레코그나이저)이
/// 평소와 완전히 동일하게 자기 몫의 경기장 승리를 그대로 가져간다 —
/// 이 엔진은 "누가 이겼는지"와 무관하게 포인터 좌표만 조용히 지켜보다가,
/// 2번째 손가락이 닿는 순간 스스로 오버레이를 띄워 확대를 담당한다.
///
/// 결과적으로 "1손가락 입력에는 이 엔진이 구조적으로 전혀 관여하지
/// 않는다"는 것이 코드 레벨에서 보장되며, 이는 "기존 한 손가락 스크롤과
/// 버튼 동작은 유지한다"는 요구사항을 가장 안전하게 만족시키는 방식이다.
class PinchGestureListener extends StatefulWidget {
  const PinchGestureListener({
    super.key,
    required this.child,
    required this.onPinchStart,
    required this.onPinchUpdate,
    required this.onPinchEnd,
    this.onSingleDown,
    this.onSingleMove,
    this.onSingleUp,
    this.blockPassThrough = false,
  });

  final Widget child;

  /// 2번째 손가락이 닿아 핀치가 "시작"될 때 — 두 포인터의 초기 위치.
  final void Function(Offset posA, Offset posB) onPinchStart;

  /// 두 포인터 중 하나라도 움직일 때마다 최신 위치.
  final void Function(Offset posA, Offset posB) onPinchUpdate;

  /// 핀치를 구성하던 두 손가락 중 하나라도 떨어지면 즉시 호출.
  final VoidCallback onPinchEnd;

  /// [확대 유지 기능용] 화면에 손가락이 "정확히 1개"만 닿아 있는 상태로
  /// 전환되는 순간(핀치 중이 아닐 때) 호출된다 — 핀치가 끝난 직후 한
  /// 손가락이 남아 있는 경우도 포함한다. 평소(확대 안 한 상태)에는 매니저가
  /// 이 콜백을 그냥 무시하므로 1손가락 스크롤/탭 동작에 영향이 없다.
  ///
  /// [isPinchContinuation]이 true면 "방금 핀치(2손가락)가 끝나면서 남은
  /// 손가락"을 뜻한다 — 실기기에서는 두 손가락을 "동시에" 뗐다고 느껴도
  /// 실제로는 한쪽이 몇 ms 먼저 이벤트가 들어오는 경우가 거의 항상
  /// 발생하므로, 이 경우를 "사용자가 새로 탭을 시작한 것"과 구분해야
  /// 한다(그렇지 않으면 핀치 종료 직후 남은 손가락이 바로 떨어지는 것이
  /// "탭"으로 오인되어 확대가 즉시 닫혀버리는 버그가 재발한다).
  final void Function(Offset pos, {required bool isPinchContinuation})?
  onSingleDown;

  /// 위 상태에서 그 손가락이 움직일 때마다 최신 위치.
  final void Function(Offset pos)? onSingleMove;

  /// 위 상태의 손가락이 떨어질 때 호출.
  final VoidCallback? onSingleUp;

  /// true면 이 레이어 아래(실제 화면 버튼/스크롤)로 터치가 전달되지
  /// 않도록 막는다. 확대가 진행 중일 때(2손가락 핀치 중)만 true로
  /// 바꿔, 혹시 끼어드는 3번째 손가락 탭이 그 아래 버튼을 눌러버리는
  /// 사고를 막는다("확대 중 버튼 오작동 방지" 요구사항). 평소(false)엔
  /// 이 레이어는 아예 존재하지 않는 것처럼 모든 입력을 투과한다.
  final bool blockPassThrough;

  @override
  State<PinchGestureListener> createState() => _PinchGestureListenerState();
}

class _PinchGestureListenerState extends State<PinchGestureListener> {
  /// 현재 화면에 닿아 있는 모든 포인터(순서 보존을 위해 LinkedHashMap 역할
  /// — Dart의 기본 Map은 삽입 순서를 보존하므로 별도 자료구조 불필요).
  final Map<int, Offset> _pointers = <int, Offset>{};

  /// 핀치를 구성 중인 두 포인터 ID(순서 고정 — 중간에 3번째 손가락이
  /// 닿아도 이 두 포인터만 계속 확대 기준으로 삼는다. "비정상 멀티터치
  /// 입력 안전 처리" 요구사항).
  int? _pointerA;
  int? _pointerB;
  bool _pinching = false;

  void _handleDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;

    if (!_pinching && _pointers.length == 2) {
      final ids = _pointers.keys.toList(growable: false);
      _pointerA = ids[0];
      _pointerB = ids[1];
      _pinching = true;
      widget.onPinchStart(_pointers[_pointerA]!, _pointers[_pointerB]!);
    } else if (!_pinching && _pointers.length == 1) {
      // [확대 유지 기능] 손가락이 1개만 닿은 상태 — 핀치가 아니라 단일
      // 포인터 세션(탭/이동)의 시작으로 매니저에 알린다. 이 경로는 순수
      // 신규 터치(핀치 직후가 아님)이므로 isPinchContinuation=false.
      widget.onSingleDown?.call(event.position, isPinchContinuation: false);
    }
    // 3번째 이상 손가락은 추적 맵에는 남기되(좌표 정리를 위해) 핀치 기준
    // (pointerA/B)에는 영향을 주지 않는다 — 이미 핀치 중이면 추가 손가락은
    // 무시된다.
  }

  void _handleMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (_pinching && _pointerA != null && _pointerB != null) {
      final posA = _pointers[_pointerA];
      final posB = _pointers[_pointerB];
      if (posA != null && posB != null) {
        widget.onPinchUpdate(posA, posB);
      }
    } else if (!_pinching && _pointers.length == 1) {
      widget.onSingleMove?.call(event.position);
    }
  }

  void _handleUpOrCancel(int pointer) {
    final wasPinchFinger = pointer == _pointerA || pointer == _pointerB;
    _pointers.remove(pointer);

    if (_pinching && wasPinchFinger) {
      // 핀치를 구성하던 두 손가락 중 하나라도 떨어지면 즉시 종료한다
      // ("터치 종료 시 상태 복구" 요구사항) — 설령 다른 손가락이 화면에
      // 남아 있어도 더 이상 2점 핀치가 아니므로 깔끔하게 끝낸다.
      _pinching = false;
      _pointerA = null;
      _pointerB = null;
      widget.onPinchEnd();
      // [확대 유지 기능] 핀치가 끝났는데 손가락 하나가 아직 화면에 남아
      // 있다면, 그 손가락은 이미 "내려가 있던" 상태이므로 지금 바로 단일
      // 포인터 세션(이동/탭)의 시작으로 알려준다 — 사용자가 두 손가락을
      // 동시에 떼지 않고 한쪽만 먼저 떼는 자연스러운 경우를 지원한다.
      // isPinchContinuation=true로 표시해, 매니저가 이 손가락이 바로
      // 떨어져도 "탭으로 닫기"로 오인하지 않도록 한다(핵심 버그 수정).
      if (_pointers.length == 1) {
        widget.onSingleDown?.call(
          _pointers.values.first,
          isPinchContinuation: true,
        );
      }
    } else if (!_pinching && _pointers.isEmpty) {
      widget.onSingleUp?.call();
    }

    if (_pointers.isEmpty) {
      // 모든 손가락이 떨어졌다 — 다음 터치는 완전히 새로운 사이클로
      // 취급하기 위해 내부 상태를 완전히 비워 메모리/상태 잔존을 막는다.
      _pointerA = null;
      _pointerB = null;
      _pinching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // translucent(평소): 이 지점의 다른 모든 위젯(버튼 탭, 리스트
      // 스크롤 등)의 경기장 판정에 어떤 영향도 주지 않는다 — 순수 관찰자.
      // opaque(확대 중): 추가로 끼어드는 터치가 아래 버튼까지 뚫고
      // 내려가 오작동을 일으키지 않도록 이 레이어에서 흡수한다.
      behavior: widget.blockPassThrough
          ? HitTestBehavior.opaque
          : HitTestBehavior.translucent,
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: (e) => _handleUpOrCancel(e.pointer),
      onPointerCancel: (e) => _handleUpOrCancel(e.pointer),
      child: widget.child,
    );
  }
}
