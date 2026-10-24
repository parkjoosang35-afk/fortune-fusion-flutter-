// U11: 이야기방 001~010 추가 후 Shrine.load() 전체 파싱 및 route 로직 검증.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/shrine/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Shrine.load() parses tales including r001..r010', () async {
    final shrine = await Shrine.load();

    // 기존 4개 + 신규 10개 = 14개
    expect(shrine.tales.length, 14);
    for (final id in ['room', 'night', 'other', 'secret']) {
      expect(shrine.tales.containsKey(id), true, reason: '$id 가 사라지면 안 됨');
    }
    for (var i = 1; i <= 10; i++) {
      final key = 'r${i.toString().padLeft(3, '0')}';
      expect(shrine.tales.containsKey(key), true, reason: '$key 가 있어야 함');
    }

    // 각 이야기방의 judge() 결말 분기 4개(A/B/C/D) 모두 도달 가능한지 확인
    for (var i = 1; i <= 10; i++) {
      final key = 'r${i.toString().padLeft(3, '0')}';
      final tale = shrine.tales[key]!;

      expect(tale.judge({'give'}), 'C', reason: '$key give->C');
      expect(tale.judge({'key', 'listen'}), 'A', reason: '$key key+listen->A');
      expect(tale.judge({'key'}), 'B', reason: '$key key->B');
      expect(tale.judge({'seal'}), 'B', reason: '$key seal->B');
      expect(tale.judge({'froze'}), 'D', reason: '$key froze(기타)->D');

      // 각 노드/결말 아트 경로가 room-NNN 형식인지 확인
      expect(tale.cover.startsWith('rooms/room-$i'.padLeft(0, '0')) ||
             tale.cover.contains('room-${i.toString().padLeft(3, '0')}'), true);
      expect(tale.nodes.length, 3); // s1, s2, s3
      expect(tale.nodes.containsKey('s1'), true);
      expect(tale.nodes.containsKey('s2'), true);
      expect(tale.nodes.containsKey('s3'), true);
      expect(tale.endings.length, 4);
      expect(tale.endings.containsKey('A'), true);
      expect(tale.endings.containsKey('B'), true);
      expect(tale.endings.containsKey('C'), true);
      expect(tale.endings.containsKey('D'), true);
    }
  });

  test('flagFlavor has listen/key/warm/cold mapping via TalismanEngine', () async {
    final shrine = await Shrine.load();
    final i = shrine.talismans.interpret(['listen']);
    expect(i.id, 'observe');
    final i2 = shrine.talismans.interpret(['key']);
    expect(i2.id, 'return');
    final i3 = shrine.talismans.interpret(['warm']);
    expect(i3.id, 'trust');
    final i4 = shrine.talismans.interpret(['cold']);
    expect(i4.id, 'leave');
  });

  test('all 100 room image files exist on disk (filesystem check, not rootBundle)', () async {
    // 단위 테스트 환경에는 AssetManifest가 생성되지 않아 rootBundle.load가
    // 항상 실패하므로, 실제 파일 시스템 존재 여부로 검증한다.
    final names = ['cover','place','object','seorena','choice1','visitor','choice2','climax','end-light','end-dark'];
    for (var i = 1; i <= 10; i++) {
      final rid = i.toString().padLeft(3, '0');
      for (var idx = 0; idx < names.length; idx++) {
        final num = (idx + 1).toString().padLeft(2, '0');
        final path = 'assets/shrine/img/rooms/room-$rid/room-$rid-$num-${names[idx]}.jpg';
        final exists = File(path).existsSync();
        expect(exists, true, reason: 'missing file: $path');
      }
    }
  });
}
