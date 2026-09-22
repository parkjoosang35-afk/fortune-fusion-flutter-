import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../widgets/sintong_sub_screen_scaffold.dart';

/// 귀인지도 진입 목차 화면 — README `screens/guide.html`.
class GuinjiGuideSubScreen extends StatelessWidget {
  const GuinjiGuideSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SintongSubScreenScaffold(category: SHomeV2Category.guide);
  }
}
