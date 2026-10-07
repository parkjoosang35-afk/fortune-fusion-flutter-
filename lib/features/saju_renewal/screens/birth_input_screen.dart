import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/birthday_picker/birthday_picker_modal.dart';
import '../../auth/application/auth_provider.dart';
import '../data/saju_visual_adapter.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_visual_widgets.dart';
import 'calculating_screen.dart';

/// docs/09_기획검수_확인사항.md Q-10 "권고안대로 On"(진태양시 경도 보정
/// 기본 적용 + 02/03 화면 안내 문구 노출)에 대응하는 국내 주요 도시 목록.
///
/// [버그수정 — "경기도도 없음"] 기존 목록은 8대 광역시 중 7개 + 제주만
/// 있고, 9개 광역도(경기/강원/충북/충남/전북/전남/경북/경남) 전체가
/// 빠져 있었다. 전국 17개 광역시·도를 전부 포함하도록 확장한다 — 순서는
/// 행정안전부 표기 순(특별시 → 광역시 → 도).
const List<String> _kBirthPlaceOptions = [
  '서울',
  '부산',
  '인천',
  '대구',
  '대전',
  '광주',
  '울산',
  '세종',
  '경기',
  '강원',
  '충북',
  '충남',
  '전북',
  '전남',
  '경북',
  '경남',
  '제주',
];

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면② 출생정보 입력.
/// `design_files/saju/screens-a.jsx`의 `ScreenInput`을 재현한다 — 상단
/// "태어난 순간을 정확히 알려주세요" 타이틀, 입력값으로 실시간 갱신되는
/// 원국(사주 8자) 프리뷰 카드, "태어난 곳" + 진태양시 보정 안내
/// (C-02-6), 필드별 검증 UX(C-02-8), 하단 고정 CTA.
///
/// [기존 모델 재사용] 생년월일/시간/성별의 실제 입력 UI는 디자인
/// 핸드오프의 `Field`/`Seg`/`inputBox` 커스텀 컴포넌트를 새로 만들지
/// 않고, 앱 전역이 공유하는 [showBirthdayPicker](BirthdayPickerModal,
/// `midnight` 팔레트가 이미 다크 톤)를 그대로 재사용한다(매트릭스 문서
/// #13 "기존 data/domain 계층 유지"와 동일 취지).
///
/// [절대 금지] 생년월일/출생시간/성별을 topics/select API의 요청바디로
/// 직접 보내지 않는다 — 서버가 User.profile(DB)에 저장된 값을 조회해
/// 사용하도록 설계되어 있으므로, 반드시 [AuthProvider.updateProfile]로
/// 먼저 서버 프로필을 저장한 뒤에만 다음 단계(계산중 화면)로 진행한다.
///
/// [출생정보 수정 기능 — "처음에 잘못 입력한 사람은 어떡하라는거야?"]
/// 이 화면은 두 가지 모드로 쓰인다:
/// - 최초 입력(isEditMode=false, 기존 동작): 저장 후 03(계산중) 화면으로
///   진행해 바로 사주를 계산한다.
/// - 수정(isEditMode=true, 마이페이지/설정/정통사주 홈에서 진입): 이미
///   저장된 값(initState에서 전부 프리필됨)을 고친 뒤 저장하면, 03으로
///   강제 진행하지 않고 "저장되었습니다" 토스트만 띄우고 이전 화면으로
///   돌아간다 — 설정을 고치러 온 사용자를 사주 분석 플로우에 가두지
///   않는다. 생년월일/시간/음양력/성별 중 하나라도 바뀌면 서버의
///   birthKey(사주 계산 입력값 해시)가 자동으로 달라져, 예전에 틀린
///   정보로 생성된 이야기/상세해석은 더 이상 조회되지 않고 새 정보로
///   완전히 새로 계산된다(별도 마이그레이션 불필요 — admin_web
///   schema.prisma의 SajuFactsCache/TopicInterpretResult가 전부 birthKey
///   unique 기준이기 때문).
class BirthInputScreen extends StatefulWidget {
  const BirthInputScreen({super.key, this.isEditMode = false});

