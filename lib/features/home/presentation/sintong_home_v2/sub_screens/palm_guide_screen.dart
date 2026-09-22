import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../widgets/sintong_sub_screen_scaffold.dart';

/// 손금·관상 진입 목차 화면 — README `screens/palm.html`.
class PalmGuideSubScreen extends StatelessWidget {
  const PalmGuideSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SintongSubScreenScaffold(category: SHomeV2Category.palm);
  }
}
