import 'package:flutter/material.dart';

import '../../../core/auth/auth_token_store.dart';
import '../domain/history_readonly_adapter.dart';
import 'history_jeontong_sectioned_view.dart';

/// 2026‑08‑13 결정.
/// 사용자 히스토리(타로·상담·관상·손금·정통사주 80)를 한 화면에서 Read‑Only 로
/// 모아 보여준다.
///
/// 원칙:
///  · 어떤 편집·재생성·삭제 액션도 노출하지 않는다.
///  · 정통사주 로컬 룰 결과 — AI 호출 없음.
///  · 기존 컬렉션/모델의 스키마는 일체 변경하지 않는다.
class HistoryReadOnlyScreen extends StatefulWidget {
  const HistoryReadOnlyScreen({super.key});

  @override
  State<HistoryReadOnlyScreen> createState() => _HistoryReadOnlyScreenState();
}

class _HistoryReadOnlyScreenState extends State<HistoryReadOnlyScreen> {
  int _tab = 0;

  static const _tabs = <String>[
    '타로', '상담', '관상', '손금', '정통사주',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 기록 (읽기 전용)'),
      ),
      body: Column(
        children: [
          _tabsBar(),
          const Divider(height: 1),
          Expanded(
            child: _tabBody(_tab),
          ),
        ],
      ),
    );
  }

  Widget _tabsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < _tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(_tabs[i]),
                selected: _tab == i,
                onSelected: (_) => setState(() => _tab = i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyTab(int index) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '${_tabs[index]} 기록은 준비 중입니다.\n'
          '메뉴에서 ${_tabs[index]} 를 이용하시면 이 화면에서 모아 볼 수 있어요.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _tabBody(int index) {
    // 정통사주(4번) 탭만 실데이터 vertical slice — 어댑터가 Future 를
    // 반환하도록 갱신됐으므로 FutureBuilder 로 소비한다.
    if (index == 4) {
      return FutureBuilder<List<HistoryReadOnlyEntry>>(
        future: historyReadOnlyAdapter.readJeontong(_currentUserId()),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return HistoryJeontongSectionedView(
            entries: snap.data ?? const [],
            userId: _currentUserId(),
          );
        },
      );
    }
    // 나머지 4탭(타로·상담·관상·손금)은 이전 미션 상태 그대로 —
    // 어댑터가 항상 빈 리스트를 반환하므로 결과적으로 기존 "준비 중" 그대로.
    final entries = _readTab(index);
    if (entries.isEmpty) return _emptyTab(index);
    return _cardList(entries);
  }

  Widget _cardList(List<HistoryReadOnlyEntry> entries) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          title: Text(e.title),
          subtitle: Text('${e.subtitle}\n${e.createdAt.toIso8601String()}'),
          isThreeLine: true,
          // 편집/삭제/재생성 액션 0. onTap 도 없음.
        );
      },
    );
  }

  List<HistoryReadOnlyEntry> _readTab(int index) {
    switch (index) {
      case 0:
        return historyReadOnlyAdapter.readTarot();
      case 1:
        return historyReadOnlyAdapter.readCounsel();
      case 2:
        return historyReadOnlyAdapter.readFace();
      case 3:
        return historyReadOnlyAdapter.readPalm();
    }
    return const <HistoryReadOnlyEntry>[];
  }

  /// [STEP 0-C 실측] 앱 전역에 사용자별 히스토리를 구분할 로그인 사용자 ID
  /// 개념은 AuthTokenStore.cachedUserIdOrNull(SharedPreferences 기반, HTTP
  /// 없음)뿐이다. 비로그인 시 기존 12개 Repository와 동일한 폴백 규칙
  /// (fallbackUserId)을 그대로 따른다.
  String _currentUserId() =>
      (AuthTokenStore.cachedUserIdOrNull ?? AuthTokenStore.fallbackUserId)
          .toString();
}
