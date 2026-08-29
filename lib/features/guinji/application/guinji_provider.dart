import 'package:flutter/foundation.dart';

import '../../auth/domain/user_model.dart';
import '../../home/domain/jeontong_eighty_report_builder.dart';
import '../../home/domain/manseryeok/saju_profile.dart';
import '../../home/domain/user_profile_to_jeontong_adapter.dart';
import '../data/guinji_repository.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_saju_adapter.dart';

/// 귀인지도(Guinji Map) 전역 상태 — [GuinjiRepository]를 감싸고, 화면들이
/// 공유하는 map/members/relationships 상태를 관리한다.
///
/// [절대 원칙] 이 Provider는 결제·재화를 직접 다루지 않는다(모든 지급은
/// 서버 트랜잭션 내부에서만 발생 — 클라이언트는 결과를 조회할 뿐이다).
/// 로딩/에러 상태는 "느낌표 금지" 원칙에 따라 문구에 느낌표를 쓰지 않는다.
class GuinjiProvider extends ChangeNotifier {
  GuinjiProvider(this._repository);

  final GuinjiRepository _repository;

  bool _isLoading = false;
  String? _error;
  String? _errorCode;

  /// 서버가 확정한 지도 메타(mapId/name/token/createdAt). 지도가 없으면 null.
  Map<String, dynamic>? _map;

  /// 서버 응답 원본 members 리스트(각: memberId/name/solarLunar/birthDate/
  /// birthTime/birthTimeMissing/joined).
  List<Map<String, dynamic>> _members = const [];

  /// 서버 응답 원본 relationships 리스트(각: memberId/relationType/
  /// chemistryScore/ohaengEvidence).
  List<Map<String, dynamic>> _relationships = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 마지막 실패의 서버 에러 코드('UNAUTHORIZED'|'NOT_FOUND'|'EXPIRED' 등).
  /// [GuinjiJoinScreen]이 'UNAUTHORIZED'일 때만 로그인 유도로 분기하는 데 사용.
  String? get errorCode => _errorCode;
  Map<String, dynamic>? get map => _map;
  bool get hasMap => _map != null;
  String? get mapId => _map?['mapId'] as String?;
  String? get mapName => _map?['name'] as String?;
  String? get mapToken => _map?['token'] as String?;

  /// [GuinjiPerson] 리스트로 매핑된 멤버 목록(랭킹/지도 화면이 그대로 사용).
  List<GuinjiPerson> get people {
    final relationByMemberId = {
      for (final r in _relationships) r['memberId'] as String: r,
    };
    return _members
        .map(
          (m) => GuinjiPerson.fromServerJson(
            member: m,
            relation: relationByMemberId[m['memberId']],
          ),
        )
        .toList();
  }

  bool get isEmpty => _members.isEmpty;