  /// true면 "수정 모드"로 진입 — 타이틀/버튼 문구가 바뀌고, 저장 후
  /// 03(계산중)으로 강제 이동하지 않고 이전 화면으로 돌아간다.
  final bool isEditMode;

  @override
  State<BirthInputScreen> createState() => _BirthInputScreenState();
}

class _BirthInputScreenState extends State<BirthInputScreen> {
  BirthdayPickerValue? _birthValue;
  String _gender = 'female'; // 'male' | 'female' — 디자인 기본값(Seg 첫 옵션)과 동일.
  bool _isLunar = false;
  bool _submitting = false;
  String? _error;

  /// [버그수정 — "이름 입력란이 없음"] 02 화면에 이름(닉네임) 입력/표시
  /// 필드가 전혀 없었다. `UserModel.nickname`은 회원가입 시 이미 서버에
  /// 저장되어 있지만, 여기서 다시 보여주고 고칠 수 있게 하고,
  /// [AuthProvider.updateProfile]로 함께 저장한다.
  final TextEditingController _nicknameController = TextEditingController();
  final GlobalKey _nicknameFieldKey = GlobalKey();
  bool _nicknameBlinking = false;
  String? _nicknameError;

  /// docs/03 §02 "태어난 곳" — 기본값 서울(진태양시 보정 예시와 동일),
  /// "변경"으로 다른 도시를 고를 수 있다.
  String _birthPlace = '서울';

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _birthDateFieldKey = GlobalKey();

  /// docs/03 §02 "검증": "미입력 필드가 있으면 탭 시 해당 필드로 스크롤 +
  /// 라벨 점 rel.chung 1초 + 필드 아래 ... 문구". 1초간 라벨 점을 강조색
  /// (충/파 적선)으로 깜빡인 뒤 원래 상태로 되돌린다.
  bool _birthDateBlinking = false;

