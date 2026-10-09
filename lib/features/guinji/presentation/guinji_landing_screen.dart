import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_provider.dart';
import '../application/guinji_provider.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_intro_cinematic.dart';

/// L · Landing — `/guinji-map`
///
/// [2026 디자인 핸드오프] "01 인트로 시네마틱"(§05-1) — 검정 배경 + 별
/// 46개 → 나(84px) 등장 → 오행 원 그리기 → 인연 6명 유성 도착 → 빛
/// 폭발 → 타이틀 글자별 등장 + 인원 카운터 → 금색 CTA "내 지도 만들기".
/// 13.5초 루프, 실제 애니메이션 구현은 [GuinjiIntroCinematic]에 있다.
///
/// 흐름: 이미 지도가 있는 로그인 회원은 인트로를 건너뛰고 곧바로 M(내
/// 지도)으로 이동한다(§05-1 "이미 지도가 있으면 인트로를 건너뛰고
/// 지도로 갑니다"). 신규 방문자는 인트로를 보고 CTA를 누르면
/// I(Input, `/guinji-map/new`)로 이동한다.
class GuinjiLandingScreen extends StatefulWidget {
  const GuinjiLandingScreen({super.key});

  static const routeName = '/guinji-map';

  @override
  State<GuinjiLandingScreen> createState() => _GuinjiLandingScreenState();
}

class _GuinjiLandingScreenState extends State<GuinjiLandingScreen> {
  /// 로그인 회원의 기존 지도 여부를 서버에 확인하는 동안 인트로 대신
  /// 로딩 화면을 보여줄지 여부. 비로그인 사용자는 확인할 필요가 없으므로
  /// 처음부터 false로 시작해 인트로를 즉시 보여준다.
  bool _checkingExistingMap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRedirectToMyMap());
  }

  Future<void> _maybeRedirectToMyMap() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      // 비로그인 사용자는 지도를 가질 수 없으므로 곧바로 인트로를 보여준다.
      return;
    }

    setState(() => _checkingExistingMap = true);

    final guinji = context.read<GuinjiProvider>();
    await guinji.loadMyMap();

    if (!mounted) return;
    if (guinji.hasMap) {
      Navigator.of(context).pushReplacementNamed('/guinji-map/m');
      return;
    }

    // 지도가 없는 로그인 회원(신규)은 원래 흐름(인트로 → 정보입력 →
    // 결과 확인)을 그대로 거쳐야 한다.
    setState(() => _checkingExistingMap = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingExistingMap) {
      return Scaffold(
        backgroundColor: GmColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: GmColors.gold),
              const SizedBox(height: 16),
              Text(
                '내 귀인지도를 불러오고 있어요',
                style: TextStyle(
                  fontFamily: GmText.ui,
                  fontSize: 13,
                  color: GmColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GuinjiIntroCinematic(
      onStart: () => Navigator.of(context).pushNamed('/guinji-map/new'),
    );
  }
}
