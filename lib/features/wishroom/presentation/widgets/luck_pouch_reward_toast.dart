import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';

/// [소원방 MVP §13] 치성 보상으로 복주머니가 적립됐음을 알리는 토스트.
/// 기존 공통 [AppToast]를 그대로 재사용하고, 문구만 표준화한다.
class LuckPouchRewardToast {
  LuckPouchRewardToast._();

  static void show(BuildContext context, int amount) {
    AppToast.show(context, '복주머니 +$amount 적립되었어요');
  }
}
