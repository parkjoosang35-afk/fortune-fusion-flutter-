/// [정통사주 80종 결과 콘텐츠 안전 추출] JeontongResultTextExtractor.
///
/// [STEP 0 raw 로 확정한 사실 — 미션 템플릿의 가정과 다름]
/// 1) 파일 경로: 미션은 `lib/features/fortune/jeontong/presentation/
///    widgets/...`를 가정했으나, 실제 결과 화면은
///    `lib/features/home/presentation/jeontong_eighty_result_screen.dart`
///    이다(직전 3개 미션에서도 반복 확인된 동일 패턴). 이 파일도 같은
///    디렉터리 규칙을 따라 `lib/features/home/presentation/widgets/`
///    아래에 둔다.
/// 2) 데이터 형태: 미션은 "80종 카테고리 결과 dict"(`category`/`headline`/
///    `summary`/`message`/`advice`/`spouse_god`/`asset_style`/... 같은 키를
///    가진 raw `Map<String,dynamic>`)가 결과 화면에 이미 존재한다고
///    가정했다. 그러나 실제로는 `JeontongReportBuilder.build()` →
///    `FortuneReport{hero: FortuneHero, sections: List<FortuneSection>}`
///    강타입 객체 그래프만 존재하며(fortune_report_model.dart 전체 확인,
///    `Map<String,dynamic>` 사용처는 전부 무관한 JSON 직렬화 코드였음),
///    raw dict 는 코드베이스 어디에도 없다.
///
/// [해결 방침] 이 클래스 자체의 공개 계약(dict 입력 → title()/body()/
/// easyTermHints())은 미션 스펙을 그대로 보존한다 — 어떤 스키마의 dict가
/// 들어와도 안전하게 표시하는 폴백 규칙이라는 목적 자체는 스키마 불문의
/// 범용 유틸리티로서 유효하기 때문이다. 대신 결과 화면 호출부
/// (`jeontong_eighty_result_screen.dart`의 `_ResultBody.build()` 단
/// 1곳)에서 이미 갖고 있는 `FortuneReport` 객체의 필드(hero.headline/
/// hero.subDescription/overview 섹션 body/세부 섹션 body들)를 얇은
/// 어댑터 dict로 변환해 이 클래스에 넘긴다. 즉 "dict 가 이미 존재한다"는
/// 가정 대신 "결과 화면이 dict 를 즉석에서 구성해 넘긴다"로 바뀐 것 뿐,
/// title()/body()/easyTermHints() 의 우선순위 로직·폴백 규칙은 미션이
/// 제시한 설계를 그대로 따른다.
///
/// 비용: dart:convert 미사용(직접 파싱 불필요), HTTP/AI/Random/
/// DateTime.now()/dart:io 전혀 사용하지 않음 — 순수 문자열/컬렉션 연산.
library;

class JeontongResultTextExtractor {
  const JeontongResultTextExtractor(this._raw);

  final Map<String, dynamic> _raw;

  static const List<String> _titlePriority = [
    'headline',
    'title',
    'name',
    'verdict',
    'category_theme',
  ];

  static const List<String> _bodyPriority = [
    'summary',
    'message',
    'personality',
    'core_nature',
    'overall',
    'advice',
    'structure',
    'style',
    'spouse_god',
    'lifetime_warnings',
    'asset_style',
    'work_style',
    'recommended_jobs',
    'marriage_timing',
    'lifestyle',
    'lucky_color',
    'lucky_direction',
    'lucky_number',
    'career_fit',
    'weaknesses',
    'strengths',
    'analysis',
  ];

  /// title ≥1줄 보장. `_titlePriority` 순서로 첫 non-empty 문자열 채택,
  /// 없으면 `message`의 첫 줄, 그마저 없으면 `category`, 최종 폴백 '운세'.
  String title() {
    for (final key in _titlePriority) {
      final v = _raw[key];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    final msg = _raw['message'];
    if (msg is String && msg.trim().isNotEmpty) return msg.split('\n').first;
    final cat = _raw['category'];
    if (cat is String && cat.trim().isNotEmpty) return cat;
    return '운세';
  }

  /// body ≥2줄 보장. `_bodyPriority` 순서로 문자열/리스트/맵을 평탄화해
  /// 최대 4줄까지 모으고, 2줄 미만이면 `message` 재활용 → 그래도 부족하면
  /// 고정 안내 문구 2줄로 폴백한다.
  List<String> body() {
    final out = <String>[];
    for (final key in _bodyPriority) {
      final v = _raw[key];
      if (v is String && v.trim().isNotEmpty) {
        for (final line in v.split('\n')) {
          final t = line.trim();
          if (t.isNotEmpty) out.add(t);
        }
      } else if (v is List) {
        for (final item in v) {
          if (item is String && item.trim().isNotEmpty) out.add(item.trim());
        }
      } else if (v is Map) {
        // 추천 직업·결혼 시기 등 서브 dict 는 한 줄로 평탄화.
        v.forEach((k, vv) {
          if (vv is String && vv.trim().isNotEmpty) {
            out.add('$k: $vv');
          }
        });
      }
      if (out.length >= 4) break; // body ≥2줄 보장 + 너무 길지 않게
    }
    if (out.length < 2) {
      // 빈약 폴백 — 메시지만 있는 케이스도 2줄 보장.
      final msg = _raw['message'];
      if (msg is String && msg.trim().isNotEmpty) {
        final parts = msg.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (parts.length >= 2) {
          out.addAll(parts.take(2));
        } else if (parts.isNotEmpty) {
          out.add(parts.first);
          out.add('상세 내용 보강 예정');
        }
      }
      if (out.isEmpty) {
        out.add('이 영역의 상세 해석을 준비 중입니다.');
        out.add('다음 업데이트에서 더 풍부한 내용이 추가됩니다.');
      }
    }
    return out.take(4).toList(growable: false);
  }

  /// 본문에서 한자/사주 전문 용어로 보이는 토큰을 최대 3개 추출한다.
  /// [JeontongEasyTermToggle]의 쉬운 설명 트리거용 힌트로 사용.
  List<String> easyTermHints() {
    final joined = body().join(' ');
    final tokens = <String>[];
    final regex = RegExp(
      r'[一-龥]{2,4}|신강|신약|식신|상관|편재|정재|정관|편관|정인|편인|비견|겁재',
    );
    for (final m in regex.allMatches(joined)) {
      final t = m.group(0);
      if (t != null && !tokens.contains(t)) tokens.add(t);
    }
    return tokens.take(3).toList(growable: false);
  }
}
