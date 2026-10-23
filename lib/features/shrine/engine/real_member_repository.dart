// 신당(THE SHRINE) 회원 연결 — 후보 B 확정(신통방통 실제 로그인 연동).
//
// [배경 — 사용자 확정 사항] "신통방통 회원과 연결이 당연히 돼야하는데"라는
// 지적에 따라, 기존 SampleMemberRepository(고정된 가짜 회원 "박서연")를
// 대체한다. 신당 U12(어뷰징 방지) 서버 원장이 진짜 userId로 집계되려면
// 신당이 실제 로그인 사용자를 알아야 하므로, 이 교체가 선행 조건이다.
//
// [실명 vs 닉네임] 사용자 확정: "실명으로 해야해" — 닉네임을 이름 자리에
// 대신 쓰지 않는다. UserModel.realName(신규 필드, 마이페이지에서 1회 등록)을
// 그대로 사용하며, 미등록이면 null을 반환해 ConnectScreen이 "실명 등록
// 필요" 안내로 분기하게 한다(지어내지 않는다 — 엔진 경계 원칙과 동일 정신).
//
// [memberId] UserModel.id(실제 신통방통 유저 PK 문자열)를 그대로 쓴다.
// 서버 ShrineIssueLedger.userId가 이 값을 int로 파싱해 사용하므로, 다른
// 값으로 변형하지 않는다.
import '../../auth/application/auth_provider.dart';
import 'shrine_engine.dart';

/// 신당 전용 예외 — ConnectScreen이 구분해서 분기 처리할 수 있도록
/// 사유 코드를 둔다(로그인 필요/실명 미등록 두 가지).
class ShrineMemberLinkError implements Exception {
  const ShrineMemberLinkError(this.code, this.message);
  final String code; // 'NOT_LOGGED_IN' | 'NO_REAL_NAME'
  final String message;
}

class RealMemberRepository implements MemberRepository {
  RealMemberRepository(this._authProvider);

  final AuthProvider _authProvider;

  @override
  Future<MemberProfile> link({required Set<String> scope}) async {
    final user = _authProvider.currentUser;
    if (user == null || !_authProvider.isLoggedIn) {
      throw const ShrineMemberLinkError(
        'NOT_LOGGED_IN',
        '신통방통 로그인이 필요합니다.',
      );
    }
    // [실명 필수] scope에 'name'이 포함된 경우에만 실명을 요구한다 —
    // ConnectScreen에서 이름 토글을 꺼둔 경우(직접 적기 선택)까지 막을
    // 이유는 없다.
    final realName = user.realName?.trim();
    if (scope.contains('name') && (realName == null || realName.isEmpty)) {
      throw const ShrineMemberLinkError(
        'NO_REAL_NAME',
        '부적에 새길 실명을 먼저 등록해 주세요. (마이 > 설정 > 실명 등록/수정)',
      );
    }

    // [엔진 경계 원칙 동일 적용] scope에 없는 항목은 null로 생략한다 —
    // 지어내지 않는다.
    String? birth;
    if (scope.contains('birth') && user.birthDate != null) {
      // UserModel.birthDate는 'YYYY-MM-DD', 신당 포맷은 'YYYY.MM.DD'.
      birth = user.birthDate!.replaceAll('-', '.');
    }
    String? time;
    if (scope.contains('time')) {
      time = (user.birthTimeUnknown || user.birthTime == null)
          ? '모름'
          : user.birthTime;
    }

    return MemberProfile(
      memberId: user.id,
      name: scope.contains('name') ? realName : null,
      birth: birth,
      time: time,
    );
  }

  @override
  Future<void> unlink() async {
    // [설계 원칙 — shrine_engine.dart 상단 주석과 동일] 신당은 신통방통
    // 로그인 세션 자체를 건드리지 않는다. "연결 끊기"는 신당 쪽
    // ShrineSessionProvider.unlinkMember()(로컬 상태 초기화)만으로
    // 충분하며, 신통방통 로그아웃은 별도 경로(설정 화면)의 책임이다.
  }
}
