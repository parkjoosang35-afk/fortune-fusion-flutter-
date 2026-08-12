import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/application/auth_provider.dart';
import '../application/saju_provider.dart';
import '../domain/saju_model.dart';

/// 03단계 §3.3 / 07단계 - SajuInputScreen (입력형 패턴)
/// 생년월일시 확인/수정, 주제 선택(재물/애정/직업/건강 멀티선택)
///
/// [사주 입력 화면 UI 개선 - sowoon.kr saju.html 스타일 이식]
/// 참고 사이트(sowoon.kr/saju.html)의 구성 요소를 앱 공용 디자인 토큰
/// (UnifiedColors/UnifiedText/UnifiedTokens) 안에서 재해석했다:
/// - 헤더 아래 "태어난 순간의 우주 지도" 서브타이틀
/// - 안내 카드(안내 문구 + info 아이콘, 얇은 테두리 카드)
/// - 양력/음력 선택을 Switch 대신 알약형 라디오칩(pill radio-chip)으로 변경
/// - 생년월일/출생시간 필드에 원형 아이콘 배경을 추가해 카드 느낌 강화
/// - CTA 버튼을 더 크고 강조된 pill 버튼(아이콘 포함)으로 변경
/// 데이터 흐름(생년월일/시간/음력/토픽/프로필 API 연동)은 기존 로직을
/// 전혀 변경하지 않고 그대로 재사용한다(순수 UI 개선, 회귀 없음).
class SajuInputScreen extends StatefulWidget {
  // [운세 카테고리 확장] 전체보기(all_categories_screen)에서 관리자 카테고리
  // (오행 재물운/직업운/연애운/건강운/월별운세 등)를 탭했을 때, 이 공용 입력
  // 화면의 토픽 멀티선택을 해당 주제로 미리 선택해두기 위한 선택적 인자.
  // null(기존 모든 진입 경로)이면 기존 동작과 완전히 동일하게 '종합'만
  // 기본 선택된다(회귀 없음).
  const SajuInputScreen({super.key, this.initialTopics});

  final List<String>? initialTopics;

  @override
  State<SajuInputScreen> createState() => _SajuInputScreenState();
}

class _SajuInputScreenState extends State<SajuInputScreen> {
  // [사주정보 이름 필드 보완] 메인 입력 폼에 이름 입력이 없던 문제를 해결하기
  // 위한 컨트롤러. 로그인 사용자는 닉네임으로 자동 채워지고, "내 사주함" 프로필을
  // 선택하면 해당 프로필의 실제 이름으로 갱신된다(둘 다 사용자가 직접 수정 가능).
  final TextEditingController _nameController = TextEditingController();
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  bool _isLunar = false;
  late final Set<String> _topics;
  String? _selectedProfileId;
  String? _selectedProfileName;
  bool _saveAsProfile = false;

  // [운세 카테고리 확장] '월별' 추가 → 사주 월별 운세(saju_monthly) 도메인과
  // 자연스럽게 연결(입력/결과 화면 구조는 기존 멀티 토픽 선택 방식 그대로 재사용).
  static const _allTopics = ['종합', '재물', '애정', '직업', '건강', '월별'];

  // [어뷰징 방지 개편 §신규 ②] 서버(saju route)가 주제마다 개별 LLM 호출을
  // Promise.allSettled로 동시에 발사하므로, 1회 요청당 최대 선택 개수를 제한해
  // "1회 이용 카운트당 최대 N번 AI 호출"의 실질 배수를 낮춘다. 서버(admin_web
  // saju/route.ts의 MAX_TOPICS_PER_REQUEST)도 동일한 값(3)으로 방어한다.
  static const _maxTopicSelection = 3;

