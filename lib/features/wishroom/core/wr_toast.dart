// 소원방 전역 토스트 — app2/wr2.css `.toast` + shell2.jsx `say()` 1:1.
//
// [버그수정 — 전수감사] fx2.jsx/shell2.jsx 전역 토스트(app.toast)는 화면 상단
// top:110px·중앙·둥근 pill(rgba(30,12,24,.9)+blur16)·rise-in .4s·2.6s 자동소멸인데,
// 기존 Flutter 구현 11개 화면 49곳이 전부 기본 Material ScaffoldMessenger
// SnackBar(화면 하단, 사각형, 기본 다크 테마)를 그대로 썼다. 위치·모양·지속시간이
// 전부 명세와 달랐다. OverlayEntry로 .toast와 1:1 재현하고, 기존 호출부는
// WrToast.show(context, message)로 교체한다.
import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/wr_theme.dart';

class WrToast {
  WrToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// app.toast(s) 1:1. 2.6s 뒤 자동으로 사라지고(say() setTimeout 2600),
  /// 연속 호출 시 기존 토스트를 즉시 교체한다(clearTimeout(tT.current)).
  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    showWithOverlay(overlay, message);
  }

  /// Navigator.pop() 직후처럼 호출 시점의 context가 이미 dispose됐을 수
  /// 있는 경우를 위한 버전 — pop() 이전에 Overlay.of(context, rootOverlay:
  /// true)를 미리 캡쳐해 두고 pop 이후에 이 메서드로 띄운다.
  static void showWithOverlay(OverlayState overlay, String message) {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;

    final entry = OverlayEntry(builder: (_) => _WrToastView(message: message));
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 2600), () {
      entry.remove();
      if (_entry == entry) _entry = null;
    });
  }
}

class _WrToastView extends StatefulWidget {
  const _WrToastView({required this.message});
  final String message;
  @override
  State<_WrToastView> createState() => _WrToastViewState();
}

class _WrToastViewState extends State<_WrToastView>
    with SingleTickerProviderStateMixin {
  // rise-in .4s both: opacity 0→1, translateY 20px→0.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 110,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = Curves.easeOut.transform(_c.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - t)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE61E0C18), // rgba(30,12,24,.9)
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: WrC.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message,
                      style: WrF.body(12.5, color: Colors.white),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
