import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/router/app_navigator_key.dart';
import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/utils/lunar_calendar_util.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/birthday_picker/birthday_picker_modal.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/presentation/signup_complete_screen.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';
import '../data/saju_visual_adapter.dart';
import '../domain/pending_saju_entry.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_visual_widgets.dart';
import 'calculating_screen.dart';

/// [비회원 둘러보기 및 로그인 연속성 — 정통사주] 로그인 완료 후 저장된 02
/// (출생정보 입력) 화면 재진입 요청이 있으면, 원래 입력하던 값 그대로
/// [BirthInputScreen]으로 자동 복귀시킨다. `guinji_input_screen.dart`의
/// [replayPendingGuinjiMapEntry]와 동일한 타이밍(로그인 화면이 '/home'으로
/// 스택을 교체한 *다음 프레임*)에 호출해야 한다.
void replayPendingSajuEntry() {
  final draft = PendingSajuEntryStore.consume();
  if (draft == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navState = appNavigatorKey.currentState;
    if (navState == null) return;
    navState.push(
      MaterialPageRoute(builder: (_) => BirthInputScreen(initialDraft: draft)),
    );
  });
}

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
  const BirthInputScreen({
    super.key,
    this.isEditMode = false,
    this.initialDraft,
    this.isSignupFlow = false,
  });

  /// true면 "수정 모드"로 진입 — 타이틀/버튼 문구가 바뀌고, 저장 후
  /// 03(계산중)으로 강제 이동하지 않고 이전 화면으로 돌아간다.
  final bool isEditMode;

  /// [비회원 둘러보기 및 로그인 연속성] 로그인 리다이렉트 전에 저장해 둔
  /// 입력값(있으면 복원, 없으면 기존처럼 [AuthProvider.currentUser] 기준
  /// 프리필 또는 빈 폼). `isEditMode`와는 함께 쓰이지 않는다(수정 모드는
  /// 이미 로그인된 사용자만 진입하는 경로이므로 draft 복원이 필요 없음).
  final SajuEntryDraft? initialDraft;

  /// [회원가입 통합 사주정보 — 디자인 핸드오프 04/05 화면] true면 방금
  /// 가입(이메일/카카오/구글)을 마치고 "공통 본인 사주정보 입력"으로
  /// 강제 연결된 상태다. `isEditMode`와는 상호 배타적이다.
  /// - 상단 타이틀/CTA 문구가 "가입을 마무리"하는 톤으로 바뀐다
  ///   (`✧ 사주정보 저장하고 시작하기` 상당).
  /// - 저장 성공 시 03(계산중)이 아니라 05(가입 완료 요약) 화면으로
  ///   이동한다.
  /// - 뒤로가기(상단 ←, 시스템 back)를 누르면 핸드오프 dev-spec.md
  ///   "가입 모드에서 뒤로가기: 이탈 불가 토스트"에 따라 화면을 유지하고
  ///   안내 토스트만 띄운다(로그아웃 후 가입 선택 화면으로 돌아가고
  ///   싶으면 설정에서 가능 — 임의로 세션을 끊지 않는다).
  final bool isSignupFlow;

  @override
  State<BirthInputScreen> createState() => _BirthInputScreenState();
}

class _BirthInputScreenState extends State<BirthInputScreen> {
  // [회원가입 통합 사주정보 04 화면 — Moonlit Crystal 리스킨] 이 화면은
  // `isSignupFlow`/`isEditMode`/기본값(최초 정통사주 입력) 3개 모드를
  // 공유하는데, 가입 플로우(`isSignupFlow:true`)만 02/03과 동일한
  // "Moonlit Crystal" 다크 보라/핑크 톤으로 바꾸고, 정통사주 전용
  // `isEditMode`/기본값 경로는 기존 `SajuGold`/`SajuDarkBase` 톤을 1px도
  // 바꾸지 않는다. 아래 `_moon` 플래그로 분기하고, 공유 private 위젯
  // (`_FieldLabel`/`_InputBoxTap`/`_TimeUnknownButton`/`_SajuSeg`)에는
  // 기본값 false인 `moon` 파라미터를 추가해 이 플래그를 전달한다 —
  // 호출부에서 넘기지 않으면 기존 동작과 100% 동일하다.
  bool get _moon => widget.isSignupFlow;

