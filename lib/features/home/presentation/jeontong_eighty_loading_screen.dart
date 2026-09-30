// ============================================================
// [운세 섹션 4단계 흐름 - 화면3 · 만세력 계산 로딩]
// 원본: flutter_handoff.zip screens/saju_loading_screen.dart
// (만세력 책 페이지 넘김 애니메이션 + 천간·지지 스트림 + 4단계 순차
// 진행 + 하단 진행바)의 시각 디자인을 100% 재현하되, 이 프로젝트는
// flutter_riverpod/go_router를 쓰지 않으므로 StatefulWidget +
// Navigator + 기존 HanjiColors/HanjiTextStyles 토큰 기반으로 이식한다.
//
// [사용자 명시 요구사항 재확인] "69종중에 1개을 선택을하면 정보창이뜨고
// 사주보기을누르면 로딩창 디자인이 뜨며 다음애 결과페이지가 뜨게" — 이전
// 구현이 이 로딩 화면(화면3) 자체를 완전히 빠뜨리고 목록/입력에서 결과로
// 곧장 점프해 지적을 받았다. 이 파일이 그 누락을 채운다.
//
// [계산 재사용 원칙] 신규 계산 로직을 만들지 않는다 — 이미 검증된
// [jeontongReportCache.getOrBuild]를 애니메이션 진행 중 1회 호출해 결과를
// "미리 데워두고"(warm), 애니메이션이 끝나면 결과 화면으로 넘어간다.
// 결과 화면(JeontongEightyResultScreen)은 동일한 캐시 키로 다시
// getOrBuild()를 호출하므로 캐시 히트로 즉시 렌더링된다(중복 계산 아님 —
// LRU+TTL 캐시가 같은 입력에 대해 항상 같은 결과를 반환하는 순수 함수
// 호출이므로 여러 번 호출해도 부작용이 없다).
//
// [원상복구] 부적게이트를 이 화면(결과 로딩) 뒤에 배선했던 것은 사용자가
// 요청한 위치가 아니었다(사용자는 "운세 섹션 진입 시" 인트로 게이트를
// 원했다 — 카테고리 선택 후 결과 계산 로딩이 아니다). 그 잘못된 배선을
// 전부 되돌려 이 화면은 원래대로 8초 애니메이션 후 곧장 결과 화면으로
// 이동한다. 부적게이트는 [JeontongEightyScreen](69종 목록) 진입 직전으로
// 옮겨 배선한다.
//
// [게이트 재검증 없음] 이 화면에 도달하는 시점에는 이미
// `navigateWithPassGate()`가 게이트 체크(로그인/프리패스 소비)를 마친
// 상태다. 따라서 이 화면에서 결과 화면으로 넘어갈 때는 게이트를 다시
// 통과시키지 않고(중복 소비 방지) `pushReplacementNamed`로 곧장 이동한다
// (뒤로가기 시 로딩 화면을 건너뛰어 입력/목록 화면으로 바로 돌아가게
// 하기 위해 push가 아닌 replace를 사용).
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../fortune/saju_v3/data/saju_v3_api.dart';
import '../../result_access/application/result_access_provider.dart';
import '../data/jeontong_profile_store.dart';
import '../domain/jeontong_eighty_matrix.dart';
import '../domain/jeontong_input.dart';
import '../domain/jeontong_report_cache.dart';
import '../domain/jeontong_v3_prefetch_cache.dart';
import '../domain/jeontong_v3_report_mapping.dart';
import 'jeontong_design/hanji_background.dart';
import 'jeontong_design/hanji_design_tokens.dart';
import 'jeontong_design/saju_seal.dart';

/// 로딩 화면에 표시할 4단계 — handoff `data/saju_calc_service.dart`의
/// `kCalcSteps`와 라벨을 그대로 재현(신규 개념 추가 없음).
class _CalcStep {
  final String label;
  const _CalcStep(this.label);
}

const List<_CalcStep> _kCalcSteps = [
  _CalcStep('만세력 조회'),
  _CalcStep('사주 원국 배열'),
  _CalcStep('오행 분석'),
  _CalcStep('대운 계산'),
];

class JeontongEightyLoadingScreen extends StatefulWidget {
  const JeontongEightyLoadingScreen({
    super.key,
    required this.categoryId,
    this.transactionId,
  });

