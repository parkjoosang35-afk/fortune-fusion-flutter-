import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// [결과보기 통합 권한 시스템 v1.0, §7 "쿠팡 이동과 복귀(상태 복원) — 매우
/// 중요"] 사용자가 쿠팡 프리패스를 받으러 외부 브라우저/쿠팡 앱으로 이동하면,
/// OS가 메모리 확보를 위해 Flutter 프로세스를 완전히 종료(kill)할 수 있다.
/// 이 경우 [PendingPassRequestStore](메모리 static 필드, 로그인 흐름 전용)와
/// 달리 메모리에만 있는 상태는 전부 사라진다 — 반드시 디스크(SharedPreferences)에
/// 저장해야 프로세스가 재시작되어도 복원할 수 있다.
///
/// §7.1이 명시한 최소 저장 항목을 그대로 필드화한다:
///   content_type / content_id / selected_category / question / user_input /
///   result_request_id / return_route
///
/// [저장 시점] ResultAccessGateSheet에서 "오늘의 프리패스 받기" 선택 →
/// 쿠팡 방문 직전에 [save]를 호출한다.
/// [복원 시점] 앱 재시작(스플래시) 또는 resume 시 [consume]으로 꺼내
/// [return_route]로 이동한 뒤 저장된 입력값으로 화면/시트를 재구성한다.
/// 1회성 소비 — consume() 호출 시 즉시 삭제해 중복 복원을 막는다.
class PendingResultAccessReturn {
  const PendingResultAccessReturn({
    required this.contentType,
    this.contentId,
    this.selectedCategory,
    this.question,
    required this.userInput,
    this.resultRequestId,
    required this.returnRoute,
    required this.savedAt,
    this.contentTitle,
    this.categoryKey,
  });

  /// 정통사주/타로/운세 등(ResultAccessRepository.getQuote의 contentType과 동일값).
  final String contentType;
  final String? contentId;

  /// [비로그인 결과보기 복귀 지시서 R2] 결과보기 시트 제목에 쓰인 사람이
  /// 읽을 수 있는 콘텐츠 이름(예: '재물운', '프리랜서 운'). 로그인 복귀 후
  /// 시트를 다시 그릴 때 [selectedCategory](서버 카테고리 키, 사람이 읽기
  /// 어려운 값일 수 있음)와 별개로 정확한 표시 문구를 복원하기 위해
  /// 추가했다. null이면(과거 저장된 값 등) 호출부가 안전하게 폴백한다.
  final String? contentTitle;

  /// [비로그인 결과보기 복귀 지시서 R2] 서버 카테고리별 이용횟수 검증에
  /// 쓰이는 categoryKey. 원래 [ResultAccessGateSheet]가 받는 값과 동일 —
  /// 로그인 복귀 후 시트를 다시 열 때도 원래와 동일한 조건으로 quote를
  /// 조회해야 하므로 함께 저장한다.
  final String? categoryKey;

  /// 예: '재물운'(§7 예시 "정통사주 → 재물운 → 결과보기").
  final String? selectedCategory;
  final String? question;

  /// 입력화면에서 사용자가 입력한 값 전체(생년월일/이름/토픽 등)를 그대로
  /// JSON-호환 Map으로 보관한다 — 콘텐츠마다 필드가 다르므로 스키마를
  /// 고정하지 않고 자유 형식으로 둔다(§8.1 공통화 원칙과 동일한 이유,
  /// 콘텐츠별 전용 복원 로직을 여기 새로 만들지 않는다).
  final Map<String, dynamic> userInput;

  final String? resultRequestId;

  /// 복귀 후 되돌아갈 입력화면 라우트(예: '/ai-fortune/saju/input').
  final String returnRoute;

  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'contentType': contentType,
    'contentId': contentId,
    'selectedCategory': selectedCategory,
    'question': question,
    'userInput': userInput,
    'resultRequestId': resultRequestId,
    'returnRoute': returnRoute,
    'savedAt': savedAt.toIso8601String(),
    'contentTitle': contentTitle,
    'categoryKey': categoryKey,
  };

  factory PendingResultAccessReturn.fromJson(Map<String, dynamic> json) {
    return PendingResultAccessReturn(
      contentType: json['contentType'] as String,
      contentId: json['contentId'] as String?,
      selectedCategory: json['selectedCategory'] as String?,
      question: json['question'] as String?,
      userInput: (json['userInput'] as Map?)?.cast<String, dynamic>() ?? {},
      resultRequestId: json['resultRequestId'] as String?,
      returnRoute: json['returnRoute'] as String,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.now(),
      contentTitle: json['contentTitle'] as String?,
      categoryKey: json['categoryKey'] as String?,
    );
  }
}

/// SharedPreferences 기반 영속 저장소 — 프로세스 kill을 견뎌야 하므로
/// AuthTokenStore와 동일하게 shared_preferences를 사용한다(§7 요구사항,
/// 메모리 static 필드로는 불충분).
class PendingResultAccessReturnStore {
  PendingResultAccessReturnStore._();

  static const _kKey = 'pending_result_access_return';

  /// [만료 안전장치] 너무 오래된 pending 상태(예: 며칠 전에 저장된 채 방치된
  /// 경우)는 복원하지 않는다 — 사용자가 이미 잊었을 가능성이 높고, 오래된
  /// 입력값(생년월일 등)을 갑자기 복원해 혼란을 주지 않기 위함이다.
  static const Duration _maxAge = Duration(hours: 6);

  static Future<void> save(PendingResultAccessReturn state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(state.toJson()));
  }

  /// 저장된 상태를 꺼내면서 동시에 삭제한다(1회성 소비 — 중복 복원 방지).
  /// [_maxAge]를 초과했으면 조용히 폐기하고 null을 반환한다.
  static Future<PendingResultAccessReturn?> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return null;
    await prefs.remove(_kKey);
    try {
      final state = PendingResultAccessReturn.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (DateTime.now().difference(state.savedAt) > _maxAge) return null;
      return state;
    } catch (_) {
      return null;
    }
  }

  /// 저장된 상태가 있는지만 확인(소비하지 않음) — 스플래시/앱 시작 시
  /// "복원할 것이 있는지" 빠르게 판단할 때 사용.
  static Future<bool> hasPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