  BirthdayPickerValue? _birthValue;
  String _gender = 'female'; // 'male' | 'female' — 디자인 기본값(Seg 첫 옵션)과 동일.
  bool _isLunar = false;

  /// [회원가입·본인 사주정보 통합 흐름 — 전면 검수 지시서 B1] 음력
  /// 선택 시에만 의미가 있는 윤달 여부. 양력이면 항상 false로 취급한다
  /// (`saju_input_screen.dart`의 `_leap`과 동일한 역할).
  bool _isLeapMonth = false;
  bool _submitting = false;
  String? _error;

  /// B1/B2: 음력+윤달 선택이 그 연도에 실제로 존재하지 않는 조합일 때의
  /// 안내 메시지(예: "2023년(음력)은 윤2월만 윤달이에요"). null이면 문제
  /// 없음 — `_openPicker()`에서 매번 재계산한다.
  String? _leapMonthWarning;

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
  bool _originalIsLeapMonth = false;

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
      // [B1 — 윤달 프리필] 음력일 때만 의미가 있다(양력이면 항상 false).
      _isLeapMonth = user.isLunar ? user.isLeapMonth : false;
      // [출생정보 수정 기능] "실제로 바뀌었는지" 판단용 원본값 보관.
      _originalBirthDate = user.birthDate;
      _originalBirthTime = user.birthTime;
      _originalBirthTimeUnknown = user.birthTimeUnknown;
      _originalIsLunar = user.isLunar;
      _originalIsLeapMonth = _isLeapMonth;
    }
    // [버그수정 — 이름 입력란] 회원가입 시 받은 닉네임을 기본값으로 채워
    // 보여준다(비어있지 않은 한 그대로 쓸 수 있고, 원하면 바로 고칠 수 있음).
    if (user?.nickname != null && user!.nickname.trim().isNotEmpty) {
      _nicknameController.text = user.nickname.trim();
    }

    // [비회원 둘러보기 및 로그인 연속성 — 정통사주] 로그인 리다이렉트 전에
    // 입력해 둔 값이 있으면(=게스트가 입력 중 로그인하러 보내진 경우),
    // 그 값이 서버 프로필 기반 프리필보다 사용자의 "방금 직접 입력한"
    // 최신 의도를 더 정확히 반영하므로 덮어써서 복원한다.
    final draft = widget.initialDraft;
    if (draft != null) {
      BirthdayPickerTimeValue? time;
      if (draft.timeRangeStart != null) {
        time = _zhiTimeForHour(draft.timeRangeStart!);
      }
      _birthValue = BirthdayPickerValue(
        year: draft.year,
        month: draft.month,
        day: draft.day,
        weekday: DateTime(draft.year, draft.month, draft.day).weekday % 7,
        time: time,
      );
      _gender = draft.gender;
      _isLunar = draft.isLunar;
      _isLeapMonth = draft.isLunar ? draft.isLeapMonth : false;
      _birthPlace = draft.birthPlace;
      _nicknameController.text = draft.nickname;
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

  /// [B2 — 음력 날짜 검증] 음력 선택 시, `BirthdayPickerModal`의 8자리
  /// 키패드 입력 단계에서부터 "기존 만세력 엔진 기준"(`LunarCalendarUtil`,
  /// `saju_input_screen.dart`와 동일 원칙)으로 실제 존재하는 날짜인지
  /// 검증한다. 공용 위젯([validateBirthdayDate])은 양력 전용 로직을 그대로
  /// 유지하고, 이 화면만 `dateValidator`로 음력 검증 함수를 주입한다 —
  /// 궁합/귀인지도 등 같은 위젯을 쓰는 다른 화면은 영향받지 않는다.
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
          LunarCalendarUtil.daysInLunarMonth(y, m, isLeap: _isLeapMonth) ?? 29;
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

  /// [B1/B2] 날짜가 이미 선택된 상태에서 음력/윤달 설정이 바뀌면(예: 윤달
  /// 체크 해제·체크, 양력→음력 전환), 기존에 고른 날짜가 더 이상 유효하지
  /// 않을 수 있다(예: 윤달에만 있는 "윤4월 30일"을 골라둔 채 윤달 체크를
  /// 해제하면 평달 4월엔 30일이 없을 수 있음). 이런 경우 조용히 잘못된
  /// 값을 유지한 채 저장되지 않도록, 날짜를 비우고 다시 고르게 안내한다.
  void _recheckBirthValueAfterLunarToggle() {
    final v = _birthValue;
    if (v == null || !_isLunar) {
      _leapMonthWarning = null;
      return;
    }
    final validation = LunarCalendarUtil.validateLunarDate(
      year: v.year,
      month: v.month,
      day: v.day,
      isLeap: _isLeapMonth,
    );
    if (!validation.ok) {
      _leapMonthWarning = validation.message;
      _birthValue = null;
    } else {
      _leapMonthWarning = null;
    }
  }

  Future<void> _openPicker() async {
    final result = await showBirthdayPicker(
      context,
      palette: _moon
          ? BirthdayPickerPalette.moonlit
          : BirthdayPickerPalette.midnight,
      requireTime: false,
      initialValue: _birthValue,
      title: '태어난 날을 알려주세요',
      dateValidator: _isLunar ? _lunarPickerValidator : null,
    );
    if (result == null) return;
    setState(() {
      _birthValue = result;
      _error = null;
      _leapMonthWarning = null;
    });
  }

  /// docs/03 §02 "태어난 곳 — 입력 박스(좌 지역명, 우 "변경")". 전용
  /// 피커가 없었으므로, 기존 바텀시트 톤(SajuDarkBase 계열 다크 배경)에
  /// 맞춘 최소 목록 선택 시트를 새로 만든다.
  Future<void> _changeBirthPlace() async {
    // [작은 화면/글자확대 잘림 수정 — 2026 반응형 규격 통일] 17개 지역
    // Wrap 목록이 isScrollControlled 없이 showModalBottomSheet로 열려
    // Flutter 기본 동작으로 높이가 화면 절반 고정됐다. 글자 확대(1.3배)
    // 조건에서 320×568·360×640 두 폭 모두 바닥 오버플로가 실측됐다
    // (최대 131px). 다른 시트들과 동일한 표준 패턴 — isScrollControlled:
    // true + SingleChildScrollView — 로 "내용이 들어가면 그대로, 넘칠
    // 때만 스크롤"되게 한다. 디자인(배경색·모서리·목록 레이아웃)은
    // 그대로다.
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SajuInk.i900,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
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
      isLeapMonth: _isLunar ? _isLeapMonth : false,
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
    // [B2] 양력이면 윤달 개념 자체가 없으므로 항상 false로 정규화해
    // 저장한다(saju_input_screen.dart의 `_cal == 'lunar' ? _leap : false`와
    // 동일 원칙).
    final isLeapMonth = _isLunar ? _isLeapMonth : false;

    // [비회원 둘러보기 및 로그인 연속성 — 정통사주, 귀인지도 패턴 적용]
    // 로그인 게이트를 화면 "진입 시점"(SajuRenewalHomeScreen._start())이
    // 아니라 여기 "제출 시점"으로 옮겼다 — 게스트도 02 화면에 들어와 자유롭게
    // 입력해볼 수 있어야 하고, 실제로 서버 저장(updateProfile)이 필요한
    // 바로 이 순간에만 로그인을 확인한다. 비로그인이면 지금까지 입력한
    // 값을 그대로 [PendingSajuEntryStore]에 담아 두고 `/login`으로 보낸다
    // — 로그인/회원가입이 끝나면 [replayPendingSajuEntry]가 이 화면을
    // 동일한 입력값으로 다시 열어준다(guinji_input_screen.dart의
    // `_handleSubmit()` 비로그인 분기와 동일한 구조).
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      PendingSajuEntryStore.save(
        SajuEntryDraft(
          nickname: nickname,
          year: value.year,
          month: value.month,
          day: value.day,
          timeRangeStart: value.time?.rangeStart,
          gender: _gender,
          isLunar: _isLunar,
          isLeapMonth: isLeapMonth,
          birthPlace: _birthPlace,
        ),
      );
      Navigator.of(context).pushNamed('/login');
      return;
    }

    // [출생정보 수정 기능] 사주 계산에 실제로 영향을 주는 값(생년월일/
    // 시간/시간모름여부/음양력)이 바뀌었는지 확인한다. 수정 모드에서
    // 이 값들이 바뀌면 서버 birthKey가 달라져 기존에 복주머니로 열어본
    // 이야기는 더 이상 보이지 않고 새로 계산된다 — 결제한 사용자가
    // 당황하지 않도록 저장 전에 미리 안내하고 확인을 받는다.
    final birthRelatedChanged =
        birthDateStr != _originalBirthDate ||
        birthTimeStr != _originalBirthTime ||
        birthTimeUnknown != _originalBirthTimeUnknown ||
        _isLunar != _originalIsLunar ||
        isLeapMonth != _originalIsLeapMonth;

    if (widget.isEditMode && birthRelatedChanged) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '출생정보를 변경하시겠어요?',
        message:
            '생년월일시 정보를 바꾸면 사주가 다시 계산됩니다.\n'
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

    final ok = await auth.updateProfile(
      birthDate: birthDateStr,
      birthTime: birthTimeStr,
      isLunar: _isLunar,
      isLeapMonth: isLeapMonth,
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

    if (widget.isSignupFlow) {
      // [회원가입 통합 사주정보 — 디자인 핸드오프 04→05] 가입 직후
      // 흐름에서는 바로 사주 계산(03)으로 보내지 않고, 05(가입 완료
      // 요약) 화면으로 pushReplacement한다 — 뒤로가기로 이 입력 화면에
      // 다시 돌아올 수 없게 스택에서 제거한다(dev-spec.md 라우팅 규칙
      // "05 가입 완료 → pendingMenu ? 해당 메뉴 : 홈"과 동일 취지로,
      // 여기서는 pendingMenu가 없는 일반 가입 경로이므로 홈으로
      // 이어진다).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignupCompleteScreen()),
      );
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CalculatingScreen()));
    context.read<SajuRenewalProvider>().startCalculating();
  }

  @override
  Widget build(BuildContext context) {
    final moon = _moon;

    return PopScope(
      // [dev-spec.md §Interactions "가입 모드에서 뒤로가기: 이탈 불가
      // 토스트 — 사주정보를 입력해야 가입이 완료돼요"] 회원가입 플로우로
      // 들어온 경우에만 뒤로가기를 막는다. 일반 입력/수정 모드는 기존
      // 그대로 자유롭게 뒤로 갈 수 있다(회귀 없음).
      canPop: !widget.isSignupFlow,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !widget.isSignupFlow) return;
        AppToast.show(context, '사주정보를 입력해야 가입이 완료돼요', isError: true);
      },
      child: Scaffold(
        body: moon
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            IntroPalette.backgroundTop,
                            IntroPalette.backgroundBottom,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(child: _buildBody(context, moon: true)),
                ],
              )
            : SajuDarkBase(
                child: SafeArea(child: _buildBody(context, moon: false)),
              ),
        bottomNavigationBar: widget.isSignupFlow
            ? null
            : const MainBottomNavBar(currentIndex: 0),
      ),
    );
  }

  Widget _buildBody(BuildContext context, {required bool moon}) {
    final preview = _livePreview;
    final timeUnknown = _birthValue?.time == null;
    final showSolarTimeNote = !timeUnknown;
    final titleColor = moon ? IntroPalette.textPrimary : SajuGold.g100;
    final titleStyle = moon
        ? IntroTextStyles.formTitle(color: titleColor)
        : TextStyle(
            fontFamily: SajuType.serif,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            height: 1.35,
            letterSpacing: -0.02 * 24,
            color: titleColor,
          );
    final subtitleStyle = moon
        ? IntroTextStyles.formSubtitle()
        : const TextStyle(
            fontFamily: SajuType.body,
            fontSize: 14,
            height: 1.6,
            color: SajuText.muted,
          );
    final fieldTextColor = moon ? IntroPalette.textPrimary : SajuGold.g100;
    final fieldTextStyle = TextStyle(
      fontFamily: moon ? 'Pretendard' : SajuType.ui,
      fontSize: 15,
      color: fieldTextColor,
    );
    final hintColor = moon ? IntroPalette.textSecondary : SajuText.faint;
    final mutedColor = moon ? IntroPalette.textSecondary : SajuText.muted;
    final errorColor = moon ? IntroPalette.danger : const Color(0xFFE08A7E);
    final requiredMarkColor = moon ? IntroPalette.rose : SajuGold.g500;
    final cardBorderColor = moon ? IntroPalette.cardBorder : SajuText.line;
    final cardFillColor = moon
        ? IntroPalette.primaryLight
        : SajuText.fg.withValues(alpha: 0.035);

    return Column(
      children: [
        moon
            ? Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isEditMode ? 'MY SAJU · EDIT' : 'SIGN UP · N°02',
                      style: IntroTextStyles.formEyebrow(
                        color: IntroPalette.primary,
                      ),
                    ),
                  ],
                ),
              )
            : SajuTopBar(
                left: widget.isSignupFlow
                    ? null
                    : SajuIconButton(
                        icon: '←',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                title: widget.isEditMode
                    ? '출생정보 수정'
                    : (widget.isSignupFlow ? 'SIGN UP · N°02' : 'BIRTH · 02'),
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
                      : (widget.isSignupFlow
                            ? '나의 사주정보\n입력'
                            : '태어난 순간을\n정확히 알려주세요'),
                  style: titleStyle,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isEditMode
                      ? '처음에 잘못 입력했다면 지금 바로 고칠 수 있어요.'
                      : (widget.isSignupFlow
                            ? '매번 생년월일을 입력하지 않고, 나에게 맞는\n'
                                  '개인 맞춤 운세를 편리하게 제공받을 수 있어요.'
                            : '시간이 정밀할수록 사주가 선명해집니다.'),
                  style: subtitleStyle,
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
                    moon: moon,
                  ),
                ),
                TextField(
                  controller: _nicknameController,
                  maxLength: 12,
                  style: fieldTextStyle,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: '이름을 입력해주세요',
                    hintStyle: TextStyle(
                      fontFamily: moon ? 'Pretendard' : SajuType.ui,
                      fontSize: 15,
                      color: hintColor,
                    ),
                    filled: true,
                    fillColor: cardFillColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cardBorderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cardBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: moon ? IntroPalette.primary : SajuGold.g100,
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
                      style: TextStyle(
                        fontFamily: moon ? 'Pretendard' : SajuType.ui,
                        fontSize: 12,
                        color: errorColor,
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
                    border: Border.all(color: cardBorderColor),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: moon
                          ? [
                              IntroPalette.primary.withValues(alpha: 0.16),
                              IntroPalette.backgroundBottom.withValues(
                                alpha: 0.2,
                              ),
                            ]
                          : [
                              SajuViolet.v700.withValues(alpha: 0.4),
                              SajuInk.i900.withValues(alpha: 0.2),
                            ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: SajuPillarGrid(
                          pillars:
                              preview?.pillars ??
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
                        onChange: (v) => setState(() {
                          _isLunar = v == '음력';
                          if (!_isLunar) _isLeapMonth = false;
                          _recheckBirthValueAfterLunarToggle();
                        }),
                      ),
                    ),
                  ],
                ),
                // [B1 — 윤달 선택] 음력을 고른 경우에만 노출한다
                // (saju_input_screen.dart의 '윤달에 태어났어요' 체크와
                // 동일한 UX 원칙 — 양력에는 윤달 개념이 없으므로 숨김).
                if (_isLunar)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkWell(
                      onTap: () => setState(() {
                        _isLeapMonth = !_isLeapMonth;
                        _recheckBirthValueAfterLunarToggle();
                      }),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: _isLeapMonth
                                  ? (moon
                                        ? IntroPalette.primary
                                        : SajuGold.g300)
                                  : Colors.transparent,
                              border: Border.all(
                                color: _isLeapMonth
                                    ? (moon
                                          ? IntroPalette.primary
                                          : SajuGold.g300)
                                    : cardBorderColor,
                              ),
                            ),
                            child: _isLeapMonth
                                ? Icon(
                                    Icons.check,
                                    size: 13,
                                    color: moon
                                        ? IntroPalette.onPrimary
                                        : SajuInk.i900,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '윤달에 태어났어요',
                            style: TextStyle(
                              fontFamily: moon ? 'Pretendard' : SajuType.ui,
                              fontSize: 13,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // docs/03 §02 검증 — 생년월일 필드 바로 아래에
                // "이 정보가 있어야 사주를 세울 수 있어요"(C-02-8).
                if (_birthValue == null && _error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontFamily: moon ? 'Pretendard' : SajuType.ui,
                        fontSize: 12,
                        color: errorColor,
                      ),
                    ),
                  ),
                // [B2] 음력+윤달 조합이 그 해에 실제로 존재하지 않아
                // 날짜가 초기화된 경우의 안내(예: "2023년(음력)은
                // 윤2월만 윤달이에요").
                if (_leapMonthWarning != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _leapMonthWarning!,
                      style: TextStyle(
                        fontFamily: moon ? 'Pretendard' : SajuType.ui,
                        fontSize: 12,
                        color: errorColor,
                      ),
                    ),
                  ),

                _FieldLabel(label: '태어난 시간', done: !timeUnknown, moon: moon),
                Row(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity: timeUnknown ? 0.35 : 1,
                        child: _InputBoxTap(
                          onTap: _openPicker,
                          moon: moon,
                          child: Text(
                            timeUnknown
                                ? '— : —'
                                : (_birthValue?.time?.label ?? '— : —'),
                            style: TextStyle(
                              fontFamily: moon ? 'Pretendard' : SajuType.ui,
                              fontSize: 15,
                              color: fieldTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TimeUnknownButton(
                      active: timeUnknown,
                      onTap: _openPicker,
                      moon: moon,
                    ),
                  ],
                ),
                if (timeUnknown)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '시간을 몰라도 핵심 이야기는 볼 수 있습니다.',
                      style: TextStyle(
                        fontFamily: moon ? 'Pretendard' : SajuType.ui,
                        fontSize: 12,
                        color: moon ? IntroPalette.gold : SajuGold.g300,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),

                _FieldLabel(label: '성별', done: true, moon: moon),
                _SajuSeg(
                  options: const ['여성', '남성'],
                  value: _gender == 'male' ? '남성' : '여성',
                  moon: moon,
                  onChange: (v) =>
                      setState(() => _gender = v == '남성' ? 'male' : 'female'),
                ),
                const SizedBox(height: 14),

                // docs/03 §02 "태어난 곳" + 진태양시 보정 안내(C-02-6).
                _FieldLabel(label: '태어난 곳', done: true, moon: moon),
                Row(
                  children: [
                    Expanded(
                      child: _InputBoxTap(
                        onTap: _changeBirthPlace,
                        moon: moon,
                        child: Text(
                          _birthPlace,
                          style: TextStyle(
                            fontFamily: moon ? 'Pretendard' : SajuType.ui,
                            fontSize: 15,
                            color: fieldTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _changeBirthPlace,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                        child: Text(
                          '변경',
                          style: TextStyle(
                            fontFamily: moon ? 'Pretendard' : SajuType.ui,
                            fontSize: 12,
                            color: hintColor,
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
                        style: TextStyle(
                          fontFamily: moon ? 'Pretendard' : SajuType.ui,
                          fontSize: 12,
                          height: 1.5,
                          color: mutedColor,
                        ),
                        children: [
                          TextSpan(
                            text: '☼ ',
                            style: TextStyle(color: requiredMarkColor),
                          ),
                          TextSpan(text: '$_birthPlace 기준 태양시로 보정하여 계산합니다.'),
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
                    style: TextStyle(
                      fontFamily: moon ? 'Pretendard' : SajuType.ui,
                      fontSize: 13,
                      color: errorColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                moon ? IntroPalette.backgroundBottom : SajuInk.i900,
              ],
              stops: const [0.0, 0.5],
            ),
          ),
          child: moon
              ? AuthPrimaryButton(
                  label: widget.isEditMode ? '저장하기' : '사주정보 저장하고 시작하기',
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _submit,
                )
              : SajuButton(
                  label: widget.isEditMode
                      ? '저장하기'
                      : (widget.isSignupFlow
                            ? '✧ 사주정보 저장하고 시작하기'
                            : '사주 분석 시작하기'),
                  loading: _submitting,
                  onTap: _submitting ? null : _submit,
                ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
    required this.done,
    this.blinking = false,
    this.moon = false,
  });
  final String label;
  final bool done;

  /// docs/03 §02 검증 — 미입력 필드를 탭했을 때 라벨 점을 1초간
  /// rel.chung(충/파 적선)으로 강조한다.
  final bool blinking;

  /// [회원가입 04 화면 — Moonlit Crystal] true면 `IntroPalette` 톤으로
  /// 렌더링한다(기본값 false는 기존 `SajuGold`/`SajuText` 톤 그대로 —
  /// isEditMode/기본값 정통사주 경로는 영향 없음).
  final bool moon;

  @override
  Widget build(BuildContext context) {
    final doneColor = moon ? IntroPalette.gold : SajuGold.g300;
    final faintColor = moon ? IntroPalette.textSecondary : SajuText.faint;
    final mutedColor = moon ? IntroPalette.textSecondary : SajuText.muted;
    final blinkColor = moon ? IntroPalette.rose : SajuRelationColor.chung;
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
              color: blinking ? blinkColor : (done ? doneColor : faintColor),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: moon
                ? IntroTextStyles.fieldLabel(color: mutedColor)
                : TextStyle(
                    fontFamily: SajuType.ui,
                    fontSize: 12,
                    color: mutedColor,
                  ),
          ),
        ],
      ),
    );
  }
}

class _InputBoxTap extends StatelessWidget {
  const _InputBoxTap({
    required this.onTap,
    required this.child,
    this.moon = false,
  });
  final VoidCallback onTap;
  final Widget child;
  final bool moon;

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
          border: Border.all(
            color: moon ? IntroPalette.cardBorder : SajuText.lineGold,
          ),
          color: moon
              ? IntroPalette.primaryLight
              : SajuText.fg.withValues(alpha: 0.035),
        ),
        child: child,
      ),
    );
  }
}

