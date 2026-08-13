import 'package:flutter/material.dart';

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
            child: _emptyTab(_tab),
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
}
