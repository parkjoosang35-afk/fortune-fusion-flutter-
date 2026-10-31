// 보관함(vault) '복주머니' 탭(_PouchTab) 회귀 테스트.
//
// [발견한 버그] "복주머니 모으기"(제목) + "매일 자정 초기화"(부제) 두 Text가
// Flexible/Expanded 없이 고정폭으로 Row에 바로 들어있어, textScale이
// 커지면 Row 가용폭(화면폭-32)을 초과해 가로로 넘쳤다(실측 320x568@2.0,
// 81px 초과). 320x568@1.5/2.5, 390x844@1.0 등 다른 조건에서는 재현되지
// 않았다(두 텍스트 합산 폭이 딱 2.0배수 근처에서만 가용폭을 넘김).
//
// [수정 내용] (디자인·문구·색상 변경 없음)
// 부제 Text를 Flexible+overflow:ellipsis로 감싸, 평소(공간 충분)엔 그대로
// 보이고 넘칠 때만 말줄임표로 줄어들게 했다.
//
// 적립 섹션(_kSections 6개 전부 최악 케이스: 진행 거의 완료 + 긴 라벨),
// 내역 리스트(긴 라벨 10건), 사용처 리스트까지 스크롤한 하단 콘텐츠도
// 함께 점검한다.
import 'dart:io';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/vault/vault_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<List<Map<String, dynamic>>> ledger() async => List.generate(10, (i) => {
        'label': '아주 길고 긴 적립 내역 설명 텍스트 테스트 $i',
        'amount': i.isEven ? 30 : -15,
        'at': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Future<List<WishRoom>> archive() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (size, scale) in <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ]) {
    testWidgets('pouch tab ${size.width.toInt()}x${size.height.toInt()}@$scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await WrCatalog.load();
        final data = ByteData.view(File('/usr/share/fonts/truetype/nanum/NanumSquareR.ttf').readAsBytesSync().buffer);
        for (final family in ['Pretendard', 'NotoSerifKR', 'GowunBatang', 'IBMPlexMono']) {
          await (FontLoader(family)..addFont(Future.value(data))).load();
        }
      });

      final room = WishRoom.fromJson({
        'id': 'room-1', 'ownerId': 'owner-1', 'owner': '테스트', 'text': '소원',
        'char': 'F00', 'status': 'ACTIVE', 'devotionCount': 7, 'supportCount': 0,
        'pouchReceived': 0, 'level': 1, 'points': 0, 'levelName': '시작',
        'curLevelPts': 0, 'nextLevelPts': 100, 'brightness': 1.0,
        'devotionsToday': 7, 'dailyLimit': 10,
      });
      final me = Me.fromJson({
        'id': 'u1', 'nick': '테스트', 'repChar': 'F00', 'pouch': 1234567,
        // 모든 EARN 항목을 거의 다 채운 최악 케이스(진행바 n/limit 최대, 완료표시 포함)
        'earnToday': {'ad': 9, 'attend': 1, 'devo10': 1, 'm_visit': 1, 'm_cheer': 1, 'm_msg': 1},
      });
      final provider = WishRoomProvider(_FakeWrRepository())
        ..room = room
        ..me = me;

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<WishRoomProvider>.value(
            value: provider,
            child: const MaterialApp(home: VaultScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 보관함 기본 탭(소원 기록관) -> 복주머니 탭으로 전환
      await tester.tap(find.text('복주머니'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [pouch tab] overflow 없어야 함');

      // 맨 아래(사용처/내역 리스트)까지 스크롤해 하단 콘텐츠도 점검.
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull,
          reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [pouch tab scrolled] overflow 없어야 함');
    });
  }
}
