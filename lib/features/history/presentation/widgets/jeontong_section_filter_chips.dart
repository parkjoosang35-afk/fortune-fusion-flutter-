import 'package:flutter/material.dart';

/// [정통사주 한눈에 미리보기] 8개 섹션(A~H) + "전체" 필터 칩 가로 리스트.
///
/// [STEP 0 raw 로 확정 — 미션 템플릿과의 차이]
/// 미션 스펙 중 이 위젯 안에 "한눈에 미리보기" TextButton도 동봉하라는
/// 항목이 있었으나, 바로 뒤에 명시된 이 클래스의 생성자 계약
/// (`{required onChanged, required activeLetter}`)에는 그 버튼을 위한
/// 파라미터가 전혀 없다 — 즉 "한눈에 미리보기" 진입 버튼은 실제로는
/// history_readonly_screen.dart(STEP 1-C, 정통사주 탭 진입점)에 두는 것이
/// 스펙 전체 맥락과 일치한다(이 위젯은 이미 진입한 후의 overview 화면
/// 내부에서만 쓰이므로 "미리보기 진입" 버튼이 자기 자신 안에 있을 이유가
/// 없음). 이 위젯은 생성자 계약 그대로 필터 칩 9개만 담당한다.
///
/// dart:io/HTTP/Socket/File/Random/DateTime.now() 사용 0건.
class JeontongSectionFilterChips extends StatelessWidget {
  const JeontongSectionFilterChips({
    super.key,
    required this.onChanged,
    required this.activeLetter,
  });

  final ValueChanged<String> onChanged;

  /// '전체' 또는 'A'..'H'.
  final String activeLetter;

  static const List<String> _letters = [
    '전체', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _letters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final letter = _letters[index];
          final selected = letter == activeLetter;
          return FilterChip(
            label: Text(letter),
            selected: selected,
            onSelected: (_) => onChanged(letter),
          );
        },
      ),
    );
  }
}
