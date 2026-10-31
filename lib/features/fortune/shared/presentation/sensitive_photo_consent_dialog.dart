import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../sintong/theme/sintong_colors.dart';
import '../../sintong/theme/sintong_typography.dart';
import '../../sintong/widgets/sintong_button.dart';

/// [6-7-4-B-4 전면개정 — 2026-10-29] 얼굴관상·손금 기능 진입 시 필요한
/// "민감정보(얼굴·손바닥 사진) 처리 동의" 1회성 팝업.
///
/// 작업지시(`신통방통_이용약관_개인정보처리방침_개정판.md` A-4) 원문:
/// "얼굴관상·손금 기능 진입 시 별도 동의 팝업(1회. '사진은 분석에만
/// 사용되며 저장되지 않습니다' 문구 + 동의/거부. 거부 시 해당 기능만
/// 제한)". 개인정보처리방침 1조 다항과 동일한 문구를 사용한다.
///
/// SharedPreferences에 기능별(face/palm) 독립 플래그로 "이미 동의했는지"를
/// 저장한다(onboarding_gate_screen.dart의 `has_seen_onboarding_v1` 1회성
/// 플래그 패턴과 동일). 한 번 동의하면 그 이후로는 다시 묻지 않는다—단,
/// 거부한 경우에는 플래그를 저장하지 않아 다음 진입 시 다시 물어본다(거부는
/// "이번엔 아니다"일 뿐 "영구 거부"가 아니므로, 앱 설정 깊숙한 곳에 별도
/// 철회 UI를 만들 필요 없이 재진입 시 다시 선택할 수 있게 한다).
class SensitivePhotoConsentDialog {
  SensitivePhotoConsentDialog._();

  static String _prefsKey(String feature) => 'sensitive_photo_consent_$feature';

  /// 이미 동의한 적이 있으면 true.
  static Future<bool> hasAgreed(String feature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsKey(feature)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _markAgreed(String feature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey(feature), true);
    } catch (_) {
      // 저장 실패해도 이번 실행 흐름은 계속 진행(다음 진입 시 재노출될 수 있음).
    }
  }

  /// 이미 동의했으면 즉시 true를 반환하고, 처음이면 팝업을 띄워 사용자의
  /// 선택(동의=true/거부=false)을 반환한다. 동의 시에만 플래그를 저장한다.
  ///
  /// [featureLabel] 예: '관상', '손금' — 팝업 문구에 노출.
  /// [feature] 예: 'face', 'palm' — SharedPreferences 키 구분용.
  static Future<bool> ensureConsent(
    BuildContext context, {
    required String feature,
    required String featureLabel,
  }) async {
    if (await hasAgreed(feature)) return true;
    if (!context.mounted) return false;

    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConsentSheet(featureLabel: featureLabel),
    );

    if (agreed == true) {
      await _markAgreed(feature);
      return true;
    }
    return false;
  }
}

class _ConsentSheet extends StatelessWidget {
  final String featureLabel;
  const _ConsentSheet({required this.featureLabel});

  @override
  Widget build(BuildContext context) {
    // [반응형 화면 규격 통일 지시서] 이 시트는 고정 Column(mainAxisSize: min)에
    // SingleChildScrollView 보호가 없어, 작은 화면(320px대) + 큰 textScale
    // (1.5배 이상) 조합에서 안내문구가 길어지며 세로 RenderFlex 오버플로가
    // 발생했다(실측 320x568@1.5 65px, @2.0 430px, @2.5 882px). 내용이
    // 화면보다 작을 때는 기존과 시각적으로 동일하고, 넘칠 때만 스크롤되도록
    // SingleChildScrollView로 감싼다 — 디자인/문구/버튼 변경 없음.
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: SintongColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SintongColors.line),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: SintongColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$featureLabel 분석을 위한 사진 처리 동의',
                      style: SintongType.cardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '사진은 분석에만 사용되며 저장되지 않습니다.',
                style: SintongType.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '촬영 또는 선택한 사진은 얼굴·손금 분석 응답을 생성하는 목적으로만 '
                'AI 모델에 일시적으로 전송되며, 분석이 끝나면 즉시 파기되고 회사 '
                '서버에 별도로 저장되지 않습니다. 동의하지 않으셔도 다른 기능은 '
                '계속 이용하실 수 있으며, 이 경우 $featureLabel 기능만 제한됩니다.',
                style: SintongType.caption,
              ),
              const SizedBox(height: 18),
              SintongPrimaryButton(
                label: '동의하고 계속하기',
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 8),
              SintongGhostButton(
                label: '거부하기',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