  @override
  void initState() {
    super.initState();
    // [운세 카테고리 확장] 딥링크로 전달된 초기 토픽 중 실제 유효한
    // 토픽(_allTopics)만 필터링해 선택 상태로 시드한다. 전달값이 없거나
    // 전부 무효하면 기존 기본값('종합')으로 폴백한다.
    final validInitial = widget.initialTopics
        ?.where((t) => _allTopics.contains(t))
        .toSet();
    // [어뷰징 방지 개편 §신규 ②] 딥링크로 전달된 초기값도 최대 선택 개수를 넘지
    // 않도록 앞에서부터 잘라낸다.
    _topics = (validInitial == null || validInitial.isEmpty)
        ? {'종합'}
        : validInitial.take(_maxTopicSelection).toSet();
    final user = context.read<AuthProvider>().currentUser;
    if (user?.birthDate != null) {
      final parts = user!.birthDate!.split('-');
      _birthDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      _isLunar = user.isLunar;
      if (user.birthTime != null) {
        final t = user.birthTime!.split(':');
        _birthTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      }
    }
    // [사주정보 이름 필드 보완] 로그인 사용자의 닉네임으로 이름 입력을 자동
    // 프리필한다(다른 운세 입력 화면들과 동일한 패턴). 비로그인 상태이거나
    // 닉네임이 없으면 빈 값으로 두어 사용자가 직접 입력하게 한다.
    if (user?.nickname != null && user!.nickname.trim().isNotEmpty) {
      _nameController.text = user.nickname;
    }
    // [웹→앱 이식] saju.html "내 사주함" - 화면 진입 시 저장된 프로필 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SajuProvider>().loadProfiles();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _applyProfile(SajuProfileModel p) {
    final parts = p.birthDate.split('-');
    setState(() {
      _selectedProfileId = p.id;
      _selectedProfileName = p.profileName;
      // [사주정보 이름 필드 보완] "내 사주함" 프로필을 선택하면 해당 프로필의
      // 실제 이름(p.name)으로 이름 입력을 갱신한다.
      _nameController.text = p.name;
      _birthDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      _isLunar = p.isLunar;
      if (p.birthTime != null) {
        final t = p.birthTime!.split(':');
        _birthTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      } else {
        _birthTime = null;
      }
    });
  }