  /// [출생정보 수정 기능] initState에서 프리필한 "원래 값"을 보관해,
  /// 저장 시점에 실제로 값이 바뀌었는지 판단한다(수정 모드에서만 사용 —
  /// 바뀐 경우에만 "기존 이야기는 새로 계산됩니다" 확인을 받는다).
  String? _originalBirthDate;
  String? _originalBirthTime;
  bool _originalBirthTimeUnknown = false;
  bool _originalIsLunar = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user?.birthDate != null) {
      final parts = user!.birthDate!.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          BirthdayPickerTimeValue? time;
          if (user.birthTime != null && !user.birthTimeUnknown) {
            final t = user.birthTime!.split(':');
            final hour = int.tryParse(t.isNotEmpty ? t[0] : '');
            if (hour != null) {
              time = _zhiTimeForHour(hour);
            }
          }
          _birthValue = BirthdayPickerValue(
            year: y,
            month: m,
            day: d,
            weekday: DateTime(y, m, d).weekday % 7,
            time: time,
          );
        }
      }
      if (user.gender == 'male' || user.gender == 'female') {
        _gender = user.gender!;
      }
      if (user.birthPlace != null && user.birthPlace!.isNotEmpty) {
        _birthPlace = user.birthPlace!;
      }
      // [출생정보 수정 기능 — 버그수정] 양력/음력(_isLunar) 프리필이
      // 빠져 있었다 — 수정 모드로 재진입했을 때 음력으로 저장한 사용자가
      // 항상 "양력"으로 되돌아와 보이는 문제가 있었다.
      _isLunar = user.isLunar;
      // [출생정보 수정 기능] "실제로 바뀌었는지" 판단용 원본값 보관.
      _originalBirthDate = user.birthDate;
      _originalBirthTime = user.birthTime;
      _originalBirthTimeUnknown = user.birthTimeUnknown;
      _originalIsLunar = user.isLunar;
    }
    // [버그수정 — 이름 입력란] 회원가입 시 받은 닉네임을 기본값으로 채워
    // 보여준다(비어있지 않은 한 그대로 쓸 수 있고, 원하면 바로 고칠 수 있음).
    if (user?.nickname != null && user!.nickname.trim().isNotEmpty) {
      _nicknameController.text = user.nickname.trim();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  BirthdayPickerTimeValue? _zhiTimeForHour(int hour) {
    for (final z in kBirthdayZhiTimes) {
      if (z.rangeStart == hour) {
        return BirthdayPickerTimeValue(
          zhi: z.zhi,
          hanja: z.hanja,
          rangeStart: z.rangeStart,
          rangeEnd: z.rangeEnd,
          label: '${z.label} (${z.hint})',
        );
      }
    }
    return null;
  }

  Future<void> _openPicker() async {
    final result = await showBirthdayPicker(
      context,
      palette: BirthdayPickerPalette.midnight,
      requireTime: false,
      initialValue: _birthValue,
      title: '태어난 날을 알려주세요',
    );
    if (result == null) return;
    setState(() {
      _birthValue = result;
      _error = null;
    });
  }

  /// docs/03 §02 "태어난 곳 — 입력 박스(좌 지역명, 우 "변경")". 전용
  /// 피커가 없었으므로, 기존 바텀시트 톤(SajuDarkBase 계열 다크 배경)에
  /// 맞춘 최소 목록 선택 시트를 새로 만든다.
  Future<void> _changeBirthPlace() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SajuInk.i900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '태어난 곳을 선택해주세요',
                  style: TextStyle(
                    fontFamily: SajuType.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: SajuGold.g100,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kBirthPlaceOptions.map((place) {
                    final selectedNow = place == _birthPlace;
                    return InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(place),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: selectedNow
                                ? SajuText.lineGold
                                : SajuText.line,
                          ),
                          color: selectedNow
                              ? SajuText.fg.withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                        child: Text(
                          place,
                          style: TextStyle(
                            fontFamily: SajuType.ui,
                            fontSize: 14,
                            color: selectedNow
                                ? SajuGold.g100
                                : SajuText.muted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _birthPlace = selected);
  }

  /// 입력값 기반 실시간 원국 프리뷰(가짜 데모 사주 금지 — 사용자가 아직
  /// 날짜를 선택하지 않았으면 null 사주로 전부 빈 칸(—) 표시).
  SajuVisualProfile? get _livePreview {
    final v = _birthValue;
    if (v == null) return null;
    final dt = v.toDateTime();
    final timeUnknown = v.time == null;
    return SajuVisualAdapter.build(
      kst: DateTime(dt.year, dt.month, dt.day, timeUnknown ? 0 : dt.hour, 0),
      gender: _gender,
      isLunar: _isLunar,
      timeUnknown: timeUnknown,
      referenceDate: DateTime.now(),
    );
  }

  /// docs/03 §02 검증: 생년월일 미입력 시 해당 필드로 스크롤 + 라벨 점
  /// 강조 + 필드 아래 안내 문구(C-02-8) — 화면 하단 공용 에러 1줄이
  /// 아니라 "그 필드 바로 아래"에 보여준다.
  Future<void> _highlightMissingBirthDate() async {
    final ctx = _birthDateFieldKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }
    if (!mounted) return;
    setState(() {
      _birthDateBlinking = true;
      _error = '이 정보가 있어야 사주를 세울 수 있어요';
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _birthDateBlinking = false);
  }

  /// [버그수정 — 이름 입력란] 생년월일 검증(_highlightMissingBirthDate)과
  /// 동일한 UX 패턴(스크롤 + 라벨 점 강조 1초 + 필드 아래 문구)을 이름
  /// 필드에도 그대로 적용한다.
  Future<void> _highlightMissingNickname() async {
    final ctx = _nicknameFieldKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }
    if (!mounted) return;
    setState(() {
      _nicknameBlinking = true;
      _nicknameError = '이름을 입력해주세요';
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _nicknameBlinking = false);
  }

  Future<void> _submit() async {
    // [버그수정 — 이름 입력란] 생년월일보다 먼저 이름을 검증한다(화면상
    // 더 위에 있는 필드이므로 누락 시 그 필드로 먼저 스크롤).
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      await _highlightMissingNickname();
      return;
    }
    final value = _birthValue;
    if (value == null) {
      await _highlightMissingBirthDate();
      return;
    }

    final birthDateStr = value.iso;
    final birthTimeUnknown = value.time == null;
    final birthTimeStr = value.time != null
        ? '${value.time!.rangeStart.toString().padLeft(2, '0')}:00'
        : null;

    // [출생정보 수정 기능] 사주 계산에 실제로 영향을 주는 값(생년월일/
    // 시간/시간모름여부/음양력)이 바뀌었는지 확인한다. 수정 모드에서
    // 이 값들이 바뀌면 서버 birthKey가 달라져 기존에 복주머니로 열어본
    // 이야기는 더 이상 보이지 않고 새로 계산된다 — 결제한 사용자가
    // 당황하지 않도록 저장 전에 미리 안내하고 확인을 받는다.
    final birthRelatedChanged =
        birthDateStr != _originalBirthDate ||
        birthTimeStr != _originalBirthTime ||
        birthTimeUnknown != _originalBirthTimeUnknown ||
        _isLunar != _originalIsLunar;

    if (widget.isEditMode && birthRelatedChanged) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '출생정보를 변경하시겠어요?',
        message: '생년월일시 정보를 바꾸면 사주가 다시 계산됩니다.\n'
            '이전 정보로 보셨던 이야기는 더 이상 보이지 않고,\n'
            '새 정보로 새롭게 이야기를 찾아드려요.',
        confirmLabel: '변경하기',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _nicknameError = null;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      birthDate: birthDateStr,
      birthTime: birthTimeStr,
      isLunar: _isLunar,
      birthTimeUnknown: birthTimeUnknown,
      birthPlace: _birthPlace,
      gender: _gender,
      nickname: nickname,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _submitting = false;
        _error = auth.lastProfileUpdateError ?? '출생정보를 저장하지 못했습니다. 다시 시도해주세요.';
      });
      return;
    }

    setState(() => _submitting = false);
    if (!mounted) return;

    if (widget.isEditMode) {
      // [출생정보 수정 기능] 설정/마이페이지에서 고치러 온 사용자를 사주
      // 분석 플로우에 강제로 태우지 않는다 — 저장만 하고 이전 화면으로
      // 돌아간다.
      AppToast.show(context, '출생정보를 저장했습니다.');
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CalculatingScreen()));
    context.read<SajuRenewalProvider>().startCalculating();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _livePreview;
    final timeUnknown = _birthValue?.time == null;
    // docs/09 Q-10: "권고안대로 On, 02(출생지 아래)·03(1단계)에 표시.
    // 시간 모름이면 미표시" — E-15와 동일하게 시간 모름일 때는 진태양시
    // 문구를 숨긴다(시간 자체를 안 쓰므로 보정 의미가 없음).
    final showSolarTimeNote = !timeUnknown;

    return Scaffold(
      body: SajuDarkBase(
        child: SafeArea(
          child: Column(
            children: [
              SajuTopBar(
                left: SajuIconButton(
                  icon: '←',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                title: widget.isEditMode ? '출생정보 수정' : 'BIRTH · 02',
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEditMode
                            ? '출생정보를\n다시 확인해주세요'
                            : '태어난 순간을\n정확히 알려주세요',
                        style: const TextStyle(
                          fontFamily: SajuType.serif,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          height: 1.35,
                          letterSpacing: -0.02 * 24,
                          color: SajuGold.g100,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.isEditMode
                            ? '처음에 잘못 입력했다면 지금 바로 고칠 수 있어요.'
                            : '시간이 정밀할수록 사주가 선명해집니다.',
                        style: const TextStyle(
                          fontFamily: SajuType.body,
                          fontSize: 14,
                          height: 1.6,
                          color: SajuText.muted,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // [버그수정 — "이름 입력란이 없음"] docs/03 §02에
                      // 명시되어 있지 않았지만, 사주 분석은 "누구의
                      // 사주인지" 이름이 있어야 자연스러우므로 생년월일
                      // 바로 앞에 추가한다.
                      KeyedSubtree(
                        key: _nicknameFieldKey,
                        child: _FieldLabel(
                          label: '이름',
                          done: _nicknameController.text.trim().isNotEmpty,
                          blinking: _nicknameBlinking,
                        ),
                      ),
                      TextField(
                        controller: _nicknameController,
                        maxLength: 12,
                        style: const TextStyle(
                          fontFamily: SajuType.ui,
                          fontSize: 15,
                          color: SajuGold.g100,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          counterText: '',
                          hintText: '이름을 입력해주세요',
                          hintStyle: const TextStyle(
                            fontFamily: SajuType.ui,
                            fontSize: 15,
                            color: SajuText.faint,
                          ),
                          filled: true,
                          fillColor: SajuText.fg.withValues(alpha: 0.035),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: SajuText.lineGold,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: SajuText.lineGold,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: SajuGold.g100,
                              width: 1.4,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          if (_nicknameError != null) {
                            setState(() => _nicknameError = null);
                          } else {
                            // done 점 표시를 즉시 갱신.
                            setState(() {});
                          }
                        },
                      ),
                      if (_nicknameError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _nicknameError!,
                            style: const TextStyle(
                              fontFamily: SajuType.ui,
                              fontSize: 12,
                              color: Color(0xFFE08A7E),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),

                      // 원국 프리뷰 카드.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SajuText.line),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              SajuViolet.v700.withValues(alpha: 0.4),
                              SajuInk.i900.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Center(
                              child: SajuPillarGrid(
                                pillars: preview?.pillars ??
                                    const [null, null, null, null],
                                cell: 44,
                                gap: 10,
                                reveal: 8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '입력한 순간이 여덟 글자로 새겨져요',
                              style: TextStyle(
                                fontFamily: SajuType.ui,
                                fontSize: 11,
                                color: SajuText.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      KeyedSubtree(
                        key: _birthDateFieldKey,
                        child: _FieldLabel(
                          label: '생년월일',
                          done: _birthValue != null,
                          blinking: _birthDateBlinking,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _InputBoxTap(
                              onTap: _openPicker,
                              child: Text(
                                _birthValue == null
                                    ? '생년월일을 선택해주세요'
                                    : _birthValue!.iso.replaceAll('-', '. '),
                                style: TextStyle(
                                  fontFamily: SajuType.ui,
                                  fontSize: 15,
                                  color: _birthValue == null
                                      ? SajuText.faint
                                      : SajuGold.g100,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 132,
                            child: _SajuSeg(
                              options: const ['양력', '음력'],
                              value: _isLunar ? '음력' : '양력',
                              onChange: (v) =>
                                  setState(() => _isLunar = v == '음력'),
                            ),
                          ),
                        ],
                      ),
                      // docs/03 §02 검증 — 생년월일 필드 바로 아래에
                      // "이 정보가 있어야 사주를 세울 수 있어요"(C-02-8).
                      if (_birthValue == null && _error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontFamily: SajuType.ui,
                              fontSize: 12,
                              color: Color(0xFFE08A7E),
                            ),
                          ),
                        ),

                      _FieldLabel(label: '태어난 시간', done: !timeUnknown),
                      Row(
                        children: [
                          Expanded(
                            child: Opacity(
                              opacity: timeUnknown ? 0.35 : 1,
                              child: _InputBoxTap(
                                onTap: _openPicker,
                                child: Text(
                                  timeUnknown
                                      ? '— : —'
                                      : (_birthValue?.time?.label ?? '— : —'),
                                  style: const TextStyle(
                                    fontFamily: SajuType.ui,
                                    fontSize: 15,
                                    color: SajuGold.g100,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TimeUnknownButton(
                            active: timeUnknown,
                            onTap: _openPicker,
                          ),
                        ],
                      ),
                      if (timeUnknown)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '시간을 몰라도 핵심 이야기는 볼 수 있습니다.',
                            style: TextStyle(
                              fontFamily: SajuType.ui,
                              fontSize: 12,
                              color: SajuGold.g300,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),

                      _FieldLabel(label: '성별', done: true),
                      _SajuSeg(
                        options: const ['여성', '남성'],
                        value: _gender == 'male' ? '남성' : '여성',
                        onChange: (v) =>
                            setState(() => _gender = v == '남성' ? 'male' : 'female'),
                      ),
                      const SizedBox(height: 14),

                      // docs/03 §02 "태어난 곳" + 진태양시 보정 안내(C-02-6).
                      _FieldLabel(label: '태어난 곳', done: true),
                      Row(
                        children: [
                          Expanded(
                            child: _InputBoxTap(
                              onTap: _changeBirthPlace,
                              child: Text(
                                _birthPlace,
                                style: const TextStyle(
                                  fontFamily: SajuType.ui,
                                  fontSize: 15,
                                  color: SajuGold.g100,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _changeBirthPlace,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 14,
                              ),
                              child: Text(
                                '변경',
                                style: TextStyle(
                                  fontFamily: SajuType.ui,
                                  fontSize: 12,
                                  color: SajuText.faint,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showSolarTimeNote)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: SajuType.ui,
                                fontSize: 12,
                                height: 1.5,
                                color: SajuText.muted,
                              ),
                              children: [
                                const TextSpan(
                                  text: '☼ ',
                                  style: TextStyle(color: SajuGold.g500),
                                ),
                                TextSpan(
                                  text: '$_birthPlace 기준 태양시로 보정하여 계산합니다.',
                                ),
                              ],
                            ),
                          ),
                        ),

                      // [공통 저장 실패 안내] 생년월일 관련이 아닌 그 외
                      // 실패(서버 오류 등)는 화면 하단에 그대로 노출한다.
                      if (_error != null && _birthValue != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontFamily: SajuType.ui,
                            fontSize: 13,
                            color: Color(0xFFE08A7E),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, SajuInk.i900],
                    stops: [0.0, 0.5],
                  ),
                ),
                child: SajuButton(
                  label: widget.isEditMode ? '저장하기' : '사주 분석 시작하기',
                  loading: _submitting,
                  onTap: _submitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
    required this.done,
    this.blinking = false,
  });
  final String label;
  final bool done;

  /// docs/03 §02 검증 — 미입력 필드를 탭했을 때 라벨 점을 1초간
  /// rel.chung(충/파 적선)으로 강조한다.
  final bool blinking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, top: 14),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: blinking
                  ? SajuRelationColor.chung
                  : (done ? SajuGold.g300 : SajuText.faint),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: SajuType.ui,
              fontSize: 12,
              color: SajuText.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBoxTap extends StatelessWidget {
  const _InputBoxTap({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SajuText.lineGold),
          color: SajuText.fg.withValues(alpha: 0.035),
        ),
        child: child,
      ),
    );
  }
}

class _TimeUnknownButton extends StatelessWidget {
  const _TimeUnknownButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? SajuGold.g100 : Colors.transparent,
          border: Border.all(
            color: active ? SajuGold.g100 : SajuText.line,
          ),
        ),
        child: Text(
          '모름',
          style: TextStyle(
            fontFamily: SajuType.ui,
            fontSize: 13,
            color: active ? SajuInk.i900 : SajuText.muted,
          ),
        ),
      ),
    );
  }
}

class _SajuSeg extends StatelessWidget {
  const _SajuSeg({
    required this.options,
    required this.value,
    required this.onChange,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SajuText.line),
        color: SajuText.fg.withValues(alpha: 0.02),
      ),
      child: Row(
        children: options.map((o) {
          final selected = value == o;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: o == options.last ? 0 : 6),
              child: InkWell(
                onTap: () => onChange(o),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: selected
                        ? SajuText.fg.withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: selected
                        ? Border.all(color: SajuText.lineGold)
                        : null,
                  ),
                  child: Text(
                    o,
                    style: TextStyle(
                      fontFamily: SajuType.ui,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? SajuGold.g100 : SajuText.muted,
                    ),
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
