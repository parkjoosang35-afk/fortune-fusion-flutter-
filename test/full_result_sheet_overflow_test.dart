// [신통방통 반응형 화면 규격 통일 지시서] 전체 결과 저장·공유 바텀시트
// (FullResultSheet) 가로/세로 오버플로 회귀 테스트.
//
// 이 시트는 5개 결과 화면(운세/타로/관상/손금/소원성/귀인지도) 공통으로
// 호출되며, `fullResultSections(payload)`가 만드는 섹션 제목/본문을 캡처용
// RepaintBoundary 안에 그대로 나열한다 — 섹션 개수·제목·본문 길이가
// 결과 타입에 따라 크게 달라질 수 있으므로, 실제로 올 수 있는 "길이가
// 긴" payload(타로 5장 포지션, 긴 조언 등)로 렌더링해 오버플로 여부를
// 확인해야 한다.
//
// `originalPng == null`인 캡처 경로(`RepaintBoundary` 섹션 나열 Column)가
// 테스트 대상이다 — originalPng가 있는 분기는 Image.memory 하나만 그리는
// 단순 경로라 레이아웃 위험이 없다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/share/presentation/full_result_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cases = <(Size, double)>[
    (Size(390, 844), 1.0),
    (Size(360, 640), 1.3),
    (Size(320, 568), 1.5),
    (Size(320, 568), 2.0),
    (Size(320, 568), 2.5),
  ];

  // 타로처럼 positions(최대 5장) + advice + 매우 긴 본문을 담은 payload.
  Map<String, dynamic> buildLongPayload() => {
        'summary':
            '결과 요약 섹션 본문이 매우 길게 작성되어 여러 줄에 걸쳐 표시되는 테스트 케이스입니다. 좁은 화면과 큰 텍스트스케일이 겹쳐도 가로로 넘치지 않고 줄바꿈만 일어나야 합니다.',
        'positions': [
          {
            'label': '과거를 나타내는 아주 길게 작성된 포지션 라벨 테스트',
            'cardName': '매우 길고 상세한 카드 이름이 들어가는 경우를 테스트하기 위한 임의의 긴 문자열 카드명입니다',
            'isReversed': true,
            'interpretation':
                '이 카드는 과거의 경험이 현재에 영향을 주고 있음을 나타내며, 그 경험을 통해 배운 교훈을 지금 어떻게 활용하느냐가 중요한 시점임을 알려줍니다. 역방향으로 나온 만큼 아직 완전히 해소되지 않은 감정이 남아있을 수 있어요.',
          },
          {
            'label': '현재',
            'cardName': '매우 길고 상세한 두 번째 카드 이름 테스트 문자열입니다 역시 아주 깁니다',
            'isReversed': false,
            'interpretation': '현재 상황에 대한 매우 길게 작성된 해석 본문 텍스트로 여러 줄에 걸쳐 표시될 가능성이 높은 테스트 케이스입니다.',
          },
          {
            'label': '미래를 나타내는 포지션',
            'cardName': '세 번째 카드',
            'isReversed': false,
            'interpretation': '미래 해석',
          },
        ],
        'advice': {
          'label': '아주 길게 작성된 조언 섹션 라벨 텍스트 테스트용 긴 문자열입니다',
          'text':
              '꾸준히 노력하되 서두르지 않는 것이 중요합니다. 특히 금전 관련 결정은 신중하게 내리시고 주변 사람들과 충분히 상의한 뒤에 진행하시길 권하며, 이 조언은 매우 길게 작성되어 바텀시트 안에서 줄바꿈이 여러 번 일어나야 하는 테스트 케이스입니다.',
        },
        'luckyColor': '아주 길게 설명되는 행운의 색깔 이름 테스트 문자열 행운의 보라색 계열',
        'luckyNumber': '7',
      };

  for (final (size, scale) in cases) {
    final label = '${size.width.toInt()}x${size.height.toInt()}@$scale';

    testWidgets('FullResultSheet $label overflow 없어야 함', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showFullResultSheet(
                      context,
                      title:
                          '타로 결과: 아주 길고 상세한 제목이 들어가는 테스트 케이스 문자열입니다',
                      shareUrl: 'https://sintong.kr/r/test',
                      payload: buildLongPayload(),
                    ),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      // showModalBottomSheet 애니메이션 완료까지 펌프.
      await tester.pumpAndSettle();

      final ex = tester.takeException();
      if (ex != null) {
        debugDumpRenderTree();
      }
      expect(ex, isNull, reason: 'FullResultSheet $label overflow 없어야 함: $ex');

      // 시트가 실제로 열렸는지(오류로 조용히 닫히지 않았는지) 확인.
      expect(find.text('전체 결과 공유'), findsOneWidget);
    });
  }
}