  /// [웹→앱 이식] saju.html `openSajuProfileModal` 대응 - 새 프로필 등록 바텀시트
  Future<void> _openAddProfileSheet() async {
    final nameController = TextEditingController();
    final aliasController = TextEditingController();
    String gender = '남';
    DateTime? pickerBirthDate = _birthDate;
    TimeOfDay? pickerBirthTime = _birthTime;
    bool pickerIsLunar = _isLunar;
    SajuRelationship relationship = SajuRelationship.self;

    await showAppBottomSheet(
      context,
      title: '새 프로필 등록',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: aliasController,
                decoration: const InputDecoration(hintText: '별칭 (예: 엄마 사주)'),
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: '이름'),
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                children: sajuRelationshipLabel.entries.map((e) {
                  final selected = relationship == e.key;
                  return ChoiceChip(
                    label: Text(e.value, style: UnifiedText.chipLabel()),
                    selected: selected,
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                    onSelected: (_) =>
                        setSheetState(() => relationship = e.key),
                  );
                }).toList(),
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              Row(
                children: [
                  Text('성별', style: UnifiedText.body()),
                  SizedBox(width: UnifiedTokens.spaceMd),
                  ChoiceChip(
                    label: Text('남', style: UnifiedText.chipLabel()),
                    selected: gender == '남',
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                    onSelected: (_) => setSheetState(() => gender = '남'),
                  ),
                  SizedBox(width: UnifiedTokens.spaceSm),
                  ChoiceChip(
                    label: Text('여', style: UnifiedText.chipLabel()),
                    selected: gender == '여',
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                    onSelected: (_) => setSheetState(() => gender = '여'),
                  ),
                ],
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              Row(
                children: [
                  Text('음력', style: UnifiedText.body()),
                  Switch(
                    value: pickerIsLunar,
                    onChanged: (v) => setSheetState(() => pickerIsLunar = v),
                    activeThumbColor: UnifiedColors.black,
                  ),
                ],
              ),
              _FieldTile(
                icon: Icons.cake_outlined,
                label: pickerBirthDate == null
                    ? '생년월일 선택'
                    : '${pickerBirthDate!.year}년 ${pickerBirthDate!.month}월 ${pickerBirthDate!.day}일',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: pickerBirthDate ?? DateTime(2000, 1, 1),
                    firstDate: DateTime(1930, 1, 1),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => pickerBirthDate = picked);
                  }
                },
              ),
              _FieldTile(
                icon: Icons.access_time_rounded,
                label: pickerBirthTime == null
                    ? '태어난 시간(선택)'
                    : pickerBirthTime!.format(sheetContext),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: sheetContext,
                    initialTime:
                        pickerBirthTime ?? const TimeOfDay(hour: 12, minute: 0),
                  );
                  if (picked != null) {
                    setSheetState(() => pickerBirthTime = picked);
                  }
                },
              ),
              SizedBox(height: UnifiedTokens.spaceMd),
              AppButton(
                label: '프로필 저장',
                onPressed:
                    pickerBirthDate == null || nameController.text.isEmpty
                    ? null
                    : () async {
                        final birthDateStr =
                            '${pickerBirthDate!.year}-${pickerBirthDate!.month.toString().padLeft(2, '0')}-${pickerBirthDate!.day.toString().padLeft(2, '0')}';
                        final birthTimeStr = pickerBirthTime != null
                            ? '${pickerBirthTime!.hour.toString().padLeft(2, '0')}:${pickerBirthTime!.minute.toString().padLeft(2, '0')}'
                            : null;
                        final ok = await context
                            .read<SajuProvider>()
                            .createProfile(
                              profileName: aliasController.text.isEmpty
                                  ? nameController.text
                                  : aliasController.text,
                              name: nameController.text,
                              gender: gender,
                              birthDate: birthDateStr,
                              birthTime: birthTimeStr,
                              isLunar: pickerIsLunar,
                              relationship: relationship,
                            );
                        if (ok && sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) setState(() => _birthTime = picked);
  }

  void _submit() {
    if (_birthDate == null) return;
    final birthDateStr =
        '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';
    final birthTimeStr = _birthTime != null
        ? '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}'
        : null;
    // [사주정보 이름 필드 보완] 이름 입력이 비어있으면 '게스트'로 폴백해
    // 서버/결과 화면에서 항상 유효한 이름 값을 사용할 수 있게 한다.
    final nameStr = _nameController.text.trim().isEmpty
        ? '게스트'
        : _nameController.text.trim();

    context.read<SajuProvider>().requestSaju(
      name: nameStr,
      birthDate: birthDateStr,
      birthTime: birthTimeStr,
      isLunar: _isLunar,
      topics: _topics.toList(),
      profileId: _selectedProfileId,
      profileName: _selectedProfileName,
    );
    if (_saveAsProfile && _selectedProfileId == null) {
      context.read<SajuProvider>().createProfile(
        profileName: '나',
        name: nameStr,
        gender: '남',
        birthDate: birthDateStr,
        birthTime: birthTimeStr,
        isLunar: _isLunar,
      );
    }
    Navigator.of(context).pushNamed('/ai-fortune/saju/loading');
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<SajuProvider>().profiles;
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('사주', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(UnifiedTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // [sowoon.kr saju.html 이식] 헤더 아래 서브타이틀 - "태어난 순간의 우주 지도"
              Text(
                '태어난 순간의 우주 지도',
                style: UnifiedText.body(color: UnifiedColors.textCaption),
              ),
              SizedBox(height: UnifiedTokens.spaceLg),

              // [sowoon.kr saju.html 이식] 안내 카드 - info 아이콘 + 설명 문구
              _InfoBanner(
                text: '타고난 사주팔자로 성격, 재물운, 배우자운 등을 깊이 있게 분석해드립니다.',
              ),
              SizedBox(height: UnifiedTokens.spaceXl),

              // [웹→앱 이식] saju.html "내 사주함" - 저장된 프로필이 있을 때만 노출
              if (profiles.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: UnifiedTokens.iconMd,
                      color: UnifiedColors.textPrimary,
                    ),
                    SizedBox(width: UnifiedTokens.spaceXs),
                    Text('내 사주함에서 선택', style: UnifiedText.title()),
                  ],
                ),
                SizedBox(height: UnifiedTokens.spaceSm),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: profiles.length + 1,
                    separatorBuilder: (_, __) =>
                        SizedBox(width: UnifiedTokens.spaceSm),
                    itemBuilder: (context, index) {
                      if (index == profiles.length) {
                        return _ProfileAddChip(onTap: _openAddProfileSheet);
                      }
                      final p = profiles[index];
                      return _ProfileChip(
                        profile: p,
                        selected: _selectedProfileId == p.id,
                        onTap: () => _applyProfile(p),
                      );
                    },
                  ),
                ),
                SizedBox(height: UnifiedTokens.spaceXl),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openAddProfileSheet,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('내 사주함에 추가'),
                  ),
                ),
              // [사주정보 이름 필드 보완] 다른 운세 입력 화면(오늘의 운세 등)과
              // 동일하게 메인 폼에도 이름 입력을 노출한다. "내 사주함" 프로필의
              // 실제 이름과는 별개로, 이번 1회 분석에 사용할 이름을 명시적으로
              // 입력/수정할 수 있게 한다.
              Text('이름', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: UnifiedTokens.spaceLg,
                ),
                decoration: BoxDecoration(
                  color: UnifiedColors.cardSection,
                  border: Border.all(color: UnifiedColors.border),
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                ),
                child: TextField(
                  controller: _nameController,
                  style: UnifiedText.body(color: UnifiedColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '이름을 입력해주세요',
                    hintStyle: UnifiedText.body(
                      color: UnifiedColors.textCaption,
                    ),
                    border: InputBorder.none,
                    isCollapsed: false,
                  ),
                ),
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              Text('생년월일시', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              _FieldTile(
                icon: Icons.cake_outlined,
                label: _birthDate == null
                    ? '생년월일 선택'
                    : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                onTap: _pickDate,
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              _FieldTile(
                icon: Icons.access_time_rounded,
                label: _birthTime == null
                    ? '태어난 시간(모르면 비워두세요)'
                    : _birthTime!.format(context),
                onTap: _pickTime,
              ),
              SizedBox(height: UnifiedTokens.spaceMd),

              // [sowoon.kr saju.html 이식] 양력/음력을 Switch 대신 알약형
              // 라디오칩(radio-chip) 2개로 표현 - 웹 원본의 시각 언어 재현.
              Text('양력 / 음력', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: _RadioChip(
                      label: '양력',
                      selected: !_isLunar,
                      onTap: () => setState(() => _isLunar = false),
                    ),
                  ),
                  SizedBox(width: UnifiedTokens.spaceSm),
                  Expanded(
                    child: _RadioChip(
                      label: '음력',
                      selected: _isLunar,
                      onTap: () => setState(() => _isLunar = true),
                    ),
                  ),
                ],
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              Text(
                '관심 주제 (최대 $_maxTopicSelection개 선택 가능)',
                style: UnifiedText.title(),
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                runSpacing: UnifiedTokens.spaceSm,
                children: _allTopics.map((t) {
                  final selected = _topics.contains(t);
                  // [어뷰징 방지 개편 §신규 ②] 이미 최대 개수를 선택한 상태에서
                  // 선택되지 않은 칩은 비활성화(탭 무시)해 추가 선택을 막는다.
                  final atMax = _topics.length >= _maxTopicSelection;
                  final disabled = !selected && atMax;
                  return FilterChip(
                    label: Text(t, style: UnifiedText.chipLabel()),
                    selected: selected,
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    checkmarkColor: UnifiedColors.black,
                    side: BorderSide.none,
                    onSelected: disabled
                        ? null
                        : (v) => setState(() {
                            if (v && _topics.length < _maxTopicSelection) {
                              _topics.add(t);
                            } else if (!v && _topics.length > 1) {
                              _topics.remove(t);
                            }
                          }),
                  );
                }).toList(),
              ),
              if (_selectedProfileId == null)
                CheckboxListTile(
                  value: _saveAsProfile,
                  onChanged: (v) => setState(() => _saveAsProfile = v ?? false),
                  title: Text('이 정보를 내 사주함에 저장', style: UnifiedText.body()),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              SizedBox(height: UnifiedTokens.spaceXxl),

              // [sowoon.kr saju.html 이식] btn-gold 스타일 - 더 크고 강조된
              // pill 버튼 + 아이콘. 로직은 기존 _submit()과 완전히 동일.
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _birthDate == null ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UnifiedColors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusPill,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 18),
                      SizedBox(width: UnifiedTokens.spaceSm),
                      Text(
                        '사주 분석하기',
                        style: UnifiedText.bodyStrong(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [sowoon.kr saju.html 이식] 안내 카드 - `<p class="form-hint">` 대응.
/// 옅은 배경 카드 + info 아이콘 + 안내 문구.
class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(UnifiedTokens.spaceXl),
      decoration: BoxDecoration(
        color: UnifiedColors.cardSection,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        border: Border.all(color: UnifiedColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: UnifiedTokens.iconLg,
            color: UnifiedColors.textPrimary,
          ),
          SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Text(
              text,
              style: UnifiedText.bodySmall(color: UnifiedColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// [sowoon.kr saju.html 이식] 알약형 라디오칩 - `.radio-chip` 대응.
/// 선택 시 블랙 배경 + 흰 글자, 비선택 시 옅은 배경 + 보더 없음(칩 통일 톤).
class _RadioChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: UnifiedTokens.spaceMd),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? UnifiedColors.black : UnifiedColors.chipInactiveBg,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
        child: Text(
          label,
          style: UnifiedText.bodyStrong(
            color: selected ? Colors.white : UnifiedColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// [웹→앱 이식] saju.html "내 사주함" 빠른선택 칩 - `renderProfilePicker()` 대응
class _ProfileChip extends StatelessWidget {
  final SajuProfileModel profile;
  final bool selected;
  final VoidCallback onTap;
  const _ProfileChip({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
      onTap: onTap,
      child: Container(
        width: 92,
        padding: EdgeInsets.all(UnifiedTokens.spaceSm),
        decoration: BoxDecoration(
          color: selected
              ? UnifiedColors.cardAllMenu
              : UnifiedColors.cardSection,
          border: Border.all(
            color: selected ? UnifiedColors.black : UnifiedColors.border,
          ),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (profile.isPrimary)
                  Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: UnifiedColors.black,
                  ),
                Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: selected
                      ? UnifiedColors.black
                      : UnifiedColors.textCaption,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              profile.profileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UnifiedText.bodySmall(
                color: selected
                    ? UnifiedColors.textPrimary
                    : UnifiedColors.textSecondary,
              ),
            ),
            Text(
              sajuRelationshipLabel[profile.relationship] ?? '',
              style: UnifiedText.caption(color: UnifiedColors.textCaption),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileAddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
      onTap: onTap,
      child: Container(
        width: 92,
        padding: EdgeInsets.all(UnifiedTokens.spaceSm),
        decoration: BoxDecoration(
          border: Border.all(color: UnifiedColors.border),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: UnifiedColors.textCaption,
            ),
            const SizedBox(height: 4),
            Text(
              '추가',
              style: UnifiedText.bodySmall(color: UnifiedColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// [sowoon.kr saju.html 이식] 필드 타일 - 원형 아이콘 배경을 추가해
/// 웹 원본 폼 그룹(`.form-group` + 아이콘 라벨)의 카드 느낌을 재현.
class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FieldTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: UnifiedTokens.spaceSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        child: Container(
          padding: EdgeInsets.all(UnifiedTokens.spaceLg),
          decoration: BoxDecoration(
            color: UnifiedColors.cardSection,
            border: Border.all(color: UnifiedColors.border),
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: UnifiedTokens.iconCircleLg,
                height: UnifiedTokens.iconCircleLg,
                decoration: BoxDecoration(
                  color: UnifiedColors.cardAllMenu,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: UnifiedTokens.iconMd,
                  color: UnifiedColors.textPrimary,
                ),
              ),
              SizedBox(width: UnifiedTokens.spaceMd),
              Expanded(
                child: Text(
                  label,
                  style: UnifiedText.body(color: UnifiedColors.textPrimary),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textCaption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