class _TimeUnknownButton extends StatelessWidget {
  const _TimeUnknownButton({
    required this.active,
    required this.onTap,
    this.moon = false,
  });
  final bool active;
  final VoidCallback onTap;
  final bool moon;

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
          color: active
              ? (moon ? IntroPalette.primary : SajuGold.g100)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? (moon ? IntroPalette.primary : SajuGold.g100)
                : (moon ? IntroPalette.cardBorder : SajuText.line),
          ),
        ),
        child: Text(
          '모름',
          style: TextStyle(
            fontFamily: moon ? 'Pretendard' : SajuType.ui,
            fontSize: 13,
            color: active
                ? (moon ? IntroPalette.onPrimary : SajuInk.i900)
                : (moon ? IntroPalette.textSecondary : SajuText.muted),
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
    this.moon = false,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChange;
  final bool moon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: moon ? IntroPalette.cardBorder : SajuText.line,
        ),
        color: moon
            ? IntroPalette.primaryLight
            : SajuText.fg.withValues(alpha: 0.02),
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
                        ? (moon
                              ? IntroPalette.primary.withValues(alpha: 0.18)
                              : SajuText.fg.withValues(alpha: 0.12))
                        : Colors.transparent,
                    border: selected
                        ? Border.all(
                            color: moon
                                ? IntroPalette.primary
                                : SajuText.lineGold,
                          )
                        : null,
                  ),
                  child: Text(
                    o,
                    style: TextStyle(
                      fontFamily: moon ? 'Pretendard' : SajuType.ui,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? (moon ? IntroPalette.textPrimary : SajuGold.g100)
                          : (moon
                                ? IntroPalette.textSecondary
                                : SajuText.muted),
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
