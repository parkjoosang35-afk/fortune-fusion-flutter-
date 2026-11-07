import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/lunar_calendar_util.dart';
import '../../../core/widgets/birthday_picker/birthday_picker_modal.dart';
import '../../auth/application/auth_provider.dart';
import '../../saju_renewal/data/saju_visual_adapter.dart';
import 'theme/mypage_minimal_theme.dart';
import 'theme/mypage_toast.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S13] "출생정보 수정" 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S13 출생정보 수정" 스펙
/// (전체 폭 그라디언트 사주 미리보기 밴드, 밑줄 입력, 성별/양력음력
/// 세그먼트, 태어난 시간 4×3 12지신 그리드, D2 확인 다이얼로그)에 따른
/// 전면 신규 화면이다.
///
/// [범위 결정] 기존 `BirthInputScreen`(`saju_renewal/screens/
/// birth_input_screen.dart`, 1444줄)은 isEditMode/isSignupFlow/기본값(최초
/// 정통사주 입력) 3개 모드를 공유하는 화면이고, 그중 isEditMode=true 모드만
/// 이번 README S13("마이페이지 → 설정 → 출생정보 수정")과 같은 용도다.
/// 해당 파일은 건드리지 않고(회원가입/최초입력 플로우 영향 없음), 이
/// edit-only 용도만 담당하는 새 화면을 만든다 — S03/S05/S09/S11/S12와
/// 동일한 "신규 파일 + 호출부만 교체" 패턴이다.
///
/// [로직 재사용, 스킨만 교체]
/// - 실제 사주 계산: [SajuVisualAdapter.build] (ManseryeokCoreEngine 기반
///   PHASE1~4 엔진) 그대로 호출 — 가짜 데모 사주를 보여주지 않는다. 다만
///   표시 위젯은 `SajuPillarGrid`(다크 SajuGold 톤 하드코딩)를 재사용하지
///   않고, README의 그라디언트 밴드 스펙에 맞춘 새 위젯([_PreviewBand])을
///   그린다 — 계산 로직과 표시 스킨을 분리하는 기존 원칙과 동일하다.
/// - 생년월일 입력: 8자리 키패드+검증(윤력 포함)을 새로 구현하지 않고
///   앱 전역 공용 위젯 [showBirthdayPicker]를 그대로 재사용한다(날짜
///   부분만). 이 모달은 Step2에서 시간 선택 UI도 함께 보여주지만, README
///   S13은 "태어난 시간"을 이 화면 자체의 12지신 그리드로 노출하길
///   요구하므로, 모달이 돌려주는 `BirthdayPickerValue.time`은 의도적으로
///   무시하고 연/월/일만 반영한다 — 시간의 단일 소스는 이 화면의
///   [_selectedZhi] 상태뿐이다(모달 Step2에서 시간을 건드리지 않고
///   "저장하기"를 눌러도 `requireTime:false`라 넘어갈 수 있다).
/// - 음력 검증: [LunarCalendarUtil] 그대로 사용(`birth_input_screen.dart`
///   `_lunarPickerValidator`와 동일한 로직을 이 화면에도 복제).
/// - 저장: [AuthProvider.updateProfile] 동일 시그니처 호출. 생년월일/시간/
///   음양력이 실제로 바뀐 경우에만 README "D2" 확인 다이얼로그(글리프 命)를
///   띄운 뒤 저장한다 — `birth_input_screen.dart._submit()`의
///   `birthRelatedChanged` 판정과 동일 원칙.
/// - [범위 제외] "태어난 곳"(진태양시 보정용 출생지) 필드는 README S13
///   스펙에 없어 이 화면에서 다루지 않는다. `updateProfile`에 `birthPlace`를
///   넘기지 않으므로 서버에 저장된 기존 값은 그대로 유지된다
///   (`UserModel.copyWith`가 null 인자를 "변경 없음"으로 처리).
class BirthInfoMinimalScreen extends StatefulWidget {
  const BirthInfoMinimalScreen({super.key});

  @override
  State<BirthInfoMinimalScreen> createState() =>
      _BirthInfoMinimalScreenState();
}

