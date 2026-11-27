import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';

class Repo implements WrRepository {
  bool failItems = true;
  bool failChars = false;
  @override Future<List<WrItem>> items() async {
    if (failItems) throw ApiError(503, 'ITEMS_DOWN', '아이템 조회 실패');
    return [];
  }
  @override Future<List<WrCharacter>> characters() async {
    if (failChars) throw ApiError(401, 'AUTH', '로그인이 필요해요');
    return [WrCharacter.fromJson({'id':'F00','name':'하린','gender':'F','price':0,'title':'수호자','grade':'기본'})];
  }
  @override dynamic noSuchMethod(Invocation i) => throw UnsupportedError('${i.memberName}');
}
class DelayedRepo extends Repo {
  final pending = Completer<List<WrCharacter>>();
  @override Future<List<WrCharacter>> characters() => pending.future;
}
class DelayedRoomRepo extends Repo {
  final pending = Completer<MyRoomResponse>();
  final started = Completer<void>();
  @override Future<MyRoomResponse> myRoom() {
    started.complete();
    return pending.future;
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('로그아웃 뒤 늦게 온 내 방 응답은 잔액과 계정 정보를 복구하지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = DelayedRoomRepo();
    final p = WishRoomProvider(repo);
    final request = p.loadMyRoom();
    await repo.started.future;
    p.clearOnLogout();
    repo.pending.complete(MyRoomResponse.fromJson({'room':null,'me':{'id':'old','nick':'이전 계정','repChar':'F00','pouch':9999}}));
    await request;
    expect(p.me, null);
    expect(p.room, null);
    expect(p.loaded, false);
    expect(p.isLoading, false);
  });
  test('로그아웃 전 시작한 카탈로그 응답은 계정 초기화 뒤 폐기한다', () async {
    final repo = DelayedRepo()..failItems = false;
    final p = WishRoomProvider(repo);
    final request = p.loadCatalog();
    p.clearOnLogout();
    repo.pending.complete([WrCharacter.fromJson({'id':'F00','name':'이전 계정','gender':'F','price':0,'title':'수호자','grade':'기본'})]);
    await request;
    expect(p.characters, isEmpty);
    expect(p.catalogLoaded, false);
    expect(p.catalogLoading, false);
    expect(p.catalogError, null);
  });
  test('아이템 실패에도 성공한 캐릭터 목록 보존하고 재시도 복구', () async {
    final repo = Repo();
    final p = WishRoomProvider(repo);
    await p.loadCatalog();
    expect(p.characters.single.id, 'F00');
    expect(p.catalogError!.code, 'ITEMS_DOWN');
    expect(p.catalogLoading, false);
    expect(p.catalogLoaded, false);
    repo.failItems = false;
    await p.loadCatalog();
    expect(p.catalogLoaded, true);
    expect(p.catalogError, null);
  });
  test('인증 실패는 빈 목록과 독립된 오류로 유지', () async {
    final repo = Repo()..failItems=false..failChars=true;
    final p = WishRoomProvider(repo);
    await p.loadCatalog();
    expect(p.characters, isEmpty);
    expect(p.catalogError!.code, 'AUTH');
    expect(p.catalogLoading, false);
    p.lastError = null; // 다른 조회가 오류를 지워도 카탈로그 오류는 남는다.
    expect(p.catalogError!.code, 'AUTH');
    repo.failChars = false;
    await p.loadCatalog();
    expect(p.characters.single.id, 'F00');
    expect(p.catalogError, null);
  });
}
