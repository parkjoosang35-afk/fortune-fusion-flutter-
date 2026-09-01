import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';
import '../widgets/guinji_ui_kit.dart';

/// I · Input — `/guinji/new`
///
/// [design_handoff_guinji_web/Guinji Section.html] 1341~1436줄 마크업을
/// 재현한다. 별명·생년월일(3분할)·양음력 칩·태어난 시간(모름 토글)을
/// 입력받아 "다음"을 누르면 C(Calculating)로 이동한다.
///
/// [로그인 게이트] L(Landing)에서는 로그인 없이 진입 가능했지만, 실제
/// "지도 생성"(POST /guinji/maps)은 인증이 필요하다. 이 화면 자체는 입력
/// UI만 제공하고, 다음 버튼을 눌러 실제 지도 생성을 시도하는 시점에
/// `GuinjiProvider.createMapForUser`가 인증 여부를 확인하도록 위임한다
/// (호출부에서 로그인 안내를 처리 — 이번 화면은 UI 뼈대에 집중).
class GuinjiInputScreen extends StatefulWidget {
  const GuinjiInputScreen({super.key});

  static const routeName = '/guinji/new';

  @override
  State<GuinjiInputScreen> createState() => _GuinjiInputScreenState();
}

class _GuinjiInputScreenState extends State<GuinjiInputScreen> {
  final _nicknameController = TextEditingController();
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();

  int _calendarIndex = 0; // 0=양력, 1=음력, 2=음력(윤달)
  bool _timeUnknown = false;

  static const _calendarChips = ['양력', '음력', '음력 (윤달)'];

  @override
  void dispose() {
    _nicknameController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        bgAlignment: const Alignment(0, -0.6),
        bgOpacity: 0.1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuinjiTopBar(
              breadcrumb: 'I · INPUT',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GuinjiTitleBlock(
                      titleSpans: [
                        TextSpan(text: '당신의\n'),
                        TextSpan(
                          text: '사주',
                          style: TextStyle(color: GuinjiColors.lavender),
                        ),
                        TextSpan(text: '를 알려주세요'),
                      ],
                      subtitle: '오행의 결을 정확히 짚기 위해 필요합니다.',
                    ),
                    GuinjiField(
                      label: '별명',
                      required: true,
                      hint: '최대 24자 · 지도에 표시됩니다',
                      controller: _nicknameController,
                      placeholder: '어떻게 불릴까요',
                      maxLength: 24,
                    ),
                    GuinjiField(
                      label: '생년월일',
                      required: true,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 14,
                            child: GuinjiInputBox(
                              controller: _yearController,
                              placeholder: '1998',
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GuinjiInputBox(
                              controller: _monthController,
                              placeholder: '05',
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GuinjiInputBox(
                              controller: _dayController,
                              placeholder: '14',
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GuinjiField(
                      label: '달력',
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < _calendarChips.length; i++)
                            GuinjiChip(
                              label: _calendarChips[i],
                              active: _calendarIndex == i,
                              onTap: () => setState(() => _calendarIndex = i),
                            ),
                        ],
                      ),
                    ),
                    GuinjiField(
                      label: '태어난 시간',
                      child: Row(
                        children: [
                          Expanded(
                            child: GuinjiInputBox(
                              controller: _hourController,
                              placeholder: '09',
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GuinjiInputBox(
                              controller: _minuteController,
                              placeholder: '20',
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 14,
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: GuinjiColors.lavender.withValues(alpha: 0.22),
                                border: Border.all(
                                  color: GuinjiColors.lavender.withValues(alpha: 0.5),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '辰時',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: GuinjiColors.lavender,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GuinjiToggle(
                      label: '태어난 시간을 몰라요',
                      description: '3기둥으로 계산 (정확도 다소 낮아짐)',
                      value: _timeUnknown,
                      onChanged: (v) => setState(() => _timeUnknown = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GuinjiPrimaryButton(
              label: '다음',
              onPressed: () {
                Navigator.of(context).pushNamed('/guinji/calc');
              },
            ),
          ],
        ),
      ),
    );
  }
}
