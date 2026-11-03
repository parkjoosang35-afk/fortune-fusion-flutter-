// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_result_screen.dart
// [신통방통 궁합지도 개발 지시서 §2④/§3] 궁합 결과 화면(초대자 본인 전용).
//
// 도달 경로: `GunghapInviteScreen._checkStatus()`에서 상대방이 이미
// 참여한 것이 확인되면 push된다. `resultId`만 전달받고, 이 화면이
// 직접 `GunghapProvider.fetchResult(resultId)`를 호출해 데이터를
// 가져온다(인증 필수·소유자 전용 API — AuthTokenStore.authHeader()가
// 자동으로 포함됨, GunghapRepository.fetchResult 참고).
//
// [과금 원칙 — 절대 준수] 상세 보고서 비용은 100 복주머니 고정이며,
// 서버(`/unlock`)가 멱등이다. 이 화면은 `result['unlocked'] == true`
// 여부만 보고 잠금해제 CTA 노출 여부를 결정한다 — 이미 해금된 경우
// 버튼 자체를 숨기므로 재열람 시 중복 호출/중복 차감 경로가 UI
// 레벨에서도 존재하지 않는다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/widgets/app_toast.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';
import '../application/gunghap_provider.dart';
import '../domain/gunghap_data.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/cat_icon.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';

class GunghapResultScreen extends StatefulWidget {
  const GunghapResultScreen({super.key, required this.resultId});
  final String resultId;

  @override
  State<GunghapResultScreen> createState() => _GunghapResultScreenState();
}

