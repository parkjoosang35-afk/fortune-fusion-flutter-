import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/main_bottom_nav_bar.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../home/domain/jeontong_eighty_report_builder.dart';
import '../../../home/domain/saju_engine.dart' show SajuResult;
import '../../../home/domain/saju_interpreter.dart';
import '../../../home/domain/user_profile_to_jeontong_adapter.dart';
import '../../application/shrine_v3_provider.dart';
import '../../domain/shrine_categories.dart';
import '../../domain/talisman_item.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/shrine_asset_path.dart';
import '../widgets/talisman_thumb.dart';
import 'shrine_v3_detail_screen.dart';
import 'shrine_v3_pick_screen.dart';

/// 신당(THE SHRINE) v3 — 06 추천받기.
///
/// [사용자 확정 요구사항 #1] 이 화면은 완전 무료다 — 서버 호출도, 결제도
/// 전혀 하지 않는다. 사주 계산은 기존 PHASE1~4 엔진
/// ([JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4])을
/// `guinji_provider.dart`와 완전히 동일한 방식으로 "클라이언트에서 한 번
/// 더" 호출할 뿐, 새로운 계산이나 서버 과금을 전혀 발생시키지 않는다.
/// 소망을 고르면 카테고리 매핑으로 카탈로그에서 추천 부적만 찾아 보여준다
/// (이것도 이미 로드된 [ShrineV3Provider.catalog]를 메모리에서 필터링할
/// 뿐 — 서버 재호출 없음).
class ShrineV3RecScreen extends StatefulWidget {
  const ShrineV3RecScreen({super.key});

  @override
  State<ShrineV3RecScreen> createState() => _ShrineV3RecScreenState();
}

class _ShrineV3RecScreenState extends State<ShrineV3RecScreen> {
  String? _selectedWish; // kShrineWishes의 label(l)

