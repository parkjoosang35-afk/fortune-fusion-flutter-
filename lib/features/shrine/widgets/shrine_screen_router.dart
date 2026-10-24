// 신당(THE SHRINE) v4.0 — id → 화면 매핑 (Navigator 1.0 포팅)
// 원본 shrine_module.dart의 `shrineRoutes()`(go_router RouteBase 목록)가
// 하던 역할을 대신한다. ShrineNav.go(context, id, params: {...})가 이
// 파일의 shrineScreenFor(id, params)를 호출해 실제 화면 위젯을 만든다.
//
// id 목록(원본 go_router path와 1:1, 맨 앞 kShrineBase('/shrine')는 제외):
//   entry · about(U5 緣起) · door · hall · connect · info · talk · saju ·
//   recommend · story · end/:code · meaning · ritual · receive ·
//   result/:code · tale/:id · tale-end/:id/:code · list · box
//
// params 규칙(ShrineNav.go 호출부 및 ShrineNav.goPath 전수 조사 기준):
//   end        → {'code': ...}
//   result     → {'code': ...}
//   tale       → {'id': ...}
//   tale-end   → {'id': ..., 'code': ...}
//   그 외       → 없음
import 'package:flutter/material.dart';
import '../screens/screens.dart';
import '../screens/screens_v3.dart';
import '../screens/screens_v32.dart';

Widget shrineScreenFor(String id, Map<String, String>? params) {
  switch (id) {
    case 'entry':
      return const EntryScreen();
    case 'about':
      return const AboutScreen();
    case 'door':
      return const DoorScreenV32();
    case 'hall':
      return const HallScreen();
    case 'connect':
      return const ConnectScreen();
    case 'info':
      return const InfoScreen();
    case 'talk':
      return const TalkScreen();
    case 'saju':
      return const SajuScreen();
    case 'recommend':
      return const RecommendScreen();
    case 'story':
      return const StoryScreen();
    case 'end':
      return EndingScreen(code: params?['code'] ?? '');
    case 'meaning':
      return const MeaningScreen();
    case 'ritual':
      return const RitualScreen();
    case 'receive':
      return const ReceiveScreen();
    case 'result':
      return ResultScreen(code: params?['code'] ?? '');
    case 'tale':
      return TaleScreen(key: ValueKey(params?['id']), id: params?['id'] ?? '');
    case 'tale-end':
      return TaleEndScreen(id: params?['id'] ?? '', code: params?['code'] ?? '');
    case 'list':
      return const ListScreenV3();
    case 'box':
      return const BoxScreen();
    default:
      // 알 수 없는 id는 신당 입장 화면으로 안전하게 되돌린다.
      return const EntryScreen();
  }
}
