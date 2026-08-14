import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/presentation/widgets/jeontong_result_text_extractor.dart';

void main() {
  test('빈약 결과(dict only category+message) 도 title+body≥2 보장', () {
    final raw = {'category': '자녀운', 'message': '식신·상관(남)/관성(여) 자녀성 분석'};
    final ext = JeontongResultTextExtractor(raw);
    expect(ext.title().isNotEmpty, true);
    expect(ext.body().length >= 2, true);
  });

  test('풍부한 결과(dict headline+summary) 는 headline title, summary 우선', () {
    final raw = {
      'category': '평생 총운',
      'headline': '일간 정(丁) 신약 — 식신 중심 인생',
      'summary': '재능과 표현으로 풍요를 이루는 삶',
      'core_nature': '촛불 같은 섬세한 인지',
      'personality': '온화하고 배려심 깊음',
    };
    final ext = JeontongResultTextExtractor(raw);
    expect(ext.title(), '일간 정(丁) 신약 — 식신 중심 인생');
    expect(ext.body().first.contains('재능과 표현'), true);
  });

  test('전부 빈 dict → 폴백 "준비 중" 2줄', () {
    final ext = JeontongResultTextExtractor({});
    expect(ext.title(), '운세');
    expect(ext.body().length, 2);
    expect(ext.body().join(' ').contains('준비 중'), true);
  });

  test('easyTermHints 는 한자 토큰을 1~3개 반환', () {
    final raw = {'summary': '일간 정(丁) 신약 인사 동업식신 적합 식신과 재성 균형'};
    final ext = JeontongResultTextExtractor(raw);
    expect(ext.easyTermHints().isNotEmpty, true);
    expect(ext.easyTermHints().length <= 3, true);
  });
}