  SajuResult? _saju;
  bool _sajuTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryComputeSaju());
  }

  /// [무료/클라이언트 전용] 로그인 + 실명/생년월일이 모두 갖춰진 경우에만
  /// 계산한다. 하나라도 없으면 조용히 건너뛰고(= 소망 버튼만 노출) 화면이
  /// 깨지지 않게 한다 — 이 화면은 "사주를 강제"하지 않는다.
  void _tryComputeSaju() {
    if (_sajuTried) return;
    _sajuTried = true;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final jeontongInput = userModelToJeontongInput(user);
    if (jeontongInput == null) return;
    try {
      final kst = jeontongInput.birthDateTimeUtc.add(const Duration(hours: 9));
      final sajuGender = jeontongInput.gender == 'F' ? 'female' : 'male';
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: sajuGender,
        isLunar: jeontongInput.isLunar,
        isLeapMonth: jeontongInput.effectiveIsLeapMonth,
        referenceDate: DateTime.now(),
      );
      if (!mounted) return;
      setState(() => _saju = built.saju);
    } catch (_) {
      // 계산 실패 시(드묾) 사주 카드 없이 소망 버튼만으로 진행.
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShrineV3Provider>();
    final nickname =
        context.watch<AuthProvider>().currentUser?.nickname ?? '손님';

    (String, String, String)? wish;
    for (final w in kShrineWishes) {
      if (w.$2 == _selectedWish) wish = w;
    }
    final category = wish?.$3;
    // [試(시험·합격) → suneung 단일 카테고리 고정 문제 수정] 기존에는
    // "시험·합격"을 고르면 무조건 수능 전용 카테고리(`suneung`)만 보여줘서,
    // 일반 자격증·시험을 찾는 사용자도 항상 "수능대합격부" 계열만 추천받는
    // 구조적 오류가 있었다. 이제 `suneung`이 선택되면 더 폭넓은 일반
    // 시험·학업 카테고리(`exam`: 시험부/학업부/문창부/합격부/결심부/재능부/
    // 집중부)를 먼저 합쳐서 보여주고, 수능 전용 부적은 "함께 보면 좋은
    // 부적"에 이어서 노출한다 — 대입 수험생도 여전히 수능 부적을 바로
    // 찾을 수 있다(알트 목록에 포함).
    final list = category == null
        ? const <TalismanItem>[]
        : category == 'suneung'
        ? [
            ...provider.catalog.where((k) => k.category == 'exam'),
            ...provider.catalog.where((k) => k.category == 'suneung'),
          ]
        : provider.catalog.where((k) => k.category == category).toList();
    final k = list.isNotEmpty ? list.first : null;
    final alt = list.length > 1
        ? list.skip(1).take(3).toList()
        : const <TalismanItem>[];

    return Scaffold(
      backgroundColor: ShrineV3Colors.paper,
      appBar: AppBar(
        backgroundColor: ShrineV3Colors.paper,
        foregroundColor: ShrineV3Colors.ink,
        elevation: 0,
        title: const Text('추천받기'),
      ),
      // [사용자 버그 리포트 — 디자인 핸드오프 불일치 #1] 06 추천받기는
      // 프로토타입 <Nav/> 포함 화면.
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(
              '마음에 걸리는 것을\n하나 골라 주세요',
              style: ShrineV3TextStyles.title.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.asset(
                    shrineSceneImage('talk'),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: ShrineV3Colors.paperDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ShrineV3Colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ShrineV3Colors.line),
                    ),
                    child: Text(
                      k != null
                          ? (_saju != null
                                ? '$nickname님의 사주를 보니\n${k.name}가 가장 잘 맞아요.'
                                : '고르신 소망엔\n${k.name}를 추천드려요.')
                          : '지금 가장 마음에 걸리는 것은\n무엇인가요?',
                      style: ShrineV3TextStyles.body.copyWith(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kShrineWishes.map((w) {
                final on = _selectedWish == w.$2;
                return GestureDetector(
                  onTap: () => setState(() => _selectedWish = on ? null : w.$2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: on ? ShrineV3Colors.ink : ShrineV3Colors.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: on ? ShrineV3Colors.ink : ShrineV3Colors.line,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          w.$1,
                          style: TextStyle(
                            color: on
                                ? ShrineV3Colors.gold
                                : ShrineV3Colors.seal,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          w.$2,
                          style: TextStyle(
                            color: on
                                ? ShrineV3Colors.paper
                                : ShrineV3Colors.ink2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            if (k == null) _SajuCard(saju: _saju),
            if (k != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ShrineV3Colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ShrineV3Colors.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TalismanThumb(talisman: k, width: 84, height: 180),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '推 · 가장 잘 맞는 부적',
                            style: ShrineV3TextStyles.mono.copyWith(
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            k.name,
                            style: ShrineV3TextStyles.title.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _whyLine('命', _heartLine(category, _saju)),
                          _whyLine('願', '고른 소망 「${wish?.$2 ?? ''}」과 쓰임이 같아요'),
                          _whyLine('用', k.aim),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (alt.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '함께 보면 좋은 부적',
                      style: ShrineV3TextStyles.body.copyWith(fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShrineV3PickScreen(),
                        ),
                      ),
                      child: Text(
                        '${category == 'suneung' ? '시험 · 합격' : kShrineCategoryLabels[category]} ${list.length} ›',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: alt.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final a = alt[i];
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ShrineV3DetailScreen(talismanId: a.id),
                          ),
                        ),
                        child: SizedBox(
                          width: 92,
                          child: Column(
                            children: [
                              TalismanThumb(talisman: a, width: 92, height: 96),
                              const SizedBox(height: 4),
                              Text(
                                a.name,
                                style: ShrineV3TextStyles.body.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShrineV3DetailScreen(talismanId: k.id),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShrineV3Colors.seal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('${k.name}로 쓰기 ›'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ShrineV3PickScreen(),
                    ),
                  ),
                  child: const Text('다른 부적 직접 고르기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _whyLine(String icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          icon,
          style: const TextStyle(
            color: ShrineV3Colors.seal,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: ShrineV3TextStyles.ui.copyWith(fontSize: 11.5),
          ),
        ),
      ],
    ),
  );
}

/// [정통사주 연결 보강] 카테고리별 "命" 한 줄 — 실제 [SajuInterpreter]
/// 결과를 사용해 만든다. `_saju`가 null(비로그인/프로필 미완료)이면 절대
/// "사주를 보니"류의 허위 주장을 하지 않고, 정직하게 프로필 등록을
/// 안내하는 문구로 대체한다. [SajuRules]가 아직 로드되지 않았거나 해석
/// 중 예외가 발생해도(드묾) 화면이 깨지지 않도록 안전한 기본 문구로
/// 폴백한다.
String _heartLine(String? category, SajuResult? saju) {
  if (saju == null) {
    switch (category) {
      case 'wealth':
        return '마이페이지에 생년월일을 등록하면 재물 기운까지 맞춰 드려요';
      case 'biz':
        return '마이페이지에 생년월일을 등록하면 사업·일 기운까지 맞춰 드려요';
      case 'love':
      case 'harmony':
        return '마이페이지에 생년월일을 등록하면 인연 기운까지 맞춰 드려요';
      case 'exam':
      case 'suneung':
        return '마이페이지에 생년월일을 등록하면 학업·시험 기운까지 맞춰 드려요';
      case 'health':
        return '마이페이지에 생년월일을 등록하면 건강 기운까지 맞춰 드려요';
      case 'ward':
        return '마이페이지에 생년월일을 등록하면 액운 기운까지 맞춰 드려요';
      default:
        return '고르신 소망에 맞춰 골라 드린 부적이에요';
    }
  }
  try {
    final rules = SajuRules.cachedOrNull;
    switch (category) {
      case 'wealth':
        final w = SajuInterpreter.interpretWealth(saju);
        return '${w.verdict} 사주 — ${w.message}';
      case 'biz':
        if (rules == null) break;
        final c = SajuInterpreter.interpretCareer(saju, rules);
        return '${c.structure} — ${c.message}';
      case 'love':
      case 'harmony':
        final l = SajuInterpreter.interpretLove(saju);
        return l.message;
      case 'exam':
      case 'suneung':
        final sin = SajuInterpreter.interpretSinsal(saju);
        final munchang = sin.list.where((e) => e.name.contains('文昌'));
        if (munchang.isNotEmpty) {
          return '文昌貴人(문창귀인) 보유 — ${munchang.first.meaning}';
        }
        if (rules == null) break;
        final dm = SajuInterpreter.interpretDayMaster(saju, rules);
        final fit = dm.careerFit.isNotEmpty ? dm.careerFit.first : '학업';
        return '${dm.title} 기운엔 $fit 분야 집중력이 잘 맞아요';
      case 'health':
        if (rules == null) break;
        final h = SajuInterpreter.interpretHealth(saju, rules);
        if (h.warnings.isNotEmpty) return h.warnings.first;
        return '${h.coreOrgans.join(', ')} 계통을 중심으로 기운을 보완해요';
      case 'ward':
        if (rules == null) break;
        final fe = SajuInterpreter.interpretFiveElements(saju, rules);
        if (fe.analysis.isNotEmpty) return fe.analysis.first;
        return '오행 균형을 맞춰 액운을 막아 줘요';
      default:
        if (rules == null) break;
        final dm = SajuInterpreter.interpretDayMaster(saju, rules);
        return dm.personality;
    }
  } catch (_) {
    // 해석 실패 시(드묾) 아래 기본 문구로 폴백.
  }
  return '타고난 기운에 맞춰 부족한 기운을 채워요';
}

/// 소망 미선택 시 노출되는 "회원님의 사주" 카드 — 4주 + 오행 막대 + 일간
/// 캡션. [saju]가 null이면(미로그인/프로필 미완료) 안내 문구만 보여준다.
class _SajuCard extends StatelessWidget {
  const _SajuCard({required this.saju});
  final SajuResult? saju;

  @override
  Widget build(BuildContext context) {
    final s = saju;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShrineV3Colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShrineV3Colors.line),
      ),
      child: s == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '나의 사주',
                  style: ShrineV3TextStyles.body.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '마이페이지에서 실명·생년월일을 입력하면\n사주 기운에 맞는 부적을 보여드려요.',
                  style: ShrineV3TextStyles.ui.copyWith(fontSize: 12.5),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '나의 사주',
                      style: ShrineV3TextStyles.body.copyWith(fontSize: 14),
                    ),
                    Text(
                      '정통사주 연동 ✓',
                      style: ShrineV3TextStyles.ui.copyWith(
                        fontSize: 11,
                        color: ShrineV3Colors.jade,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _pillarCol('年', s.pillars['year']!.kr, false),
                    _pillarCol('月', s.pillars['month']!.kr, false),
                    _pillarCol('日', s.pillars['day']!.kr, true),
                    _pillarCol('時', s.pillars['hour']!.kr, false),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 70,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: ['목', '화', '토', '금', '수'].map((e) {
                      final n = s.fiveElementsCount[e] ?? 0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 18,
                            height: (8 + n * 10).toDouble(),
                            decoration: BoxDecoration(
                              color: n == 0
                                  ? ShrineV3Colors.line
                                  : ShrineV3Colors.seal,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _hanjaOf(e),
                            style: ShrineV3TextStyles.ui.copyWith(fontSize: 11),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: ShrineV3TextStyles.ui.copyWith(fontSize: 12.5),
                    children: [
                      const TextSpan(text: '타고난 기운은 '),
                      TextSpan(
                        text:
                            '${s.dayMaster.gan}${s.dayMaster.element} · ${s.dayMaster.image}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ShrineV3Colors.ink,
                        ),
                      ),
                      const TextSpan(text: '. 고르신 소망과 함께 보고 부적을 골라 드려요.'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _pillarCol(String label, String kr, bool isDay) => Column(
    children: [
      Text(label, style: ShrineV3TextStyles.ui.copyWith(fontSize: 11)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDay ? ShrineV3Colors.seal : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          kr,
          style: ShrineV3TextStyles.body.copyWith(
            fontSize: 13,
            color: isDay ? Colors.white : ShrineV3Colors.ink,
          ),
        ),
      ),
    ],
  );

  String _hanjaOf(String kr) => switch (kr) {
    '목' => '木',
    '화' => '火',
    '토' => '土',
    '금' => '金',
    '수' => '水',
    _ => kr,
  };
}
