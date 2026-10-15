import 'package:flutter/material.dart';
import '../../../core/config/env_config.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_error_state.dart';
import '../data/share_api_service.dart';
import '../domain/share_result_model.dart';
import 'full_result_sheet.dart';
// [공유 콘텐츠 "실제 결과페이지 그대로" 근본 수정 — 2027-02] 귀인지도
// 공유 수신 화면은 더 이상 범용 텍스트 요약을 만들지 않고, 실제
// GuinjiMapRelationDetailScreen과 같은 테마/위젯(GmColors, GmChip,
// GmLabelMini, guinjiReasons)을 그대로 재사용해 아바타·점수·오행·판정근거
// 카드를 동일하게 재구성한다 — "두번째 스크린샷처럼 공유돼야 한다"는
// 사용자 요구 대응.
import '../../guinji/deep/guinji_reasons.dart';
import '../../guinji/domain/guinji_relation_meta.dart';
import '../../guinji/theme/guinji_map_theme.dart';
import '../../guinji/widgets/guinji_map_widgets.dart';

/// [결과 공유 기능] `/r/{shareId}` 딥링크(앱 설치 상태에서 App Links로
/// 직접 열렸거나, `GuinjiDeepLinkHandler`가 커스텀 스킴/https 링크를
/// 수신해 push한 경우) 도착 시 보여주는 화면.
///
/// [admin_web `/r/[id]` SSR 페이지와의 관계] 앱이 설치되지 않은 사용자는
/// admin_web의 `shared-result-view.tsx`(OG 태그 포함 SSR 웹페이지)를 보고,
/// 앱이 설치된 사용자는 이 화면으로 직접 도착한다 — 동일한
/// `GET /api/public/share/{shareId}` API를 호출해 동일한 데이터를 표시
/// 한다(웹/앱 양쪽에서 일관된 콘텐츠).
///
/// [비로그인 접근 허용] 이 화면은 로그인 여부와 무관하게 열람 가능하다
/// (shareId 자체가 유일한 접근 통제 수단 — NFR-03). 탈퇴/로그아웃 상태의
/// 사용자도 카카오톡으로 받은 링크를 눌러 앱이 열리면 정상적으로 결과를
/// 볼 수 있어야 한다.
class SharedResultScreen extends StatefulWidget {
  const SharedResultScreen({super.key, required this.shareId});

  final String shareId;

  @override
  State<SharedResultScreen> createState() => _SharedResultScreenState();
}

class _SharedResultScreenState extends State<SharedResultScreen> {
  final ShareApiService _api = ShareApiService();

