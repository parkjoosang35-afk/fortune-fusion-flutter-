import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/domain/user_model.dart';
import '../../wish_room/widgets/wish_room_dust.dart';
import '../../wish_room/widgets/wish_room_sigil.dart';
import '../application/guinji_provider.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import 'guinji_empty_map_screen.dart';
import 'guinji_map_screen.dart';

/// 귀인지도(Guinji Map) — 03. 로딩 화면.
///
/// [Phase G-2] `GUINJI_SCREENS.md` "03 · 로딩" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `LoadingScreen`): 사주 계산 중 신통도령 주문
/// 애니메이션 + 4.2초 진행바. 회전 마법진 2개(외곽 8s / 내부 5s 역회전)는
/// 소원방에 이미 구현되어 있는 [WishRoomSigilRing]을 재사용한다(색상만
/// Guinji 팔레트로 교체 — 신규 CustomPainter 재작성 방지).
///
/// [Phase G-2 범위] 실제 RelationJudger 판정·서버 API 호출은 아직 없다.
/// 진행바는 순수 로컬 타이머(4.2초)로만 진행되며, 완료 시 빈지도(S4)로
/// `pushReplacement`한다(뒤로가기 시 로딩 재노출 방지 — 앱 관례:
/// `tarot_intro_screen`/`jeontong_eighty_loading_screen`과 동일 패턴).
/// 원본 스펙의 "전면 광고 전환"(인터스티셜)은 백엔드/광고 정책 협의가
/// 필요하므로 이 Phase에서는 구현하지 않는다.
class GuinjiLoadingScreen extends StatefulWidget {
  const GuinjiLoadingScreen({super.key, required this.user});

  /// [귀인지도 실구현] 로그인 회원 프로필 — 이 화면 진입 시 실제
  /// `POST /guinji/maps` 호출(사주 계산 + API 연동)에 사용한다.
  final UserModel user;

  @override
  State<GuinjiLoadingScreen> createState() => _GuinjiLoadingScreenState();
}

class _GuinjiLoadingScreenState extends State<GuinjiLoadingScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 4200);
  static const List<String> _phases = [
    '사주 4기둥을 세우고 있어요',
    '오행의 흐름을 읽고 있어요',
    '귀인 신살을 찾는 중이에요',
    '관계의 결을 짚어보는 중이에요',
  ];

  late final AnimationController _controller;
  bool _animDone = false;
  bool _apiDone = false;
  bool _apiFailed = false;
  String? _apiErrorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animDone = true;
          _maybeNavigate();
        }
      })
      ..forward();

    // [귀인지도 실구현] 애니메이션과 동시에 실제 POST /guinji/maps 호출을
    // 진행한다. 애니메이션(4.2초)과 API 호출 중 더 늦게 끝나는 쪽을
    // 기다린 뒤에만 다음 화면으로 이동한다(로딩 연출과 실제 네트워크
    // 지연을 자연스럽게 흡수).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GuinjiProvider>();
      final ok = await provider.createMapForUser(widget.user);
      if (!mounted) return;
      _apiDone = true;
      _apiFailed = !ok;
      _apiErrorMessage = provider.error;
      _maybeNavigate();
    });
  }

  void _maybeNavigate() {
    if (!_animDone || !_apiDone || !mounted) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_apiFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiErrorMessage ?? '지도 생성에 실패했습니다.')),
        );
        Navigator.of(context).pop();
        return;
      }
      final provider = context.read<GuinjiProvider>();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => provider.isEmpty
              ? const GuinjiEmptyMapScreen()
              : GuinjiMapScreen(people: provider.people),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _phaseIndex(double progress) {
    final idx = (progress * _phases.length).floor();
    return idx.clamp(0, _phases.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          return Stack(
            children: [
              const Positioned.fill(child: GuinjiBgAtmosphere()),
              const Positioned.fill(
                child: WishRoomDust(count: 14, color: GuinjiColors.lavender),
              ),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const WishRoomSigilRing(
                        size: 280,
                        color: GuinjiColors.lavender,
                        opacity: 0.7,
                      ),
                      const WishRoomSigilRing(
                        size: 180,
                        color: GuinjiColors.aqua,
                        opacity: 0.55,
                        reverse: true,
                      ),
                      Image.asset(
                        'assets/images/home/doryeong/greeting.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                bottom: 60,
                child: Column(
                  children: [
                    const Text(
                      '지도를 여는 중',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: GuinjiFonts.display,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1.2,
                        letterSpacing: -0.4,
                        color: GuinjiColors.textPrimary,
                        shadows: [
                          Shadow(
                            color: GuinjiColors.glowShadow,
                            blurRadius: 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 20,
                      child: Text(
                        _phases[_phaseIndex(progress)],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.body,
                          fontSize: 13,
                          height: 1.4,
                          color: GuinjiColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 3,
                        child: Stack(
                          children: [
                            Container(color: GuinjiColors.surfaceCard),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: GuinjiColors.lavender,
                                  boxShadow: [
                                    BoxShadow(
                                      color: GuinjiColors.lavender,
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${(progress * 100).floor().toString().padLeft(2, '0')} / 100',
                      style: const TextStyle(
                        fontFamily: GuinjiFonts.mono,
                        fontSize: 9,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w500,
                        color: GuinjiColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