  /// 결과를 보여줄 카테고리 id(예: 'A01'). null이면(비정상 진입) 애니메이션만
  /// 재생하고 결과 화면으로 넘어가 [JeontongEightyResultScreen]의 자체
  /// "준비 중" 안내를 그대로 보여준다(신규 에러 UI를 만들지 않는다).
  final String? categoryId;

  /// [결과보기 통합 권한 시스템 v1.0, §8 적용] §8.5에서 이미 차감(begin)이
  /// 확정된 거래의 id. null이면(구 호출부 하위호환 또는 비정상 진입) §8
  /// complete()/fail() 호출을 건너뛴다 — 기존 동작 그대로 유지(회귀 없음).
  final String? transactionId;

  @override
  State<JeontongEightyLoadingScreen> createState() =>
      _JeontongEightyLoadingScreenState();
}

class _JeontongEightyLoadingScreenState
    extends State<JeontongEightyLoadingScreen>
    with TickerProviderStateMixin {
  // [로딩 재설계 — 사용자 리포트: "로딩 끝나고 빈 결과페이지가 한참
  // 보인다"] 기존에는 report만 대기하고 interpret/narrative는 기다리지
  // 않은 채 결과화면으로 넘어갔다 — 그 둘이 늦게 끝나면 결과화면
  // 진입 후에도 스켈레톤이 계속 보이는 이중 대기가 발생했다(실측
  // 확인: report 자체도 QA 재시도로 36초가 걸리는 사례 존재).
  //
  // [해결 원칙] "로딩 화면이 끝나면 바로 완성된 결과가 나와야 한다"는
  // 사용자 요구에 따라, report·interpret·narrative 3종 모두를
  // 로딩화면에서 끝까지 기다린 뒤에만 결과화면으로 넘어간다(실패해도
  // 끝난 것으로 간주 — 결과화면이 이미 자체 에러 상태를 그릴 수
  // 있으므로 예외를 삼키고 "완료"로 취급한다). 연출 최소 시간은
  // 4초를 유지하되, 실제 데이터가 이미 끝나 있으면 그 이상 억지로
  // 늘리지 않고, 반대로 데이터가 늦게 끝나면 진행바가 92%~98%
  // 구간에서 천천히(트리클) 움직이며 자연스럽게 대기 — 멈춰 보이지
  // 않게 한다. 완료되는 즉시 100%로 스냅하고 이동한다.
  static const _minDuration = Duration(seconds: 4);
  static const _trickleFloor = 0.92;
  static const _trickleCeiling = 0.98;

  late final AnimationController _progressCtrl;
  late final AnimationController _pageFlipCtrl;
  late final AnimationController _streamCtrl;
  late final Future<void> _minTimeFuture;
  Timer? _trickleTimer;

  int _stepIndex = 0;
  bool _navigated = false;
  bool _dataReady = false;
  bool _minTimeElapsed = false;
  JeontongInput? _profile;

  // [69종 리딩 지연 개선 — P0] 프로필이 있을 때만 쓰는 saju_v3 API
  // 클라이언트. 결과화면(jeontong_eighty_result_screen.dart)이 만드는
  // 것과 동일한 생성 방식(EnvConfig 기반)이며, 이 화면 전용 인스턴스를
  // 새로 만든다 — 두 화면이 인스턴스를 공유할 필요는 없다(호출 결과만
  // [jeontongV3PrefetchCache]를 통해 공유하면 충분).
  late final SajuV3Api _v3Api = SajuV3Api(
    baseUrl: EnvConfig.adminApiBaseUrl,
    freePassProvider: () =>
        EnvConfig.sajuFreePassToken.isEmpty ? null : EnvConfig.sajuFreePassToken,
  );

  /// [결과보기 통합 권한 시스템 v1.0, §8.6] 계산 실패 시 true — 애니메이션을
  /// 멈추고 실패 안내 화면으로 전환한다. 이미 환불(fail())도 함께 처리된다.
  bool _calcFailed = false;

  String get _userId =>
      (AuthTokenStore.cachedUserIdOrNull ?? AuthTokenStore.fallbackUserId)
          .toString();

  @override
  void initState() {
    super.initState();
    // [최소 연출 시간] 0→92%까지는 _minDuration 동안 정상 진행. 92%
    // 이후는 실제 데이터 완료 여부에 따라 [_startTrickle]이 이어받아
    // 92%~98% 구간을 천천히 채운다(아래 참고). upperBound는 1.0
    // 그대로 두어(기본값) 완료 시 [_maybeFinish]가 1.0으로 스냅할 수
    // 있게 한다 — animateTo(0.92)로 "92%까지만" 먼저 이동시킨다.
    _progressCtrl = AnimationController(vsync: this, duration: _minDuration);
    _minTimeFuture = _progressCtrl
        .animateTo(_trickleFloor, duration: _minDuration)
        .then((_) {
          if (mounted) _startTrickle();
        });
    _pageFlipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _streamCtrl = AnimationController(
      vsync: this,
      duration: HanjiMotion.ganjiStream,
    )..repeat();

    _progressCtrl.addListener(() {
      final t = _progressCtrl.value;
      final newStep = (t / _trickleFloor * _kCalcSteps.length).floor().clamp(
        0,
        _kCalcSteps.length - 1,
      );
      if (newStep != _stepIndex) {
        setState(() => _stepIndex = newStep);
      }
    });
    _startCalculation();
  }

  /// [92%~98% 트리클] 최소 연출 시간(4초)이 끝났는데도 데이터가 아직
  /// 도착하지 않았을 때 진행바가 멈춰 보이지 않도록 아주 천천히(0.4초마다
  /// 0.3%씩) 98%까지만 계속 채운다 — 사용자가 "멈췄다"고 느끼지 않게
  /// 하는 순수 시각 효과이며, 실제 완료 판정과는 무관하다(완료되면
  /// [_maybeFinish]가 즉시 100%로 스냅하고 이 타이머를 정지한다).
  void _startTrickle() {
    _trickleTimer?.cancel();
    if (_dataReady) return;
    _trickleTimer = Timer.periodic(const Duration(milliseconds: 400), (
      timer,
    ) {
      if (!mounted || _dataReady) {
        timer.cancel();
        return;
      }
      final next = (_progressCtrl.value + 0.003).clamp(
        0.0,
        _trickleCeiling,
      );
      _progressCtrl.value = next;
    });
  }

  Future<void> _startCalculation() async {
    // [결과보기 통합 권한 시스템 v1.0, §8.5/§8.6] 정통사주는 서버 API를
    // 전혀 호출하지 않는 순수 클라이언트 로컬 계산이므로, saju/tarot처럼
    // 서버가 내부에서 처리해주는 completeResultAccess/failAndRefundResultAccess
    // 를 이 화면이 직접 호출해야 한다. §8.5에서 이미 차감(begin)이 확정된
    // transactionId가 있을 때만 이 절차를 수행한다 — transactionId가
    // null이면(구 호출부 하위호환) 기존과 동일하게 §8 호출 없이 진행한다.
    JeontongCategoryEntry? entry;
    Object? calcError;
    // [로딩 재설계] 프로필이 있으면(=saju_v3 백엔드 기반 결과화면을 탈
    // 대상) 여기서 미리 시작해 둔 saju_v3 응답 Future 3종(report·
    // interpret·narrative) 전부를 대기 게이트로 쓴다 — "로딩 화면이
    // 끝나면 바로 완성된 결과가 나와야 한다"는 요구에 따라, 결과화면이
    // 렌더링할 모든 섹션(사주풀이/강점·조심할점/대운흐름/실전조언)의
    // 데이터 소스가 실제로 준비된 뒤에만 넘어간다.
    Future<void>? allDataPrefetch;
    try {
      final profile = await jeontongProfileStore.get(_userId);
      if (!mounted) return;
      _profile = profile;

      entry = JeontongEightyMatrix.byId(widget.categoryId ?? '');
      if (entry != null) {
        if (profile != null) {
          // [69종 리딩 지연 개선 — P0 이중 로딩 제거] 결과화면이 나중에
          // 다시 요청을 시작하는 대신, 여기서 saju_v3 API 3종을 미리
          // 시작해 결과화면 진입 시점까지 기다린 시간만큼 체감 대기를
          // 줄인다. [jeontongV3PrefetchCache]가 in-flight Future를
          // 들고 있다가 결과화면이 그대로 이어받는다(중복 호출 없음).
          final birth = jeontongInputToBirthInput(profile);
          final question = jeontongAutoQuestionForCategory(entry.title);
          final bundle = jeontongV3PrefetchCache.start(
            api: _v3Api,
            categoryId: entry.id,
            birth: birth,
            question: question,
          );
          // 개별 요청의 실패는 여기서 이 화면의 §8.6 환불 판단에 영향을
          // 주지 않는다(정통사주는 로컬 계산 성공 여부로만 환불을 판단
          // — 기존 원칙 그대로 유지). 오직 "언제 결과화면으로 넘어갈지"
          // 타이밍에만 쓰므로 예외를 삼킨다(결과화면이 이미 자체
          // LoadState.error 처리를 갖고 있다) — 3개 모두 끝나야(성공이든
          // 실패든) 완료로 간주한다.
          allDataPrefetch = Future.wait<void>([
            bundle.report.then((_) {}, onError: (_) {}),
            bundle.interpret.then((_) {}, onError: (_) {}),
            bundle.narrative.then((_) {}, onError: (_) {}),
          ]).then((_) {});
        }
        // [계산 재사용] 이미 검증된 jeontongReportCache.getOrBuild를 여기서
        // 1회 호출해 결과를 캐시에 "미리 데워둔다"(warm) — 결과 화면이 동일
        // 캐시 키로 다시 호출하면 캐시 히트로 즉시 렌더링된다(중복 계산
        // 아님). 이 호출이 예외를 던지면 아래 catch에서 §8.6 환불로 이어진다.
        jeontongReportCache.getOrBuild(
          entry: entry,
          userId: profile != null ? _userId : null,
          birthDateTimeUtc: profile?.birthDateTimeUtc,
          gender: profile?.gender,
          isLunar: profile?.isLunar,
        );
      }
    } catch (e) {
      calcError = e;
    }

    final transactionId = widget.transactionId;
    if (transactionId != null) {
      if (entry != null && calcError == null) {
        // §8.5 성공 확정 — fortuneRequestId가 없는 콘텐츠이므로 서버가
        // null로 저장한다(§8 적용 설계 문서 1단계).
        await context.read<ResultAccessProvider>().complete(transactionId);
      } else {
        // §8.6 실패 환불 — entry를 찾지 못했거나(카테고리 id 불일치 등)
        // 계산 자체가 예외를 던진 경우 모두 여기로 온다.
        await context.read<ResultAccessProvider>().fail(transactionId);
        if (!mounted) return;
        setState(() => _calcFailed = true);
        return;
      }
    }

    if (!mounted) return;

    // [로딩 재설계] 최소 연출 시간(4초, _progressCtrl이 이미 진행 중)과
    // saju_v3 3종 응답 완료 중 "더 늦게 끝나는 쪽"에 맞춰 넘어간다.
    // - 데이터가 4초보다 먼저 끝나면(캐시 히트 등) 애니메이션이 끝날
    //   때까지만 대기 → 로딩 화면이 너무 순식간에 사라지지 않는다.
    // - 데이터가 4초보다 오래 걸리면(실제 LLM 처리) 애니메이션은 92%에서
    //   멈추지 않고 트리클로 98%까지 천천히 채우며 자연스럽게 대기 →
    //   결과화면 진입 직후 스켈레톤이 보이는 이중 대기를 없앤다. 데이터가
    //   없는(프로필 미설정 등) 경로는 allDataPrefetch가 null이므로 최소
    //   연출 시간만 기다리고 곧장 넘어간다(기존과 동일).
    if (allDataPrefetch != null) {
      unawaited(
        allDataPrefetch.then((_) {
          if (!mounted) return;
          _dataReady = true;
          _maybeFinish();
        }),
      );
    } else {
      _dataReady = true;
    }
    await _minTimeFuture;
    if (!mounted) return;
    _minTimeElapsed = true;
    _maybeFinish();
  }

  /// [최소 연출 시간 AND 데이터 준비 완료] 둘 다 충족했을 때만 정확히
  /// 한 번 결과화면으로 이동한다. 진행바를 100%로 스냅해 "완료됐다"는
  /// 시각 피드백을 준 뒤 다음 프레임에 이동한다.
  void _maybeFinish() {
    if (!mounted || _navigated) return;
    if (!_dataReady || !_minTimeElapsed) return;
    _navigated = true;
    _trickleTimer?.cancel();
    _progressCtrl.value = 1.0;
    Navigator.of(context).pushReplacementNamed(
      JeontongEightyMatrix.resultRoute,
      arguments: widget.categoryId,
    );
  }

  @override
  void dispose() {
    _trickleTimer?.cancel();
    _progressCtrl.dispose();
    _pageFlipCtrl.dispose();
    _streamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [결과보기 통합 권한 시스템 v1.0, §8.6] 계산 실패(+환불 완료) 시
    // saju_result_screen.dart와 동일한 공유 에러 위젯(AppErrorState)으로
    // 안내한다 — 신규 에러 UI를 만들지 않는다.
    if (_calcFailed) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: '사주 풀이 계산에 실패했습니다. 이용하신 결제수단은 환불되었어요.',
            onRetry: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    final birthLabel = _profile == null
        ? '◇ · ◇ · ◇'
        : '${_profile!.birthDateTimeLocal.year} · '
              '${_profile!.birthDateTimeLocal.month.toString().padLeft(2, '0')} · '
              '${_profile!.birthDateTimeLocal.day.toString().padLeft(2, '0')}';

    return Scaffold(
      body: HanjiBackground(
        sigilOpacity: 0.20,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              const MonoLabel(
                '◈ CALCULATING · 03 / 04',
                color: HanjiColors.accent,
              ),
              const SizedBox(height: 8),
              Text(
                '만세력을 펼치고\n사주를 세우는 중',
                textAlign: TextAlign.center,
                style: HanjiTextStyles.display2().copyWith(height: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                '"간절히 원하면, 온 우주가 도와준다"',
                textAlign: TextAlign.center,
                style: HanjiTextStyles.bodySmall().copyWith(fontSize: 12),
              ),
              const SizedBox(height: 24),

              _MansaeryeokBook(
                pageFlipAnimation: _pageFlipCtrl,
                birthLabel: birthLabel,
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HanjiSpacing.xl,
                ),
                child: _GanjiStream(controller: _streamCtrl),
              ),
              const SizedBox(height: HanjiSpacing.xxl),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HanjiSpacing.xl,
                ),
                child: _StepList(activeIndex: _stepIndex),
              ),
              const Spacer(),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HanjiSpacing.xl,
                  0,
                  HanjiSpacing.xl,
                  12,
                ),
                child: AnimatedBuilder(
                  animation: _progressCtrl,
                  builder: (context, _) => Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(HanjiRadii.pill),
                        child: LinearProgressIndicator(
                          value: _progressCtrl.value,
                          minHeight: 3,
                          backgroundColor: HanjiColors.sigil.withValues(
                            alpha: 0.15,
                          ),
                          valueColor: const AlwaysStoppedAnimation(
                            HanjiColors.glow,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      MonoLabel('${(_progressCtrl.value * 100).round()}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 만세력 책 ────────────────────────────────────────────
class _MansaeryeokBook extends StatelessWidget {
  final AnimationController pageFlipAnimation;
  final String birthLabel;

  const _MansaeryeokBook({
    required this.pageFlipAnimation,
    required this.birthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 170,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(-20),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    HanjiColors.glowShadow,
                    HanjiColors.glowShadow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Expanded(child: _BookPage(side: _BookSide.left)),
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF4A2F15),
                      Color(0xFF8B5A2B),
                      Color(0xFF4A2F15),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: pageFlipAnimation,
                  builder: (context, child) {
                    final t = pageFlipAnimation.value;
                    double angle = 0;
                    if (t > 0.4 && t < 0.6) {
                      angle = -0.44;
                    } else if (t < 0.4) {
                      angle = -0.44 * (t / 0.4);
                    } else {
                      angle = -0.44 * (1 - (t - 0.6) / 0.4);
                    }
                    return Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      child: child,
                    );
                  },
                  child: const _BookPage(side: _BookSide.right),
                ),
              ),
            ],
          ),
          Positioned(
            top: -14,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [MonoLabel('MANSAERYEOK'), MonoLabel('萬歲曆')],
            ),
          ),
          Positioned(
            bottom: -18,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [MonoLabel(birthLabel), const MonoLabel('p. 214')],
            ),
          ),
        ],
      ),
    );
  }
}

