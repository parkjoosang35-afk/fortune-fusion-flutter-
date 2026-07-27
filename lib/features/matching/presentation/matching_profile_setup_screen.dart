import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/matching_provider.dart';

/// 03§5.3 MatchingProfileSetupScreen(입력형 패턴 재사용, CompatibilityInputScreen과 동일 구조)
/// 04A M-1 matching_profiles(is_public/preferences JSONB/intro_text) 대응
class MatchingProfileSetupScreen extends StatefulWidget {
  const MatchingProfileSetupScreen({super.key});

  @override
  State<MatchingProfileSetupScreen> createState() =>
      _MatchingProfileSetupScreenState();
}

class _MatchingProfileSetupScreenState
    extends State<MatchingProfileSetupScreen> {
  static const _preferenceOptions = [
    '독서',
    '카페투어',
    '등산',
    '요리',
    '식물',
    '산책',
    '커피',
    '음악감상',
    '여행',
    '사진',
    '운동',
    '영화',
  ];

  final _introController = TextEditingController();
  bool _isPublic = true;
  final Set<String> _selectedPreferences = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final provider = context.read<MatchingProvider>();
    await provider.loadMyProfile();
    if (!mounted) return;
    final profile = provider.profileState.data;
    if (profile != null) {
      setState(() {
        _isPublic = profile.isPublic;
        _introController.text = profile.introText;
        _selectedPreferences.addAll(profile.preferences);
      });
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final ok = await context.read<MatchingProvider>().saveProfile(
      isPublic: _isPublic,
      introText: _introController.text.trim(),
      preferences: _selectedPreferences.toList(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      AppToast.show(context, '매칭 프로필이 저장되었습니다.');
      Navigator.of(
        context,
      ).pushReplacementNamed('/ai-fortune/matching/discover');
    } else {
      AppToast.show(context, '프로필 저장에 실패했습니다.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('매칭 프로필')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '프로필 공개',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isPublic
                                ? '다른 사용자에게 프로필이 노출됩니다'
                                : '추천 목록에 노출되지 않습니다',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('자기소개', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: TextField(
                  controller: _introController,
                  maxLines: 3,
                  maxLength: 100,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '나를 소개하는 한 줄을 적어주세요',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(AppSpacing.lg),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '관심사(이상형 조건)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _preferenceOptions.map((tag) {
                  final selected = _selectedPreferences.contains(tag);
                  return ChoiceChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedPreferences.add(tag);
                      } else {
                        _selectedPreferences.remove(tag);
                      }
                    }),
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: '프로필 저장하고 시작하기',
                isLoading: _isSaving,
                onPressed: (_introController.text.trim().isEmpty || _isSaving)
                    ? null
                    : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
