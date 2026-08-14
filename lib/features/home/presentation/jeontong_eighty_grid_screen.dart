import 'package:flutter/material.dart';

import '../data/jeontong_history_store.dart';
import '../domain/jeontong_eighty_matrix.dart';

/// [정통사주 80종 그리드 신설] 8개 섹션(A~H) × 10종 카테고리를 한 화면에서
/// 항상 펼쳐진 상태로 노출하고, 진입 시점에 80종 전체를 1회 일괄
/// [JeontongHistoryStore]에 기록(pre-record)하는 전용 화면.
///
/// [STEP 0-C/0-E raw 확인 결과] 코드베이스에는 이미 동일 목적(8개 대카테고리
/// 아코디언 + 소카테고리 10개씩 탭 → 결과 진입)의 화면
/// [JeontongEightyScreen](lib/features/home/presentation/jeontong_eighty_screen.dart)이
/// 존재하며, 라우트 `/jeontong/eighty`(= [JeontongEightyMatrix.browseRoute])로
/// 이미 홈 화면 "운세" 카드에 연결되어 실사용 중이다(AccessChecker 기반
/// 프리패스 게이트/잠금 아이콘 등 부가 기능 포함). 이 미션이 요구하는
/// "80종 카테고리 그리드 신설"의 핵심 신규 기능은 UI가 아니라 "세션 진입
/// 시점 80개 일괄 record"이므로, 기존 `/jeontong/eighty` 라우트/화면은
/// 절대 건드리지 않고(회귀 위험 0), 이 화면은 별도의 신규 라우트
/// `/jeontong/eighty/grid`로만 추가한다.
///
/// [백엔드/게이트 원칙 준수] 이 화면 자체는 게이트 재검증을 하지 않는다
/// (기존 결과 화면과 동일하게 "게이트는 진입 전에" 원칙을 따르되, 이
/// 화면은 진입 자체에 게이트가 없는 순수 열람/사전기록용 화면이다).
/// 개별 카테고리 탭 시에는 기존 `JeontongEightyMatrix.resultRoute`로
/// 그대로 이동한다(결과 화면 자체는 무수정 — categoryId만 String으로 전달,
/// 기존 [JeontongEightyScreen]과 동일한 네비게이션 계약 재사용).
///
/// dart:core 전용 in-memory 기록만 수행 — HTTP/AI/파일/랜덤 호출 없음.
/// [DateTime.now()]는 initState에서 1줄(전체 80건이 동일 타임스탬프를
/// 공유)로만 사용한다.
class JeontongEightyGridScreen extends StatefulWidget {
  const JeontongEightyGridScreen({super.key, required this.userId});

  final String userId;

  @override
  State<JeontongEightyGridScreen> createState() =>
      _JeontongEightyGridScreenState();
}

class _JeontongEightyGridScreenState extends State<JeontongEightyGridScreen> {
  @override
  void initState() {
    super.initState();
    // [세션 진입 시점 80개 일괄 record] 이 화면(그리드) 진입 자체가 "이번
    // 사용자가 80종 전체를 한 번에 훑어봤다"는 의미이므로, 개별 결과 화면
    // 진입을 기다리지 않고 진입 즉시 80건을 한꺼번에 기록한다.
    final now = DateTime.now().toUtc();
    for (final entry in JeontongEightyMatrix.all) {
      JeontongHistoryStore.instance.record(
        userId: widget.userId,
        categoryId: entry.id,
        title: entry.title,
        subtitle: entry.major.title,
        createdAtUtc: now,
      );
    }
  }

  void _openResult(String categoryId) {
    Navigator.of(
      context,
    ).pushNamed(JeontongEightyMatrix.resultRoute, arguments: categoryId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('정통사주 80종')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: JeontongEightyMatrix.groups.length,
        itemBuilder: (context, index) {
          final group = JeontongEightyMatrix.groups[index];
          return _SectionCard(group: group, onTapItem: _openResult);
        },
      ),
    );
  }
}

/// 대카테고리 1개 섹션 — 헤더 + 소카테고리 10개를 2열 그리드로 항상 펼쳐
/// 보여준다(별도 접기/펼치기 없음 — "그리드" 화면의 취지에 맞춰 전체 80종을
/// 스크롤만으로 즉시 훑어볼 수 있게 함).
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.group, required this.onTapItem});

  final JeontongMajorGroup group;
  final void Function(String categoryId) onTapItem;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group.code.letter}. ${group.code.title}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, i) {
                final entry = group.items[i];
                return InkWell(
                  onTap: () => onTapItem(entry.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          entry.id,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