enum _BookSide { left, right }

class _BookPage extends StatelessWidget {
  final _BookSide side;
  const _BookPage({required this.side});

  @override
  Widget build(BuildContext context) {
    final columns = side == _BookSide.left
        ? const [
            ['壬', '申', '年'],
            ['丁', '未', '月'],
            ['癸', '酉', '日'],
            ['丁', '巳', '時'],
          ]
        : const [
            ['◇', '◇', '◇'],
            ['壬', '申', '年'],
            ['丁', '未', '月'],
            ['◇', '◇', '◇'],
          ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3E5C3), Color(0xFFE8D5A3)],
        ),
        borderRadius: BorderRadius.horizontal(
          left: side == _BookSide.left ? const Radius.circular(3) : Radius.zero,
          right: side == _BookSide.right
              ? const Radius.circular(3)
              : Radius.zero,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        textDirection: TextDirection.rtl,
        children: columns.map((col) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: col.map((ch) {
              final isMarker = ch == '年' || ch == '月' || ch == '日' || ch == '時';
              final isDiamond = ch == '◇';
              return Container(
                width: 18,
                height: 24,
                margin: const EdgeInsets.only(top: 4),
                alignment: Alignment.center,
                decoration: isMarker
                    ? const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x404A2F15)),
                        ),
                      )
                    : null,
                child: Text(
                  ch,
                  style:
                      HanjiTextStyles.display1(
                        color: isDiamond
                            ? const Color(0x598B5A2B)
                            : (isMarker
                                  ? const Color(0x8C4A2F15)
                                  : const Color(0xFF2A1F14)),
                      ).copyWith(
                        fontSize: isMarker ? 11 : 16,
                        fontWeight: isMarker
                            ? FontWeight.w400
                            : FontWeight.w900,
                      ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 천간·지지 스트림 ───────────────────────────────────
class _GanjiStream extends StatelessWidget {
  final AnimationController controller;
  const _GanjiStream({required this.controller});

  static const _gan = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
  static const _ji = [
    '子',
    '丑',
    '寅',
    '卯',
    '辰',
    '巳',
    '午',
    '未',
    '申',
    '酉',
    '戌',
    '亥',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HanjiColors.sigil.withValues(alpha: 0.05),
        border: Border.all(color: HanjiColors.line),
        borderRadius: BorderRadius.circular(HanjiRadii.card - 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              MonoLabel('천간지지 · 60갑자 조합 중'),
              Text(
                '· · ·',
                style: TextStyle(color: HanjiColors.muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _StreamLine(
            chars: _gan,
            controller: controller,
            reverse: false,
            accent: HanjiColors.accent,
          ),
          const SizedBox(height: 4),
          _StreamLine(
            chars: _ji,
            controller: controller,
            reverse: true,
            accent: HanjiColors.glow,
          ),
        ],
      ),
    );
  }
}

class _StreamLine extends StatelessWidget {
  final List<String> chars;
  final AnimationController controller;
  final bool reverse;
  final Color accent;
  const _StreamLine({
    required this.chars,
    required this.controller,
    required this.reverse,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 24,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = reverse ? 1 - controller.value : controller.value;
            return LayoutBuilder(
              builder: (context, cs) {
                final tripled = [...chars, ...chars, ...chars];
                return ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0, 0.15, 0.85, 1],
                  ).createShader(rect),
                  child: Transform.translate(
                    offset: Offset(-t * cs.maxWidth * 0.9, 0),
                    child: Row(
                      children: [
                        for (int i = 0; i < tripled.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              tripled[i],
                              style:
                                  HanjiTextStyles.display1(
                                    color: i % 10 == 3
                                        ? accent
                                        : HanjiColors.fg,
                                  ).copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── 진행 단계 리스트 ───────────────────────────────────
class _StepList extends StatelessWidget {
  final int activeIndex;
  const _StepList({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HanjiColors.card,
        border: Border.all(color: HanjiColors.line),
        borderRadius: BorderRadius.circular(HanjiRadii.card - 2),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _kCalcSteps.length; i++)
            _StepRow(
              step: _kCalcSteps[i],
              state: i < activeIndex
                  ? _StepState.done
                  : i == activeIndex
                  ? _StepState.active
                  : _StepState.pending,
              index: i,
            ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  final _CalcStep step;
  final _StepState state;
  final int index;
  const _StepRow({
    required this.step,
    required this.state,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: state == _StepState.pending ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _StepIcon(state: state),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                step.label,
                style: HanjiTextStyles.bodyTitle().copyWith(
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
            MonoLabel(
              state == _StepState.active
                  ? '계산 중…'
                  : 'STEP ${(index + 1).toString().padLeft(2, '0')}',
              color: state == _StepState.active ? HanjiColors.accent : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final _StepState state;
  const _StepIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == _StepState.done) {
      return Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: HanjiColors.accent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          '✓',
          style: TextStyle(
            color: Color(0xFFFFF9E8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (state == _StepState.active) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(HanjiColors.glow),
        ),
      );
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HanjiColors.line, width: 1.5),
      ),
    );
  }
}
