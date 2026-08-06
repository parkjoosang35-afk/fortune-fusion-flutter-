import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/fortune/fortune_loading_screen.dart';
import '../../../../core/widgets/fortune/primary_cta.dart';
import '../application/daily_fortune_provider.dart';
import '../domain/fortune_report_model.dart';

/// [버그 수정] 로딩 실패 시 원인과 무관하게 항상 "네트워크 상태를 확인해주세요"로
/// 보였던 문제 대응. Provider의 실제 [lastError] 문구를 우선 노출한다.
///
/// [무료 광고형 구조 재정비 §신규발견] "오늘의 운세"는 더 이상 복주머니(포인트)를
/// 소비하지 않는다(백엔드 fortune/daily API에서 차감 로직 제거 완료). 따라서 이
/// 화면에서도 "포인트 부족" 관련 분기와 "복주머니 충전하기" CTA(→/reward/wallet)를
/// 제거했다 — 실패는 항상 네트워크/서버 오류로만 처리하고 "다시 시도"로 안내한다.

/// [오늘의 운세 표준 플로우] §3 로딩 화면 — /fortune/today/loading
///
/// 재사용 위젯 [FortuneLoadingScreen]에 오늘의 운세 API 호출(task)을 주입한다.
/// 실패 시 §7 상태처리 스펙대로 재시도 다이얼로그를 띄운다.
class DailyFortuneLoadingScreen extends StatelessWidget {
  const DailyFortuneLoadingScreen({super.key, required this.input});

  final FortuneInputModel input;

  @override
  Widget build(BuildContext context) {
    return FortuneLoadingScreen<bool>(
      task: () => context.read<DailyFortuneProvider>().loadToday(),
      subCard: '잠시만요, 오늘의 흐름을 분석하고 있어요',
      onComplete: (success) {
        if (success) {
          Navigator.of(
            context,
          ).pushReplacementNamed('/fortune/today/result', arguments: input);
        } else {
          final message = context.read<DailyFortuneProvider>().lastError;
          _showRetryDialog(context, message);
        }
      },
      onError: (_) => _showRetryDialog(context, null),
    );
  }

  void _showRetryDialog(BuildContext context, String? errorMessage) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: UnifiedColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        ),
        title: Text('결과를 불러오지 못했어요', style: UnifiedText.title()),
        content: Text(
          errorMessage ?? '네트워크 상태를 확인한 뒤 다시 시도해주세요.',
          style: UnifiedText.body(),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          UnifiedTokens.spaceXl,
          0,
          UnifiedTokens.spaceXl,
          UnifiedTokens.spaceXl,
        ),
        actions: [
          PrimaryCTA(
            label: '다시 시도',
            height: 44,
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(
                context,
              ).pushReplacementNamed('/fortune/today/loading', arguments: input);
            },
          ),
        ],
      ),
    );
  }
}
