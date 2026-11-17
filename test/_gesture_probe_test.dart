import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scale+tapUp combo with drag movement', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) => events.add('scaleStart'),
          onScaleUpdate: (d) => events.add('scaleUpdate'),
          onScaleEnd: (d) => events.add('scaleEnd'),
          onTapUp: (d) => events.add('tapUp'),
          child: Container(color: Colors.red, width: 400, height: 400),
        ),
      ),
    );

    // Simulate drag (should trigger scale events)
    await tester.dragFrom(const Offset(100, 100), const Offset(150, 150));
    await tester.pumpAndSettle();
    debugPrint('DRAG EVENTS: $events');

    events.clear();
    // Simulate quick tap without movement (should trigger tapUp only per prior test)
    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();
    debugPrint('TAP EVENTS: $events');
  });
}
