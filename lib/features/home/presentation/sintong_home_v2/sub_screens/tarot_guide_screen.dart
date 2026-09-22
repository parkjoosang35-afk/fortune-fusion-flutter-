import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../widgets/sintong_sub_screen_scaffold.dart';

/// 타로 진입 목차 화면 — README `screens/tarot.html`.
class TarotGuideSubScreen extends StatelessWidget {
  const TarotGuideSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SintongSubScreenScaffold(category: SHomeV2Category.tarot);
  }
}
