import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/my_fortune_record_store.dart';
import '../../saju_renewal/data/models/topic_card.dart';
import '../../saju_renewal/navigation/saju_dimension_transition.dart';
import '../../saju_renewal/screens/story_preview_screen.dart';
import '../../saju_renewal/state/saju_renewal_provider.dart';
import 'theme/mypage_archive_widgets.dart';

/// [오늘의 운세 표준 플로우] §6 후속연결 "저장 → 마이 → 내 운세 기록에 카드 저장"의
/// 실제 조회 화면. 카테고리 무관 공용 저장소([MyFortuneRecordStore])를 그대로
/// 읽어오므로, 사주/궁합/타로 등 다른 카테고리에서 저장한 기록도 함께 노출된다.
///
/// [마이페이지 리뉴얼 · DEV 2026-10-11] 마이페이지 "사주 히스토리" 카드가
/// 기존에는 정통사주 실행 화면(`/saju-renewal`)으로 바로 이동해 기록 목록이
/// 아예 보이지 않는 버그가 있었다. 전용 사주 기록 목록 화면을 새로 만드는
/// 대신(§B안), 이미 있는 이 공용 기록 화면을 [categoryFilter]로 재사용해
/// "사주" 카테고리만 걸러 보여준다 — 신규 화면/저장소를 만들지 않고 기존
/// 인프라를 그대로 확장하는 방식(B안 범위 최소화 원칙).
///
/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S06/S08] design_handoff_mypage_
/// minimal.zip README "S06 운세 보관함 목록(공용)"/"S08 빈 상태" 스펙에
/// 따라 Minimal 테마 공용 위젯([MyPageArchiveScaffold]/[MyPageArchiveRow]/
/// [MyPageArchiveEmptyState])으로 리스킨한다. 데이터 조회 로직
/// ([MyFortuneRecordStore], [_load]) 자체는 전혀 변경하지 않는다 — "로직은
/// 그대로, 스킨만 교체" 원칙(§S02~S05와 동일).
class MyFortuneRecordsScreen extends StatefulWidget {
  const MyFortuneRecordsScreen({super.key, this.categoryFilter});

  /// null이면 전체 기록, 값이 있으면 해당 카테고리만 필터링해 보여준다.
  /// 예: '사주'.
  final String? categoryFilter;

  @override
  State<MyFortuneRecordsScreen> createState() => _MyFortuneRecordsScreenState();
}

class _MyFortuneRecordsScreenState extends State<MyFortuneRecordsScreen> {
  List<SavedFortuneRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final filter = widget.categoryFilter;
    final list = filter != null
        ? await MyFortuneRecordStore.listByCategory(filter)
        : await MyFortuneRecordStore.list();
    if (!mounted) return;
    setState(() {
      _records = list;
      _loading = false;
    });
  }

  /// [마이페이지 리뉴얼 시안 "빈 화면 시안"] 사주 히스토리가 비어있을 때는
  /// 공용 문구 대신 "정통사주 보러가기" CTA가 있는 사주 전용 빈 상태를
  /// 보여준다 — 시안이 "정통사주로 가는 길은 빈 화면의 버튼으로만"이라고
  /// 명시했으므로, 이 버튼이 saju_renewal로의 유일한 경로가 된다.
  ///
  /// [§S08] README 빈 상태 CTA 표에 사주="사주 보러 가기", 운세 기록=
  /// "오늘의 운세 보러 가기"가 명시돼 있다. 기존 saju_renewal 진입 로직
  /// (탭 지점 Offset 전달)은 그대로 유지한다.
  Widget _buildEmptyState(BuildContext context) {
    final isSaju = widget.categoryFilter == '사주';
    if (!isSaju) {
      return MyPageArchiveEmptyState(
        glyph: '運\n錄',
        ctaLabel: '오늘의 운세 보러 가기 ›',
        onCta: () =>
            Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      );
    }
    return MyPageArchiveEmptyState(
      glyph: '四\n柱',
      title: '아직 저장된 사주 기록이 없어요',
      subtitle: '정통사주를 보면 결과가 이곳에 쌓여요',
      ctaLabel: '사주 보러 가기 ›',
      onCta: () => Navigator.of(context).pushNamed(
        '/saju-renewal',
        arguments: sajuCardCenterOf(context),
      ),
    );
  }

  /// 서버가 내려주는 값과 동일한 문자열 이름 — [SajuRecentStoryStore]의
  /// `_sceneFromName`과 동일한 패턴(알 수 없는 값은 life로 안전 폴백).
  SajuRenewalScene _sceneFromName(String? raw) {
    for (final s in SajuRenewalScene.values) {
      if (s.name == raw) return s;
    }
    return SajuRenewalScene.life;
  }

  /// [버그 수정 — 2026-12 "보관만 하고 안 열려" 결함] 사주 기록을 탭하면
  /// 저장된 topic 정보로 [TopicCard]를 복원해 "최근 본 이야기" 재방문
  /// 카드(`saju_renewal_home_screen.dart`의 `_openRecentStory`)와 완전히
  /// 동일한 경로로 그 이야기를 다시 연다 — `loadPreview` → 05 미리보기
  /// (이미 해제된 주제면 05가 게이트 없이 바로 07로 보낸다). 결제 게이트를
  /// 다시 거치게 하지 않는다("게이트 재통과 요구 금지" 원칙 유지).
  /// 복원에 필요한 정보가 없는 과거 레코드(이 필드 추가 이전에 저장된
  /// 것)는 안전하게 탭을 무시한다.
  void _openSajuRecord(BuildContext context, SavedFortuneRecord r) {
    final topicId = r.sajuTopicId;
    if (topicId == null || topicId.isEmpty) return;
    final topic = TopicCard(
      topicId: topicId,
      scene: _sceneFromName(r.sajuScene),
      title: r.title,
      isTiming: false,
      evidenceFactKeys: r.sajuEvidenceFactKeys ?? const [],
    );
    context.read<SajuRenewalProvider>().loadPreview(topic);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StoryPreviewScreen()));
  }

  /// [버그 수정 — 2026-12] "내 운세 기록"(사주 외 카테고리 운세) 탭 —
  /// 저장된 [genericCategoryId]로 공용 결과 화면(`/fortune/category`)을
  /// 다시 연다.
  void _openGenericRecord(BuildContext context, SavedFortuneRecord r) {
    final categoryId = r.genericCategoryId;
    if (categoryId == null || categoryId.isEmpty) return;
    Navigator.of(
      context,
    ).pushNamed('/fortune/category', arguments: categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final isSaju = widget.categoryFilter == '사주';
    final title = isSaju ? '사주 히스토리' : '내 운세 기록';
    // README §4-S01 그리드 톤: 사주=tile1(0), 운세 기록=tile4(3).
    final tileIndex = isSaju ? 0 : 3;

    return MyPageArchiveScaffold(
      title: title,
      itemCount: _loading ? null : _records.length,
      isLoading: _loading,
      onRefresh: _load,
      body: _loading
          ? const MyPageArchiveLoadingPlaceholder()
          : _records.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                for (final r in _records)
                  MyPageArchiveRow(
                    glyph: isSaju ? '四' : '錄',
                    tileIndex: tileIndex,
                    dateLabel:
                        '${r.date.year} · ${r.date.month.toString().padLeft(2, '0')} · ${r.date.day.toString().padLeft(2, '0')}',
                    title: r.title,
                    summary: r.summary,
                    onTap: isSaju
                        ? () => _openSajuRecord(context, r)
                        : () => _openGenericRecord(context, r),
                  ),
              ],
            ),
    );
  }
}