class _GunghapResultScreenState extends State<GunghapResultScreen> {
  bool _loading = true;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<GunghapProvider>();
    final ok = await provider.fetchResult(widget.resultId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      final code = provider.errorCode;
      if (code == 'UNAUTHORIZED') {
        AppToast.show(context, '로그인이 필요합니다.', isError: true);
        Navigator.of(context).pushNamed('/login');
      } else if (code == 'FORBIDDEN') {
        AppToast.show(context, '이 결과를 열람할 권한이 없습니다.', isError: true);
      } else {
        AppToast.show(context, provider.error ?? '결과를 불러올 수 없습니다.', isError: true);
      }
    }
  }

  Future<void> _unlock() async {
    final provider = context.read<GunghapProvider>();
    final pouch = context.read<LuckPouchProvider>();
    setState(() => _unlocking = true);
    final ok = await provider.unlock(widget.resultId);
    if (!mounted) return;
    setState(() => _unlocking = false);

    if (!ok) {
      if (provider.errorCode == 'INSUFFICIENT_BALANCE') {
        AppToast.show(context, '복주머니가 부족합니다. 복주머니를 모아 다시 시도해 주세요.', isError: true);
      } else {
        AppToast.show(context, provider.error ?? '잠금해제에 실패했습니다.', isError: true);
      }
      return;
    }
    // [재화 단일화 원칙] 서버 원장을 다시 조회해 앱 전역 잔액 표시를
    // 동기화한다(GunghapProvider는 결제를 직접 다루지 않음 — 파일 상단
    // 주석/GunghapProvider.unlock() 문서 참고).
    await pouch.load();
    if (!mounted) return;
    AppToast.show(context, '상세 보고서가 열렸어요.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();
    final result = provider.result;

    return GHScreen(
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(title: '궁합 결과', onBack: () => Navigator.of(context).pop()),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(color: GHColors.gold)),
            )
          : result == null
              ? _ErrorState(onRetry: () {
                  setState(() => _loading = true);
                  _load();
                })
              : _ResultBody(
                  result: result,
                  unlocking: _unlocking,
                  onUnlock: _unlock,
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Column(
      children: [
        Text(
          '결과를 불러오지 못했어요.',
          style: GHText.ui(size: 14, color: GHColors.gray),
        ),
        const SizedBox(height: 16),
        GHButton(label: '다시 시도', onPressed: onRetry, expand: false),
      ],
    ),
  );
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.result,
    required this.unlocking,
    required this.onUnlock,
  });
  final Map<String, dynamic> result;
  final bool unlocking;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final ownerName = result['ownerName'] as String? ?? '나';
    final guestName = result['guestName'] as String? ?? '상대방';
    final relationTypeLabel = result['relationTypeLabel'] as String?;
    final relationTypeDesc = result['relationTypeDesc'] as String?;
    final grade = result['grade'] as String?;
    final chemistryScore = result['chemistryScore'];
    final unlocked = result['unlocked'] == true;
    final unlockCost = (result['unlockCost'] as num?)?.toInt() ?? 100;
    final categoriesRaw = result['categories'];
    final categories = categoriesRaw is List
        ? categoriesRaw.whereType<Map>().toList()
        : const <Map>[];
    final detailRaw = result['detail'];
    final detail = detailRaw is List ? detailRaw.whereType<Map>().toList() : const <Map>[];
    final detailByCategory = {
      for (final d in detail)
        if (d['categoryId'] != null) d['categoryId'] as String: d,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GHSteps(step: 4, labels: ['분야', '나', '상대', '분석']),
        GHTitle(
          mono: 'STEP 04 · RESULT',
          title: '$ownerName님과 $guestName님의\n궁합 결과예요',
          center: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: StarMap(aName: ownerName, bName: guestName, draw: true),
          ),
        ),
        const SizedBox(height: 10),
        GHCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (grade != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: GHColors.gold.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: GHColors.gold),
                      ),
                      child: Text(
                        grade,
                        style: GHText.ui(size: 13, weight: FontWeight.w800, color: GHColors.gold),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (chemistryScore != null)
                    Text(
                      '$chemistryScore점',
                      style: GHText.ui(size: 13, weight: FontWeight.w700, color: GHColors.ivory),
                    ),
                ],
              ),
              if (relationTypeLabel != null) ...[
                const SizedBox(height: 10),
                Text(relationTypeLabel, style: GHText.cardTitle(size: 16)),
              ],
              if (relationTypeDesc != null) ...[
                const SizedBox(height: 6),
                Text(
                  relationTypeDesc,
                  style: GHText.ui(size: 13, height: 1.6, color: GHColors.gray),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        GHSectionHead(mono: 'FREE RESULT', title: '8개 분야 궁합 등급'),
        for (final c in categories) ...[
          _CategoryRow(
            categoryId: c['categoryId'] as String?,
            grade: c['grade'] as String?,
            detail: detailByCategory[c['categoryId']],
            unlocked: unlocked,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        if (!unlocked) ...[
          GHCard(
            borderRadius: GHRadius.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('상세 궁합 보고서', style: GHText.cardTitle(size: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '8개 분야 각각 관계 특징 · 잘 맞는 부분 · 갈등 가능성 ·\n'
                  '관계 개선 방향까지, 실제 사주 풀이를 바탕으로 한\n'
                  '전체 보고서를 확인할 수 있어요.',
                  style: GHText.ui(size: 13, height: 1.6, color: GHColors.gray),
                ),
                const SizedBox(height: 16),
                GHButton(
                  label: unlocking ? '잠금해제하는 중…' : '상세 보고서 잠금해제하기',
                  onPressed: unlocking ? null : onUnlock,
                  trailing: GHPricePill(unlockCost),
                ),
              ],
            ),
          ),
        ] else ...[
          const GHSectionHead(mono: 'DETAIL REPORT', title: '상세 궁합 보고서'),
          for (final c in categories) ...[
            _DetailCard(
              categoryId: c['categoryId'] as String?,
              detail: detailByCategory[c['categoryId']],
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.categoryId,
    required this.grade,
    required this.detail,
    required this.unlocked,
  });
  final String? categoryId;
  final String? grade;
  final Map? detail;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final major = ghMajorById(categoryId);
    return GHCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: GHRadius.cardSm,
      minHeight: 60,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GHColors.gold.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GHColors.divider),
            ),
            alignment: Alignment.center,
            child: CatIcon(kind: major.icon, size: 28, active: unlocked),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(major.name, style: GHText.cardTitle(size: 14.5)),
          ),
          if (grade != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: GHColors.cardSolid,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: GHColors.lineSoft),
              ),
              child: Text(
                grade!,
                style: GHText.ui(size: 12.5, weight: FontWeight.w700, color: GHColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.categoryId, required this.detail});
  final String? categoryId;
  final Map? detail;

  @override
  Widget build(BuildContext context) {
    final major = ghMajorById(categoryId);
    if (detail == null) {
      return GHCard(
        child: Text(
          '${major.name} 상세 데이터를 불러오지 못했습니다.',
          style: GHText.ui(size: 13, color: GHColors.gray),
        ),
      );
    }
    final relationshipFeature = detail!['relationshipFeature'] as String?;
    final strength = detail!['strength'] as String?;
    final conflictRisk = detail!['conflictRisk'] as String?;
    final improvement = detail!['improvement'] as String?;

    return GHCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GHColors.gold.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GHColors.divider),
                ),
                alignment: Alignment.center,
                child: CatIcon(kind: major.icon, size: 24, active: true),
              ),
              const SizedBox(width: 10),
              Text(major.name, style: GHText.reportSection()),
            ],
          ),
          const SizedBox(height: 14),
          if (relationshipFeature != null)
            _DetailSection(label: '두 사람의 관계 특징', body: relationshipFeature),
          if (strength != null)
            _DetailSection(label: '잘 맞는 부분', body: strength),
          if (conflictRisk != null)
            _DetailSection(label: '갈등 가능성', body: conflictRisk),
          if (improvement != null)
            _DetailSection(label: '관계 개선 방향', body: improvement, last: true),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.label, required this.body, this.last = false});
  final String label;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('◇ ', style: TextStyle(fontSize: 9, color: GHColors.gold)),
            Text(label, style: GHText.ui(size: 12.5, weight: FontWeight.w700, color: GHColors.gold)),
          ],
        ),
        const SizedBox(height: 6),
        Text(body, style: GHText.reportBody()),
      ],
    ),
  );
}
