// 탐색(explore) 화면(ExploreScreen) "소원방"/"✨ 이루어진 이야기" 두 탭
// 회귀 테스트.
//
// [발견한 버그 4건] (모두 textScale이 커지면서 고정폭 Row가 가용폭을
// 초과해 `RenderFlex overflowed`가 나는 가로 오버플로 패턴)
// 1) 탐색 헤더 탭 Row("소원방"/"✨ 이루어진 이야기" + Spacer + 정렬칩):
//    실측 360x640@1.3 65px 초과. Wrap(spaceBetween)으로 교체해 평소엔
//    기존과 동일하게 보이고, 공간이 부족할 때만 정렬칩 묶음이 다음
//    줄로 자동 줄바꿈되고, 탭 묶음 자체도 가로 스크롤로 감싸(320x568@2.0
//    55px/@2.5 123px 추가 초과 해결).
// 2) _StoryCard 하단 작성자 Row(닉네임 + "축하해요 N" 버튼): 실측
//    390x844@1.0에서도 54px, 320x568@1.5에서 282px 초과. 닉네임을
//    Flexible+ellipsis로, 축하 버튼 전체를 Flexible+FittedBox(scaleDown)로 감쌌.
// 3) _FeedCard ❤/💬/Lv/응원하기 Row: 실측 360x640@1.3에서 77px 초과.
//    통계 묶음을 Expanded+가로 SingleChildScrollView로 감싸 응원하기 버튼은
//    항상 탭 가능하게 유지.
// 4) 이야기(stories) 탭 버튼 Row("모두의 이야기"/"나의 이야기"): 가로
//    스크롤로 감싸 해결.
// 네 건 모두 디자인·문구·색상·배치 순서 변경 없이 Flexible/Expanded/스크롤로만
// 대응했다.
import 'dart:io';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/explore/explore_screen.dart';

class _FakeWrRepository implements WrRepository {
  @override
  Future<List<WishRoom>> explore({String? cursor}) async => List.generate(
        8,
        (i) => WishRoom.fromJson({
          'id': 'room-$i',
          'ownerId': 'owner-$i',
          'owner': '아주아주아주아주아주아주아주 긴 닉네임 테스트 유저 $i',
          'text': '아주 길고 긴 소원 텍스트가 두 줄로도 다 안 들어갈 정도로 매우 길게 작성된 테스트용 소원 문구입니다 $i',
          'char': 'F00',
          'status': 'ACTIVE',
          'devotionCount': 10,
          'supportCount': 999999,
          'commentCount': 99999,
          'pouchReceived': 0,
          'level': 99,
          'points': 0,
          'levelName': '시작',
          'curLevelPts': 0,
          'nextLevelPts': 100,
          'brightness': 1.0,
          'wishColor': 'hope',
        }),
      );

  @override
  Future<List<WrReview>> reviews({bool mine = false}) async => List.generate(
        6,
        (i) => WrReview.fromJson({
          'id': 'rev-$i',
          'roomId': 'room-$i',
          'author': '아주아주아주 긴 작성자 닉네임 $i',
          'wishText': '아주 길고 긴 원래 소원 문구가 한 줄에 다 들어가지 않을 정도로 깁니다 $i',
          'text': '아주 길고 긴 이야기 본문 텍스트입니다. 소원이 이루어진 순간의 감동을 아주 길게 서술하는 테스트용 문구이며 여러 줄에 걸쳐 표시될 수 있습니다. $i' * 2,
          'wishColor': 'hope',
          'congrats': 123456,
          'congratsByMe': false,
          'mine': i.isEven,
          'visibility': i.isEven ? 'PRIVATE' : 'PUBLIC',
        }),
      );

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
    testWidgets('explore screen rooms tab ${size.width.toInt()}x${size.height.toInt()}@$scale', (tester) async {
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

      final provider = WishRoomProvider(_FakeWrRepository());
      await provider.loadExplore();

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<WishRoomProvider>.value(
            value: provider,
            child: const MaterialApp(home: ExploreScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [rooms tab] overflow 없어야 함');

      // 피드 리스트까지 스크롤.
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull,
          reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [rooms tab scrolled] overflow 없어야 함');
    });

    testWidgets('explore screen stories tab ${size.width.toInt()}x${size.height.toInt()}@$scale', (tester) async {
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

      final provider = WishRoomProvider(_FakeWrRepository());
      await provider.loadReviewFeed();

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<WishRoomProvider>.value(
            value: provider,
            child: const MaterialApp(home: ExploreScreen(initialTab: 'stories')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: '${size.width.toInt()}x${size.height.toInt()}@$scale [stories tab] overflow 없어야 함');
    });
  }
}
