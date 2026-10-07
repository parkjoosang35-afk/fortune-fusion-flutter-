import 'package:flutter/material.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 핸드오프] Reduce Motion(시스템 설정)
/// 감지 헬퍼.
///
/// docs/08_QA_체크리스트.md "E. 모션·접근성" §3 "Reduce Motion On: 회전·
/// 반짝임·부유 정지, 03 크로스페이드" 및 docs/04_모션.md §2/§5:
/// - A-01~A-07(Bagua 회전, 별 필드 반짝임, 봉인 카드 부유, 장면 오브제
///   애니메이션, 대운 별점/노드 펄스) 전부 정지(각 루프의 0% 상태로 고정).
/// - 03(CalculatingScreen) 단계 전환: 위치 이동·응축 대신 300ms 크로스
///   페이드. 순서·데이터·타이밍 로직은 동일 유지.
/// - M-01(디멘전 진입 원형 확산) → 300ms 크로스페이드.
/// - 06 복주머니 개봉/04 봉인 해제 → 300ms 페이드.
///
/// [발견된 결함] 기존 코드는 `MediaQuery.disableAnimations`(iOS/Android
/// "동작 줄이기" 시스템 설정과 연동되는 Flutter 표준 플래그)를 전혀 조회
/// 하지 않아, 이 섹션 전체가 구현되어 있지 않았다. 이 파일의
/// [sajuReduceMotion]을 모든 상시 루프·전환 분기에서 공용으로 사용한다.
bool sajuReduceMotion(BuildContext context) {
  return MediaQuery.of(context).disableAnimations;
}
