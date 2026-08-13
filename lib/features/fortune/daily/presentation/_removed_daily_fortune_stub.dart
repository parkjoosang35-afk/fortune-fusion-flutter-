import 'package:flutter/material.dart';

/// 2026-08-13 결정으로 일간 운세는 정통사주 80항목에 통합되었다.
/// 기존 라우트(/fortune/daily/{intro,input,loading,result}) 진입 시
/// 안내문만 노출하는 dead-letter 화면. 히스토리 데이터는 Read-Only로 보존.
class RemovedDailyFortuneStub extends StatelessWidget {
  const RemovedDailyFortuneStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일간 운세'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '일간 운세는 정통사주 80항목으로 통합되어 제공됩니다.\n'
            '메뉴의 "정통사주 80항목"에서 확인하실 수 있어요.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