class _BirthInfoMinimalScreenState extends State<BirthInfoMinimalScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  String _gender = 'female';
  bool _isLunar = false;
  bool _isLeapMonth = false;

  int? _year;
  int? _month;
  int? _day;

  /// null이면 "시간 모름"과 동일하게 취급한다(아래 [_timeUnknown] 참고).
  BirthdayZhiTime? _selectedZhi;
  bool _timeUnknown = false;

  bool _submitting = false;

  SajuVisualProfile? _preview;
  Timer? _previewDebounce;

  // [출생정보 수정 기능] "실제로 바뀌었는지" 판단용 원본값.
  String? _originalBirthDate;
  String? _originalBirthTime;
  bool _originalBirthTimeUnknown = false;
  bool _originalIsLunar = false;
  bool _originalIsLeapMonth = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      if (user.nickname.trim().isNotEmpty) {
        _nicknameController.text = user.nickname.trim();
      }
      if (user.gender == 'male' || user.gender == 'female') {
        _gender = user.gender!;
      }
      _isLunar = user.isLunar;
      _isLeapMonth = user.isLunar ? user.isLeapMonth : false;

      final birthDate = user.birthDate;
      if (birthDate != null) {
        final parts = birthDate.split('-');
        if (parts.length == 3) {
          _year = int.tryParse(parts[0]);
          _month = int.tryParse(parts[1]);
          _day = int.tryParse(parts[2]);
        }
      }
      _timeUnknown = user.birthTimeUnknown;
      if (user.birthTime != null && !user.birthTimeUnknown) {
        final hour = int.tryParse(user.birthTime!.split(':').first);
        if (hour != null) {
          for (final z in kBirthdayZhiTimes) {
            if (z.rangeStart == hour) {
              _selectedZhi = z;
              break;
            }
          }
        }
      }

      _originalBirthDate = user.birthDate;
      _originalBirthTime = user.birthTime;
      _originalBirthTimeUnknown = user.birthTimeUnknown;
      _originalIsLunar = user.isLunar;
      _originalIsLeapMonth = _isLeapMonth;
    }
    _recomputePreview();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _nicknameController.dispose();
    super.dispose();
  }

  // ---------- 음력 날짜 검증 (birth_input_screen.dart와 동일 로직) ----------
  BirthdayDateValidation _lunarPickerValidator(int? y, int? m, int? d) {
    if (m != null && (m < 1 || m > 12)) {
      return const BirthdayDateValidation(
        ok: false,
        field: 'month',
        msg: '1월부터 12월까지 있어요',
      );
    }
    if (y != null) {
      final now = DateTime.now().year;
      if (y < 1900) {
        return const BirthdayDateValidation(
          ok: false,
          field: 'year',
          msg: '1900년 이후로 입력해주세요',
        );
      }
      if (y > now) {
        return BirthdayDateValidation(
          ok: false,
          field: 'year',
          msg: '$now년까지 입력할 수 있어요',
        );
      }
    }
    if (y != null &&
        m != null &&
        _isLeapMonth &&
        !LunarCalendarUtil.hasLeapMonth(y, m)) {
      final actual = LunarCalendarUtil.leapMonthOf(y);
      return BirthdayDateValidation(
        ok: false,
        field: 'month',
        msg: actual == 0 ? '$y년(음력)에는 윤달이 없어요' : '$y년(음력)은 윤$actual월만 윤달이에요',
      );
    }
    if (d != null && m != null && y != null) {
      final maxD =
          LunarCalendarUtil.daysInLunarMonth(y, m, isLeap: _isLeapMonth) ??
          29;
      if (d < 1 || d > maxD) {
        return BirthdayDateValidation(
          ok: false,
          field: 'day',
          msg: '${_isLeapMonth ? '윤$m월' : '$m월'}은 $maxD일까지 있어요',
        );
      }
    } else if (d != null) {
      if (d < 1 || d > 30) {
        return const BirthdayDateValidation(
          ok: false,
          field: 'day',
          msg: '1일부터 30일까지 있어요',
        );
      }
    }
    return BirthdayDateValidation.valid;
  }

  /// [B1/B2와 동일 원칙] 음력/윤달 설정이 바뀌어 기존에 고른 날짜가 더 이상
  /// 유효하지 않으면 날짜를 비운다.
  void _recheckDateAfterLunarToggle() {
    if (_year == null || _month == null || _day == null || !_isLunar) return;
    final validation = LunarCalendarUtil.validateLunarDate(
      year: _year!,
      month: _month!,
      day: _day!,
      isLeap: _isLeapMonth,
    );
    if (!validation.ok) {
      setState(() {
        _year = null;
        _month = null;
        _day = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final hasDate = _year != null && _month != null && _day != null;
    final result = await showBirthdayPicker(
      context,
      // README의 한지 크림 배경(#f7eedc)에 가장 가까운 기존 팔레트인
      // hanji(라이트 톤)를 사용한다 — midnight(다크)보다 Minimal 테마와
      // 위화감이 적다.
      palette: BirthdayPickerPalette.hanji,
      requireTime: false,
      initialValue: hasDate
          ? BirthdayPickerValue(
              year: _year!,
              month: _month!,
              day: _day!,
              weekday: DateTime(_year!, _month!, _day!).weekday % 7,
            )
          : null,
      title: '태어난 날을 알려주세요',
      dateValidator: _isLunar ? _lunarPickerValidator : null,
    );
    if (result == null) return;
    setState(() {
      _year = result.year;
      _month = result.month;
      _day = result.day;
      // [의도적 무시] 시간은 이 화면 자체의 12지신 그리드가 유일한 소스다
      // — 모달에서 함께 고른 시간(result.time)은 반영하지 않는다.
    });
    _schedulePreviewUpdate();
  }

  void _schedulePreviewUpdate() {
    _previewDebounce?.cancel();
    // README "값이 바뀔 때마다 미리보기를 갱신 (300ms 디바운스)".
    _previewDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(_recomputePreview);
    });
  }

  void _recomputePreview() {
    if (_year == null || _month == null || _day == null) {
      _preview = null;
      return;
    }
    final timeUnknown = _timeUnknown || _selectedZhi == null;
    final hour = _selectedZhi?.rangeStart ?? 0;
    final dt = DateTime(
      _year!,
      _month!,
      _day!,
      timeUnknown ? 0 : hour,
      0,
    );
    _preview = SajuVisualAdapter.build(
      kst: dt,
      gender: _gender,
      isLunar: _isLunar,
      isLeapMonth: _isLunar ? _isLeapMonth : false,
      timeUnknown: timeUnknown,
      referenceDate: DateTime.now(),
    );
  }

  /// README "다이얼로그 공통 (D1–D3)" 시각 스펙과 동일한 확인 다이얼로그.
  /// (settings_minimal_screen.dart의 `_showMyPageConfirmDialog`와 동일한
  /// 구현 — 공용 private 위젯을 두지 않는 각 S화면 자기완결 관례를 따른다.)
  Future<bool> _showMyPageConfirmDialog(
    BuildContext context, {
    required String glyph,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MyPageColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MyPageRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -6 * 3.14159265 / 180,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MyPageColors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    glyph,
                    style: const TextStyle(
                      fontFamily: MyPageFonts.hanja,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  height: 1.3,
                  color: MyPageColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.5,
                  color: MyPageColors.ink2,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0x122A1F14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: MyPageColors.ink2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: MyPageColors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _submit(BuildContext context) async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      showMyPageToast(context, '이름을 입력해주세요');
      return;
    }
    if (_year == null || _month == null || _day == null) {
      showMyPageToast(context, '생년월일을 선택해주세요');
      return;
    }

    final birthDateStr =
        '${_year!.toString().padLeft(4, '0')}-'
        '${_month!.toString().padLeft(2, '0')}-'
        '${_day!.toString().padLeft(2, '0')}';
    final birthTimeUnknown = _timeUnknown || _selectedZhi == null;
    final birthTimeStr = (!birthTimeUnknown && _selectedZhi != null)
        ? '${_selectedZhi!.rangeStart.toString().padLeft(2, '0')}:00'
        : null;
    final isLeapMonth = _isLunar ? _isLeapMonth : false;

    final birthRelatedChanged =
        birthDateStr != _originalBirthDate ||
        birthTimeStr != _originalBirthTime ||
        birthTimeUnknown != _originalBirthTimeUnknown ||
        _isLunar != _originalIsLunar ||
        isLeapMonth != _originalIsLeapMonth;

    if (birthRelatedChanged) {
      final confirmed = await _showMyPageConfirmDialog(
        context,
        glyph: '命',
        title: '출생정보를 바꿀까요',
        message: '저장하면 사주 풀이가\n새 정보로 다시 계산돼요',
        confirmLabel: '저장',
      );
      if (!confirmed || !context.mounted) return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      birthDate: birthDateStr,
      birthTime: birthTimeStr,
      isLunar: _isLunar,
      isLeapMonth: isLeapMonth,
      birthTimeUnknown: birthTimeUnknown,
      gender: _gender,
      nickname: nickname,
    );
    if (!context.mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      showMyPageToast(
        context,
        auth.lastProfileUpdateError ?? '출생정보를 저장하지 못했습니다. 다시 시도해주세요.',
      );
      return;
    }
    showMyPageToast(context, '출생정보를 저장했습니다.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = (_year != null && _month != null && _day != null)
        ? '$_year. ${_month.toString().padLeft(2, '0')}. '
              '${_day.toString().padLeft(2, '0')}'
        : '생년월일을 선택해주세요';

    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // README "서브화면 공통 셸" 상단바.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 40,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: MyPageColors.ink,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            '출생정보 수정',
                            textAlign: TextAlign.center,
                            style: MyPageTextStyles.header,
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
                // 사주 미리보기 밴드 — README "좌우 끝까지 꽉 채움" 요구에
                // 맞춰 subX 패딩 바깥(별도 sliver)에 둔다.
                SliverToBoxAdapter(child: _PreviewBand(profile: _preview)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    MyPageSpacing.subX,
                    0,
                    MyPageSpacing.subX,
                    140,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      const _FieldLabel('이름'),
                      _UnderlineInput(
                        controller: _nicknameController,
                        hintText: '이름을 입력해주세요',
                      ),
                      const SizedBox(height: 28),
                      const _FieldLabel('성별'),
                      _MiniSeg(
                        options: const ['여', '남'],
                        value: _gender == 'male' ? '남' : '여',
                        onChanged: (v) {
                          setState(() => _gender = v == '남' ? 'male' : 'female');
                          _schedulePreviewUpdate();
                        },
                      ),
                      const SizedBox(height: 28),
                      const _FieldLabel('생년월일'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _UnderlineTapField(
                              label: dateLabel,
                              isPlaceholder:
                                  _year == null || _month == null || _day == null,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 130,
                            child: _MiniSeg(
                              options: const ['양력', '음력'],
                              value: _isLunar ? '음력' : '양력',
                              onChanged: (v) {
                                setState(() {
                                  _isLunar = v == '음력';
                                  if (!_isLunar) _isLeapMonth = false;
                                  _recheckDateAfterLunarToggle();
                                });
                                _schedulePreviewUpdate();
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_isLunar)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isLeapMonth = !_isLeapMonth;
                                _recheckDateAfterLunarToggle();
                              });
                              _schedulePreviewUpdate();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _CheckBox(checked: _isLeapMonth),
                                const SizedBox(width: 10),
                                const Text(
                                  '윤달에 태어났어요',
                                  style: TextStyle(
                                    fontFamily: MyPageFonts.ui,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: MyPageColors.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      const _FieldLabel('태어난 시간'),
                      Opacity(
                        opacity: _timeUnknown ? 0.4 : 1,
                        child: IgnorePointer(
                          ignoring: _timeUnknown,
                          child: _ZhiTimeGrid(
                            selected: _selectedZhi,
                            onSelect: (z) {
                              setState(() => _selectedZhi = z);
                              _schedulePreviewUpdate();
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: InkWell(
                          onTap: () {
                            setState(() => _timeUnknown = !_timeUnknown);
                            _schedulePreviewUpdate();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CheckBox(checked: _timeUnknown),
                              const SizedBox(width: 10),
                              const Text(
                                '태어난 시간을 몰라요',
                                style: TextStyle(
                                  fontFamily: MyPageFonts.ui,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: MyPageColors.ink2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            // README ".dock" — 하단 고정 CTA(투명→paper 그라디언트 배경).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00F7EEDC),
                        MyPageColors.paper,
                      ],
                      stops: [0.0, 0.5],
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _submit(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MyPageColors.red,
                        disabledBackgroundColor: MyPageColors.red.withValues(
                          alpha: 0.5,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MyPageRadius.cta,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '저장하기',
                              style: TextStyle(
                                fontFamily: MyPageFonts.ui,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// README S13 "사주 미리보기 밴드" — 전체 폭 그라디언트 + 4열(시주/일주/
/// 월주/년주). 실제 계산은 [SajuVisualAdapter]가 담당하고, 이 위젯은 그
/// 결과를 README 스펙 색상으로만 그린다.
class _PreviewBand extends StatelessWidget {
  const _PreviewBand({required this.profile});
  final SajuVisualProfile? profile;

  static const _labels = ['시주', '일주', '월주', '년주'];

  @override
  Widget build(BuildContext context) {
    final pillars = profile?.pillars ?? const [null, null, null, null];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.6, -1),
          end: Alignment(0.6, 1),
          colors: [Color(0xFFA23A27), Color(0xFF5E1A12)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '四柱 미리보기',
            style: TextStyle(
              fontFamily: MyPageFonts.mono,
              fontSize: 10,
              letterSpacing: 1.5,
              color: Color(0x99FBF0D9),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(4, (i) {
              final p = pillars[i];
              // 시주(index 0)는 시간을 모르면 null — README "시주는 ?로
              // 표시"에 맞춰 둘 다 '?'로 보여준다.
              final stem = p?.stemHanja ?? (i == 0 ? '?' : '—');
              final branch = p?.branchHanja ?? (i == 0 ? '?' : '—');
              return Expanded(
                child: Container(
                  decoration: i > 0
                      ? const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Color(0x2EFBF0D9)),
                          ),
                        )
                      : null,
                  child: Column(
                    children: [
                      Text(
                        _labels[i],
                        style: const TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontSize: 10,
                          color: Color(0x99FBF0D9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stem,
                        style: const TextStyle(
                          fontFamily: MyPageFonts.hanja,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          height: 1.2,
                          color: Color(0xFFFBF0D9),
                        ),
                      ),
                      Text(
                        branch,
                        style: const TextStyle(
                          fontFamily: MyPageFonts.hanja,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          height: 1.2,
                          color: MyPageColors.gold2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: MyPageFonts.ui,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: MyPageColors.ink3,
        ),
      ),
    );
  }
}

/// README ".inp" — 밑줄 전용 입력란.
class _UnderlineInput extends StatelessWidget {
  const _UnderlineInput({required this.controller, required this.hintText});
  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 12,
      style: const TextStyle(
        fontFamily: MyPageFonts.ui,
        fontSize: 18,
        color: MyPageColors.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: MyPageFonts.ui,
          fontSize: 18,
          color: MyPageColors.ink3,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0x3F2A1F14), width: 1.5),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: MyPageColors.red, width: 1.5),
        ),
      ),
    );
  }
}

/// 탭하면 외부 피커를 여는 읽기 전용 밑줄 필드(생년월일용).
class _UnderlineTapField extends StatelessWidget {
  const _UnderlineTapField({
    required this.label,
    required this.isPlaceholder,
    required this.onTap,
  });
  final String label;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x3F2A1F14), width: 1.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: MyPageFonts.ui,
            fontSize: 18,
            color: isPlaceholder ? MyPageColors.ink3 : MyPageColors.ink,
          ),
        ),
      ),
    );
  }
}

/// README ".seg" — 공용 N옵션 세그먼트 컨트롤.
class _MiniSeg extends StatelessWidget {
  const _MiniSeg({
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0F2A1F14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((opt) {
          final selected = opt == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: MyPageMotion.fade,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? MyPageColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x1A3C230F),
                            offset: Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  style: TextStyle(
                    fontFamily: MyPageFonts.ui,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: selected ? MyPageColors.ink : MyPageColors.ink3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// README ".sj" — 4열 × 3행(총 12칸) 12지신 시간 그리드.
class _ZhiTimeGrid extends StatelessWidget {
  const _ZhiTimeGrid({required this.selected, required this.onSelect});
  final BirthdayZhiTime? selected;
  final ValueChanged<BirthdayZhiTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.35,
      children: [
        for (final z in kBirthdayZhiTimes)
          _ZhiCell(
            z: z,
            active: selected?.zhi == z.zhi,
            onTap: () => onSelect(z),
          ),
      ],
    );
  }
}

class _ZhiCell extends StatelessWidget {
  const _ZhiCell({required this.z, required this.active, required this.onTap});
  final BirthdayZhiTime z;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: active ? MyPageColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? MyPageColors.ink : MyPageColors.hair,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${z.hanja}時',
              style: TextStyle(
                fontFamily: MyPageFonts.hanja,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: active ? MyPageColors.paper : MyPageColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              z.hint.replaceAll(' ', ''),
              style: TextStyle(
                fontFamily: MyPageFonts.mono,
                fontSize: 9,
                color: active
                    ? const Color(0x99F7EEDC)
                    : MyPageColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// README ".chk i" — 22px 체크박스(선택 시 빨강 배경+흰 체크).
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MyPageMotion.fade,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? MyPageColors.red : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? MyPageColors.red : const Color(0x4D2A1F14),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
