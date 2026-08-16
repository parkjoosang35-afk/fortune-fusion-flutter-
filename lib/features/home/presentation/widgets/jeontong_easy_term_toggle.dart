import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// [정통사주 전문 용어 → 쉬운 설명] `assets/jeontong/easy_terms.json` 파싱/캐시.
///
/// [STEP 0-B raw 로 확정한 실제 스키마 — 미션 템플릿의 가정과 다름]
/// 원본은 미션이 가정한 `{ts}` / `{termsMap}` / `{terms:[...]}` 래퍼가
/// 아니라, 최상위가 곧바로 `{ "<용어>": {"easy": "...", "detail": "..."},
/// ... }` 형태의 flat map이다. 메타데이터 키 `_description` 1개만 용어가
/// 아니므로 건너뛴다. (예: "일간" → {"easy":"나 자신", ...})
class EasyTerms {
  const EasyTerms._(this._byTerm);

  final Map<String, String> _byTerm;

  static const String _assetPath = 'assets/jeontong/easy_terms.json';

  /// 프로세스 전역 1회 로드 캐시.
  static EasyTerms? _cached;

  /// 이미 로드돼 있으면 즉시(동기) 반환, 아직이면 null.
  /// [JeontongEasyTermToggle]은 이 값만 동기적으로 읽는다 — Future 를
  /// 직접 구독(FutureBuilder 등)하지 않는다. 자세한 이유는
  /// [JeontongEasyTermToggle]의 클래스 문서 참고.
  static EasyTerms? get cachedOrNull => _cached;

  static Future<EasyTerms> _load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    final byTerm = <String, String>{};
    if (decoded is Map) {
      decoded.forEach((key, value) {
        if (key == '_description') return;
        if (value is Map && value['easy'] is String) {
          byTerm[key.toString()] = value['easy'] as String;
        }
      });
    }
    return EasyTerms._(byTerm);
  }

  /// fire-and-forget 프리로드. 실패해도 예외를 삼켜 화면에 영향을 주지
  /// 않는다(실패 시 각 토글은 "쉬운 설명 준비 중" 폴백을 그대로 보여줌).
  /// 이미 로드돼 있으면 즉시 반환한다(중복 로드 없음).
  static Future<void> preload() async {
    if (_cached != null) return;
    try {
      _cached = await _load();
    } catch (_) {
      // 자산 로드 실패 — 폴백 문구로 조용히 대체.
    }
  }

  /// 테스트 전용 — 캐시 초기화.
  static void resetForTest() => _cached = null;

  String? explain(String token) => _byTerm[token];
}

/// 전문 용어 한 개를 탭하면 같은 자리(inline)에서 쉬운 설명이
/// [ExpansionTile]로 펼쳐지고, 다시 탭하면 접히는 토글 위젯.
///
/// [설계 원칙 — 프레임 예산 보호]
/// `jeontong_eighty_result_frame_bench_test.dart`(never-touch)는
/// `JeontongEightyResultScreen` 진입 시 안정화 프레임이 warm≤3/cold≤6
/// 이어야 함을 고정 계약으로 삼는다. 이 위젯은 `EasyTerms.preload()`
/// (비동기)가 끝나는 시점에 맞춰 스스로 `setState()`를 호출하지
/// 않는다 — 그렇게 하면 화면 진입 후 추가 프레임이 예약되어 계약이
/// 깨질 수 있다. 대신 build() 시점에 이미 캐시가 준비돼 있으면 그
/// 값을, 아니면 폴백 문구를 "정적으로" 보여준다. 실제 사용 흐름에서는
/// 결과 화면 `initState()`에서 이미 `preload()`를 fire-and-forget 으로
/// 미리 걸어두므로(로컬 5KB JSON, 지연은 사실상 무시할 수준), 사용자가
/// 실제로 탭할 즈음에는 이미 로드가 끝나 있을 가능성이 매우 높다.
class JeontongEasyTermToggle extends StatefulWidget {
  const JeontongEasyTermToggle({super.key, required this.token});

  /// easy_terms.json 의 키(예: "일간", "신강", "식신").
  final String token;

  /// 결과 화면 진입 시 1회 호출하는 프리로드 진입점.
  static Future<void> preload() => EasyTerms.preload();

  @override
  State<JeontongEasyTermToggle> createState() => _JeontongEasyTermToggleState();
}

class _JeontongEasyTermToggleState extends State<JeontongEasyTermToggle> {
  @override
  Widget build(BuildContext context) {
    final explanation =
        EasyTerms.cachedOrNull?.explain(widget.token) ?? '쉬운 설명 준비 중';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        key: PageStorageKey<String>('jeontong_easy_term_${widget.token}'),
        initiallyExpanded: false,
        title: Text(widget.token),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(explanation),
            ),
          ),
        ],
      ),
    );
  }
}
