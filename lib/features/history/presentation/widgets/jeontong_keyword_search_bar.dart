import 'package:flutter/material.dart';

/// [정통사주 80종 키워드 검색] 한 줄 검색바.
///
/// 디바운스 0(즉각), regex 0(단순 substring), dart:io/HTTP/Socket/File/
/// Random/DateTime.now() 사용 0건 — 순수 텍스트 입력 위젯이며 실제 필터
/// 로직은 부모(HistoryJeontongOverviewScreen)의 onChanged 콜백에서
/// simpleSearch() 패턴으로 처리한다(이 위젯 자체는 상태 없는 입력 UI).
class JeontongKeywordSearchBar extends StatefulWidget {
  const JeontongKeywordSearchBar({
    super.key,
    required this.onChanged,
    required this.initialQuery,
  });

  final ValueChanged<String> onChanged;
  final String initialQuery;

  @override
  State<JeontongKeywordSearchBar> createState() =>
      _JeontongKeywordSearchBarState();
}

class _JeontongKeywordSearchBarState extends State<JeontongKeywordSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: _clear,
          ),
          hintText: '카테고리·키워드 검색 (예: 재물, A01, 정재)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
