import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/result_card_stack.dart';
import '../../sintong/theme/sintong_colors.dart';
import '../../sintong/theme/sintong_typography.dart';
import '../../sintong/widgets/hanja_stamp.dart';
import '../../sintong/widgets/sintong_screen_bg.dart';
import '../application/face_provider.dart';
import '../domain/face_model.dart';

/// [관상·손금 신통방통 "새벽 한지" 리스킨] 관상 결과 화면.
///
/// [기존 시스템 유지 원칙] 결과 페이지 표준 스켈레톤인 [ResultCardStack]은
/// 사주/타로 결과 화면과 공유되는 컴포넌트이므로 내부 구조·스타일은 그대로
/// 유지한다(사용자 승인 #1). 이 화면에서는 바깥쪽 배경/상단바만 Dawn Hanji
/// 톤(한지 배경 + 觀 인장 + 하자 라벨)으로 감싸고, [ResultCardStack]은 그
/// 안에 "종이 위에 올려진 리포트 카드"처럼 얹는 방식으로 리스킨한다.
class FaceResultScreen extends StatefulWidget {
  final String? resultId;
  const FaceResultScreen({super.key, this.resultId});

  @override
  State<FaceResultScreen> createState() => _FaceResultScreenState();
}

/// 주제별 라인 아이콘 매핑(이모지 대체)
const Map<String, IconData> _topicIcons = {
  '재물': Icons.payments_outlined,
  '애정': Icons.favorite_outline_rounded,
  '직업': Icons.work_outline_rounded,
  '건강': Icons.health_and_safety_outlined,
};

class _FaceResultScreenState extends State<FaceResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<FaceProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaceProvider>();
    final state = provider.state;
    // [홈으로 돌아가기 — 사주/타로와 동일한 패턴] 이 화면은 항상 push 스택
    // 위에서 열리므로 canPop이 대체로 true이지만, 방어적으로 확인 후에만
    // 뒤로가기 버튼을 렌더링한다.
    final canGoBack = Navigator.canPop(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SintongScreenBg()),
          SafeArea(
            child: Column(
              children: [
                _ResultTopBar(
                  hanja: '觀',
                  hanjaColor: SintongColors.stampGuan,
                  title: '觀相 · REPORT',
                  onBack: canGoBack
                      ? () => Navigator.of(context).pop()
                      : null,
                  onShare: state.isSuccess
                      ? () => AppToast.show(context, '공유 링크가 복사되었습니다.')
                      : null,
                ),
                Expanded(
                  child: _PaperSheet(
                    child: switch (state.status) {
                      LoadStatus.loading => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      LoadStatus.error => AppErrorState(
                        message: state.errorMessage ?? '분석에 실패했습니다.',
                        onRetry: () => provider.retry(),
                      ),
                      LoadStatus.success => _buildResult(context, state.data!),
                      LoadStatus.initial => const AppErrorState(
                        message: '입력 정보가 없습니다.',
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, FaceResultModel result) {
    final topicEntries = result.topicResults.entries
        .where((e) => e.key != '종합')
        .toList();

    return ResultCardStack(
      heroCaption: '종합 관상 해석',
      heroSummary: result.summary,
      sectionTitle: '세부 리포트',
      sections: [
        ...result.features.entries.map(
          (e) => ResultSection(title: e.key, body: e.value),
        ),
        ...topicEntries.map(
          (e) => ResultSection(
            title: e.key,
            body: e.value,
            trailing: Icon(
              _topicIcons[e.key] ?? Icons.auto_awesome_outlined,
              size: 20,
              color: Colors.black45,
            ),
          ),
        ),
      ],
      ctas: [
        ResultCta(
          label: '다시 분석하기',
          icon: Icons.refresh_rounded,
          onTap: () =>
              Navigator.of(context).pushNamed('/ai-fortune/face/capture'),
        ),
        ResultCta(
          label: '히스토리 보기',
          icon: Icons.history_rounded,
          onTap: () =>
              Navigator.of(context).pushNamed('/ai-fortune/face/history'),
        ),
      ],
    );
  }
}

/// 결과 화면 공용 상단바. 한지 배경 위에 얹혀 뒤로가기/하자 인장/타이틀/공유를
/// 표시한다. [face_result_screen.dart]/[palm_result_screen.dart]가 각각
/// 자기 파일 안에 동일한 위젯을 두어 서로 독립적으로 유지보수 가능하게 한다.
class _ResultTopBar extends StatelessWidget {
  const _ResultTopBar({
    required this.hanja,
    required this.hanjaColor,
    required this.title,
    this.onBack,
    this.onShare,
  });

  final String hanja;
  final Color hanjaColor;
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          if (onBack != null)
            _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: onBack!)
          else
            const SizedBox(width: 36),
          const SizedBox(width: 10),
          HanjaStamp(text: hanja, size: 28, color: hanjaColor, rotation: -6),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: SintongType.monoSm.copyWith(color: SintongColors.accent),
            ),
          ),
          if (onShare != null)
            _CircleIconButton(icon: Icons.ios_share_rounded, onTap: onShare!)
          else
            const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SintongColors.card,
          border: Border.all(color: SintongColors.line),
        ),
        child: Icon(icon, size: 18, color: SintongColors.fg),
      ),
    );
  }
}

/// [ResultCardStack]을 감싸는 "종이 시트" 컨테이너. 상단 모서리만 둥글게 잘라
/// 한지 배경 위에 리포트 용지가 얹힌 듯한 느낌을 준다. 내부 [child]는
/// [ResultCardStack]이 그대로 렌더링하는 흰 배경 리스트 뷰이므로, 여기서는
/// 바깥 프레임(둥근 모서리 + 은은한 그림자)만 추가하고 내부 스타일은 전혀
/// 건드리지 않는다.
class _PaperSheet extends StatelessWidget {
  const _PaperSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: SintongColors.sigil.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
