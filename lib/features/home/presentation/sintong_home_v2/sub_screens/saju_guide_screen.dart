import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../widgets/sintong_sub_screen_scaffold.dart';

/// 정통사주 진입 목차 화면 — README `screens/saju.html`.
class SajuGuideSubScreen extends StatelessWidget {
  const SajuGuideSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SintongSubScreenScaffold(category: SHomeV2Category.saju);
  }
}
