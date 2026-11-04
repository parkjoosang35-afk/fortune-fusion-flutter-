/// [기간별 운세 — 화면 A'] 마이 › 사주정보 확인/수정 진입점.
///
/// `design_handoff_fortune_v4/design_files/saju-my.jsx`의 `MySajuScreen` +
/// `ConfirmEditSheet`를 백자 팔레트로 재현한다. 사주정보가 있으면
/// 정의목록(dl) 형태로 보여주고 "사주정보 고치기" 버튼, 없으면 빈 상태
/// CTA("사주정보 담기")를 보여준다.
///
/// [기존 메뉴 보존 원칙] 이 화면은 마이페이지의 새 진입점(메뉴 1개 추가)
/// 으로만 연결되며, 기존 마이페이지의 다른 항목/레이아웃은 변경하지
/// 않는다.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_provider.dart';
import '../domain/fortune_saju_profile.dart';
import '../theme/fortune_period_theme.dart';
import '../widgets/fortune_common_widgets.dart';
import '../widgets/fortune_seal.dart';
import 'saju_input_screen.dart';

class MySajuInfoScreen extends StatelessWidget {
  const MySajuInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final hasSaju = isFortuneSajuComplete(user);

    return Scaffold(
      backgroundColor: FortunePeriodColors.bg1,
      appBar: AppBar(
        backgroundColor: FortunePeriodColors.bg1,
        elevation: 0,
        foregroundColor: FortunePeriodColors.fg,
        title: const Text(
          '나의 사주정보',
          style: TextStyle(
            fontFamily: FortunePeriodType.serif,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: FortunePeriodColors.fg,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MY · 命', style: FortunePeriodType.mono10),
              const SizedBox(height: 10),
              const Text(
                '나의 사주정보',
                style: TextStyle(
                  fontFamily: FortunePeriodType.serif,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  height: 1.3,
                  color: FortunePeriodColors.fg,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '오늘 · 주간 · 월간 운세가\n모두 이 사주로 풀려요',
                style: TextStyle(
                  fontFamily: FortunePeriodType.body,
                  fontSize: 13.5,
                  height: 1.7,
                  color: FortunePeriodColors.muted,
                ),
              ),
              const SizedBox(height: 22),

              if (hasSaju && user != null)
                FortuneCard(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                  child: Column(
                    children: [
                      _dlRow('생년월일', _formatDate(user.birthDate)),
                      _dlRow(
                        '양력 · 음력',
                        user.isLunar
                            ? '음력${user.isLeapMonth ? ' · 윤달' : ' · 평달'}'
                            : '양력',
                      ),
                      _dlRow(
                        '태어난 시',
                        user.birthTimeUnknown
                            ? '모름'
                            : _timeDisplay(user.birthTime),
                        isLast: false,
                      ),
                      _dlRow(
                        '성별',
                        user.gender == 'female' ? '여성' : '남성',
                        isLast: true,
                      ),
                      const SizedBox(height: 16),
                      FortuneSecondaryButton(
                        label: '사주정보 고치기',
                        onPressed: () => _goEdit(context),
                      ),
                    ],
                  ),
                )
              else
                FortuneCard(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '아직 사주정보가 담기지 않았어요',
                          style: TextStyle(
                            fontFamily: FortunePeriodType.body,
                            fontSize: 14,
                            color: FortunePeriodColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FortunePrimaryButton(
                        label: '🕯 사주정보 담기',
                        onPressed: () => _goEdit(context),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),
              const Text(
                '사주정보를 고치면 이전에 풀이된 운세는 지워지고\n새 사주 기준으로 다시 풀어드려요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: FortunePeriodType.body,
                  fontSize: 12.5,
                  height: 1.7,
                  color: FortunePeriodColors.muted,
                ),
              ),

              if (hasSaju) ...[
                const SizedBox(height: 18),
                FortuneGhostButton(
                  label: '☾ 오늘의 운세 보러 가기',
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/fortune-period'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goEdit(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    final hasSaju = isFortuneSajuComplete(user);
    if (hasSaju) {
      final confirmed = await showFortuneConfirmEditSheet(context);
      if (confirmed != true || !context.mounted) return;
    }
    if (!context.mounted) return;
    // [버그 수정 — 2026-11 Screen A 실동작 검증 중 발견] hasSaju가
    // false(최초 등록)일 때도 항상 mode: edit로 열려, SajuInputScreen의
    // "FIRST VISIT" 타이틀/policy-note 대신 edit 모드 UI(변경분만 활성화되는
    // 저장 버튼 등)가 떠버리는 결함이 있었다. hasSaju 여부에 따라
    // first/edit 모드를 정확히 분기한다.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SajuInputScreen(
          mode: hasSaju ? SajuInputMode.edit : SajuInputMode.first,
        ),
      ),
    );
  }

  Widget _dlRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : FortunePeriodColors.line,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: FortunePeriodType.dt),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: FortunePeriodType.dd,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return '';
    final parts = birthDate.split('-');
    if (parts.length != 3) return birthDate;
    return '${parts[0]}. ${parts[1]}. ${parts[2]}';
  }

  String _timeDisplay(String? birthTime) {
    final zhi = zhiTimeForBirthTime(birthTime);
    if (zhi == null) return '모름';
    return '${zhi.hanja} ${zhi.label} (${zhi.hint})';
  }
}

/// `ConfirmEditSheet` — 사주정보를 고치면 기존 운세가 지워진다는 확인
/// 바텀시트. 확인 시 true, 취소 시 false/null을 반환한다.
Future<bool?> showFortuneConfirmEditSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
          decoration: const BoxDecoration(
            color: FortunePeriodColors.bg1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: FortunePeriodColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const FortuneSeal(text: '改', size: 40),
              const SizedBox(height: 16),
              const Text(
                '사주정보를\n고쳐 담을까요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: FortunePeriodType.serif,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  height: 1.45,
                  color: FortunePeriodColors.fg,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '지금까지 풀이된 운세는 지워지고\n새 사주로 오늘 · 주간 · 월간 운세를 다시 풀어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: FortunePeriodType.body,
                  fontSize: 13.5,
                  height: 1.75,
                  color: FortunePeriodColors.muted,
                ),
              ),
              const SizedBox(height: 20),
              FortunePrimaryButton(
                label: '고쳐 담기',
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: 10),
              FortuneGhostButton(
                label: '다시 살펴볼게요',
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
}