  /// 온보딩 화면 CTA — 로그인 회원 [UserModel]로 사주를 계산하고
  /// `POST /guinji/maps`를 호출해 내 귀인지도를 생성한다(이미 있으면 서버가
  /// 기존 지도를 그대로 반환 — 멱등).
  ///
  /// 반환값: 성공 시 true(호출부는 이후 [loadMyMap] 또는 이미 채워진
  /// [map]/[people]을 그대로 사용), 실패 시 false([error] 참고.
  Future<bool> createMapForUser(UserModel user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final jeontongInput = userModelToJeontongInput(user);
    if (jeontongInput == null) {
      _isLoading = false;
      _error = '생년월일 정보가 없어 사주를 계산할 수 없습니다. 프로필을 먼저 완성해 주세요.';
      notifyListeners();
      return false;
    }

    try {
      final kst = jeontongInput.birthDateTimeUtc.add(const Duration(hours: 9));
      final sajuGender = jeontongInput.gender == 'F' ? 'female' : 'male';
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: sajuGender,
        isLunar: jeontongInput.isLunar,
        isLeapMonth: jeontongInput.effectiveIsLeapMonth,
        referenceDate: DateTime.now(),
      );
      final SajuProfile profile = built.profile;
      final sajuJson = guinjiSajuInputFromProfile(profile);

      final result = await _repository.createMap(saju: sajuJson);
      if (!result.success) {
        _isLoading = false;
        _error = result.errorMessage ?? '지도 생성에 실패했습니다.';
        notifyListeners();
        return false;
      }

      // 생성/조회 성공 후 곧바로 최신 상태(members/relationships 포함)를
      // 다시 불러온다 — createMap 응답에는 mapId/token만 있고 members는
      // 없으므로(신규 생성 직후에는 어차피 members가 비어 있음), 단일 소스인
      // fetchMyMap으로 통일한다.
      return await loadMyMap();
    } catch (e) {
      _isLoading = false;
      _error = '사주 계산 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// `GET /guinji/maps/me` 호출 — 지도/멤버/관계 최신 상태로 갱신.
  /// 지도가 없으면(온보딩 전) [map]이 null로 유지되고 true를 반환한다
  /// (에러 아님 — 호출부가 hasMap으로 분기).
  Future<bool> loadMyMap() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.fetchMyMap();
    if (!result.success) {
      _isLoading = false;
      _error = result.errorMessage ?? '지도 조회에 실패했습니다.';
      notifyListeners();
      return false;
    }

    final data = result.data;
    if (data == null) {
      _map = null;
      _members = const [];
      _relationships = const [];
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _map = data['map'] as Map<String, dynamic>?;
    _members = (data['members'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    _relationships = (data['relationships'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// 참여(join) 화면 — 지인(guest)이 자신의 생년월일 정보를 제출해 지도에
  /// 합류한다. gender는 참여 폼에 입력 필드가 없으므로 기본값 'M'을 사용한다
  /// (RelationJudger의 판정 로직·오행 계산은 gender를 사용하지 않으므로
  /// 결과에 영향이 없다 — 천간/지지 기반 계산이기 때문).
  Future<Map<String, dynamic>?> joinMap({
    required String mapId,
    required String name,
    required bool isLunar,
    required DateTime birthDate,
    String? birthTime, // 'HH:mm', null이면 시간 미상
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      int hour = 12;
      int minute = 0;
      if (birthTime != null && birthTime.contains(':')) {
        final parts = birthTime.split(':');
        hour = int.tryParse(parts[0]) ?? 12;
        minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      }
      final localDateTime = DateTime(
        birthDate.year,
        birthDate.month,
        birthDate.day,
        hour,
        minute,
      );
      final kst = localDateTime; // 이미 KST 벽시계 입력으로 간주(참여 폼은 KST 사용자 기준).

      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: 'male',
        isLunar: isLunar,
        isLeapMonth: false,
        referenceDate: DateTime.now(),
      );
      final sajuJson = guinjiSajuInputFromProfile(built.profile);

      final birthDateStr =
          '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';

      final result = await _repository.joinMap(
        mapId: mapId,
        name: name,
        solarLunar: isLunar ? 'lunar' : 'solar',
        birthDate: birthDateStr,
        birthTime: birthTime,
        saju: sajuJson,
      );

      _isLoading = false;
      if (!result.success) {
        _error = result.errorMessage ?? '참여에 실패했습니다.';
        notifyListeners();
        return null;
      }
      notifyListeners();
      return result.data;
    } catch (e) {
      _isLoading = false;
      _error = '참여 처리 중 오류가 발생했습니다: $e';
      notifyListeners();
      return null;
    }
  }

  /// GET /guinji/g/{token} — 딥링크 초대 유효성 확인.
  Future<Map<String, dynamic>?> fetchInvite(String token) async {
    _isLoading = true;
    _error = null;
    _errorCode = null;
    notifyListeners();

    final result = await _repository.fetchInvite(token);
    _isLoading = false;
    if (!result.success) {
      _error = result.errorMessage ?? '초대 링크를 확인할 수 없습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return null;
    }
    notifyListeners();
    return result.data;
  }

  /// POST /guinji/unlocks — 관계 상세 스페셜 해설 해금.
  /// 성공 시 true(호출부에서 UI 잠금 해제 처리), 실패 시 false([error] 참고).
  Future<bool> unlock({
    required String memberId,
    required String method,
  }) async {
    _error = null;
    final result = await _repository.unlock(memberId: memberId, method: method);
    if (!result.success) {
      _error = result.errorMessage ?? '해금에 실패했습니다.';
      notifyListeners();
      return false;
    }
    return true;
  }

  void clearError() {
    _error = null;
    _errorCode = null;
    notifyListeners();
  }
}