  bool _loading = true;
  String? _error;
  SharedResultDto? _shared;
  Uint8List? _originalPng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.fetchSharedResult(widget.shareId);
    Uint8List? originalPng;
    String? originalError;
    if (result.success && result.data?.originalImageUrl != null) {
      final image = await _api.fetchOriginalPng(widget.shareId);
      if (image.success) {
        originalPng = image.data;
      } else {
        originalError = image.errorMessage ?? '원본 결과를 불러오지 못했어요.';
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success && result.data != null) {
        _shared = result.data;
        _originalPng = originalPng;
        _error = originalError;
      } else {
        _error = result.errorMessage ?? '공유된 결과를 찾을 수 없어요.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // [귀인지도 공유 = 실제 결과페이지 그대로 — 2027-02] relationship
    // 타입은 범용 Scaffold(흰 배경/일반 AppBar) 대신, 실제
    // GuinjiMapRelationDetailScreen과 동일한 다크 테마 전체를 그대로
    // 사용한다 — 로딩/에러 화면까지 톤을 맞춰야 전환이 어색하지 않다.
    final shared = _shared;
    final isRelationship =
        shared != null && shared.resultType == ShareResultType.relationship;
    if (isRelationship) {
      return Scaffold(
        backgroundColor: GmColors.bg,
        appBar: GmTopBar(back: true, title: shared.title),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: GmColors.gold),
                )
              : _error != null
              ? AppErrorState(message: _error!, onRetry: _load)
              : _buildRelationshipResult(context, shared),
        ),
      );
    }
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('공유된 결과', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? AppErrorState(message: _error!, onRetry: _load)
            : _buildResult(context, _shared!),
      ),
    );
  }

  /// [귀인지도 전용 — 실제 상세화면 레이아웃 1:1 재구성] person 인스턴스
  /// 데이터(personName/personBirth/score/ohaeng, `_handleShare` 참고)를
  /// 받아 아바타·점수·관계의 결·판정근거(S1~S5)·오행 카드를
  /// GuinjiMapRelationDetailScreen과 동일한 위젯(GmColors/GmChip 등)으로
  /// 다시 그린다. 원본 PNG가 있으면(과거 호환) 위 `_originalPng` 분기가
  /// 먼저 처리하므로 여기는 텍스트 payload 기반 재구성 경로다.
  Widget _buildRelationshipResult(BuildContext context, SharedResultDto shared) {
    final payload = shared.payload ?? const {};
    final relationType = payload['relationType'] as String? ?? 'BI_HWA';
    final meta = guinjiRelationMetaOf(relationType);
    final personName = payload['personName'] as String? ?? '지인';
    final personBirth = payload['personBirth'] as String? ?? '';
    final score = (payload['score'] as num?)?.toInt() ?? 0;
    final ohaengKey = payload['ohaeng'] as String?;
    final ohaeng = ohaengKey != null ? guinjiOhaengTypes[ohaengKey] : null;
    final note = payload['note'] as String? ?? '';
    final color = meta.color;
    final initial = personName.isNotEmpty ? personName.substring(0, 1) : '?';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Hero — 아바타 + 이름 + 관계 라벨 + 점수.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: GmColors.card,
            border: Border.all(color: GmColors.line),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.85)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: GmText.display,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GmChip(
                label: '${meta.hanja} ${meta.label}',
                background: color.withValues(alpha: 0.12),
                foreground: color,
                borderColor: color.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 10),
              Text(
                personName,
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GmColors.fg,
                ),
              ),
              if (personBirth.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  personBirth,
                  style: const TextStyle(fontSize: 11, color: GmColors.dim),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '/ 100',
                    style: TextStyle(fontSize: 13, color: GmColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                '관계 케미 점수',
                style: TextStyle(fontSize: 10.5, color: GmColors.dim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 관계의 결.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GmColors.card,
            border: Border.all(color: GmColors.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GmLabelMini('관계의 결'),
              const SizedBox(height: 10),
              Text(
                meta.long,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.7,
                  color: GmColors.fg,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 이렇게 판정했어요 (S1~S5).
        Builder(
          builder: (context) {
            final rows = guinjiReasons[relationType] ?? const [];
            if (rows.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: GmColors.card,
                  border: Border.all(color: GmColors.line),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GmLabelMini('이렇게 판정했어요'),
                    const SizedBox(height: 10),
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text(
                                row[0],
                                style: const TextStyle(
                                  fontFamily: GmText.mono,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: GmColors.dim,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row[1],
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: GmColors.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // 오행 근거.
        if (ohaeng != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GmColors.card,
              border: Border.all(color: GmColors.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ohaeng.color.withValues(alpha: 0.16),
                    border: Border.all(color: ohaeng.color.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    ohaeng.label,
                    style: TextStyle(
                      fontFamily: GmText.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: ohaeng.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ohaeng.name}(${ohaeng.label}) 기운의 사람',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: GmColors.fg,
                        ),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          note,
                          style: const TextStyle(fontSize: 11, color: GmColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // SPECIAL 해설 — 공유 시점에 이미 해금되어 있던 내용(meta.specialInsight/tips).
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GmColors.card,
            border: Border.all(color: GmColors.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GmLabelMini('SPECIAL · ${meta.label}', color: color),
              const SizedBox(height: 8),
              Text(
                meta.specialInsight,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.65,
                  color: GmColors.fg,
                ),
              ),
              const SizedBox(height: 12),
              ...meta.tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GmColors.gold.withValues(alpha: 0.06),
                      border: Border.all(color: GmColors.gold.withValues(alpha: 0.18)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: GmColors.muted,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Tip. ',
                            style: TextStyle(color: GmColors.gold),
                          ),
                          TextSpan(text: tip),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (shared.ownerNickname != null)
          Center(
            child: Text(
              '${shared.ownerNickname}님이 공유했어요',
              style: const TextStyle(fontSize: 11, color: GmColors.dim),
            ),
          ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
            child: const Text(
              '신통방통 홈으로 가기',
              style: TextStyle(color: GmColors.muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, SharedResultDto shared) {
    if (_originalPng != null) {
      return ListView(
        children: [
          Image.memory(
            _originalPng!,
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
          FilledButton(
            onPressed: () => showFullResultSheet(
              context,
              title: shared.title,
              shareUrl: EnvConfig.webResultUrl(shared.shareId),
              payload: shared.payload ?? const {},
              originalPng: _originalPng,
            ),
            child: const Text('원본 저장 · 공유'),
          ),
        ],
      );
    }
    // [결과 공유 링크 콘텐츠 부실 버그 수정] 기존에는 highlights만 단순
    // 나열해, 타로의 question/cardName처럼 서버 payload를 확장하며 새로
    // 추가한 키들이 화면에 전혀 표시되지 않았다("자기 타로 보고 잘
    // 맞는다하고 지인들한테 보내는건데 받은 사람들은 이게 모지?하고
    // 하겟지" — 사용자 리포트). resultType별로 알려진 추가 키
    // (question/cardName — 타로 전용)까지 화이트리스트로 인식해 요약
    // 바로 아래에 노출하고, highlights는 여전히 그 다음에 전체를 보여준다
    // (기존 6줄 상한 없이 전부 표시 — 앱 쪽은 SSR 웹처럼 초기 로딩
    // 대역폭 제약이 없으므로 굳이 자르지 않는다).
    final payload = shared.payload ?? const {};
    final highlights = fullResultSections(
      payload,
    ).map((section) => '${section['title']}\n${section['body']}').toList();
    final question = payload['question'] as String?;
    final cardName = payload['cardName'] as String?;
    return ListView(
      padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
      children: [
        Text(_typeLabel(shared.resultType), style: UnifiedText.caption()),
        const SizedBox(height: UnifiedTokens.spaceXs),
        Text(shared.title, style: UnifiedText.titleLarge()),
        const SizedBox(height: UnifiedTokens.spaceMd),
        if (cardName != null && cardName.isNotEmpty) ...[
          Text(
            '카드: $cardName',
            style: UnifiedText.body().copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
        ],
        if (question != null && question.isNotEmpty) ...[
          Text(
            '질문: $question',
            style: UnifiedText.body().copyWith(
              color: UnifiedColors.textSecondary,
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
        ],
        Container(
          padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
          decoration: BoxDecoration(
            color: UnifiedColors.cardAllMenu,
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
          ),
          child: Text(shared.description, style: UnifiedText.body()),
        ),
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: UnifiedTokens.spaceMd),
          ...highlights.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceSm),
              child: Text(h, style: UnifiedText.body()),
            ),
          ),
        ],
        FilledButton(
          onPressed: () => showFullResultSheet(
            context,
            title: shared.title,
            shareUrl: EnvConfig.webResultUrl(shared.shareId),
            payload: payload,
          ),
          child: const Text('전체 저장 · 공유'),
        ),
        const SizedBox(height: UnifiedTokens.spaceXl),
        if (shared.ownerNickname != null)
          Text('${shared.ownerNickname}님이 공유했어요', style: UnifiedText.caption()),
        const SizedBox(height: UnifiedTokens.spaceLg),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (r) => false),
            child: const Text('신통방통 홈으로 가기'),
          ),
        ),
      ],
    );
  }

  String _typeLabel(ShareResultType type) {
    switch (type) {
      // [하위호환] 기존에 이미 공유된 fortune 링크는 계속 "오늘의 운세"로
      // 표시된다(신규 공유는 saju를 사용 — ShareResultType 주석 참고).
      // ignore: deprecated_member_use_from_same_package
      case ShareResultType.fortune:
        return '오늘의 운세';
      case ShareResultType.tarot:
        return '타로';
      case ShareResultType.face:
        return '관상';
      case ShareResultType.palm:
        return '손금';
      case ShareResultType.wish:
        return '소원방';
      case ShareResultType.saju:
        return '정통사주';
      case ShareResultType.relationship:
        return '귀인지도';
    }
  }
}
