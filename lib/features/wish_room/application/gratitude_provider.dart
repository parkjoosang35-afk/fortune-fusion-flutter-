import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/gratitude_repository.dart';
import '../domain/gratitude_models.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';

/// 감사 도장(GratitudeSeal, "답례 도장") 전역 Provider.
///
/// [재화 절대 원칙] 이 Provider는 복주머니 잔액을 직접 보유하지 않는다.
/// 답례 도장을 찍으면 서버가 sender(+2)/recipient(+5) 양측에 자동 지급하므로,
/// 성공 시 [LuckPouchProvider.load]를 호출해 서버 원장을 다시 조회한다
/// (ShopProvider.purchase와 동일한 "서버 확정만 신뢰" 패턴).
///
/// [명칭 주의] 기존 `BlessingBagPolicyAdapter.giftSeal()`("감사 도장 보내기")과
/// 이름은 유사하지만 완전히 다른 기능이다. 이 Provider/관련 UI는 "답례 도장"
/// 문구를 사용해 구분한다.
class GratitudeProvider extends ChangeNotifier {
  final GratitudeRepository _repo;
  final LuckPouchProvider _pouch;

  GratitudeProvider(this._repo, this._pouch);

  List<GratitudeSealableCandidate> _sealable = const [];
  List<GratitudeSeal> _received = const [];

  bool _isLoading = false;
  String? _error;

  /// 답례 진행 중인 sourcePouchId 집합 — 중복 탭 방지.
  final Set<int> _sealingIds = {};

  List<GratitudeSealableCandidate> get sealable => _sealable;
  List<GratitudeSeal> get received => _received;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get sealableCount => _sealable.length;

  bool isSealing(int sourcePouchId) => _sealingIds.contains(sourcePouchId);

  String? lastSealError;

  /// sealable + received 목록을 함께 로드한다.
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _fetchSealableSafely(),
        _fetchReceivedSafely(),
      ]);
      _sealable = results[0] as List<GratitudeSealableCandidate>;
      _received = results[1] as List<GratitudeSeal>;
    } catch (e) {
      _error = '감사 도장 목록을 불러오지 못했습니다.';
      debugPrint('[GratitudeProvider] loadAll 실패 -> $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 비로그인 상태에서는 401이 발생할 수 있다 — 조용히 빈 목록으로 대체.
  Future<List<GratitudeSealableCandidate>> _fetchSealableSafely() async {
    try {
      return await _repo.fetchSealable();
    } catch (_) {
      return const [];
    }
  }

  Future<List<GratitudeSeal>> _fetchReceivedSafely() async {
    try {
      return await _repo.fetchReceived();
    } catch (_) {
      return const [];
    }
  }

  /// [sourcePouchId]에 답례 도장을 찍는다. 성공 시 true, 실패 시 false를
  /// 반환하고 [lastSealError]에 사용자 표시용 메시지를 남긴다.
  Future<bool> seal(int sourcePouchId) async {
    if (_sealingIds.contains(sourcePouchId)) return false;
    lastSealError = null;
    _sealingIds.add(sourcePouchId);
    notifyListeners();

    try {
      await _repo.seal(sourcePouchId);
      // 목록에서 제거(낙관적 업데이트가 아니라, 이미 서버가 확정한 뒤이므로
      // 즉시 반영해도 안전하다).
      _sealable = _sealable
          .where((c) => c.sourcePouchId != sourcePouchId)
          .toList();
      _sealingIds.remove(sourcePouchId);
      notifyListeners();
      // [재화 절대 원칙] 잔액은 LuckPouchProvider(→WalletProvider) 경로로만
      // 갱신한다 — 서버가 확정한 값을 다시 조회해 신뢰한다.
      await _pouch.load();
      // received 목록도 최신화(내가 찍은 도장은 recipient 관점 목록에는
      // 나타나지 않지만, 동일 세션 내 일관성을 위해 재조회해둔다).
      unawaited(_refreshReceivedQuietly());
      return true;
    } on GratitudeException catch (e) {
      lastSealError = e.message;
      _sealingIds.remove(sourcePouchId);
      notifyListeners();
      return false;
    } catch (e) {
      lastSealError = '답례 도장 처리 중 오류가 발생했습니다.';
      _sealingIds.remove(sourcePouchId);
      notifyListeners();
      debugPrint('[GratitudeProvider] seal 실패 -> $e');
      return false;
    }
  }

  Future<void> _refreshReceivedQuietly() async {
    try {
      _received = await _repo.fetchReceived();
      notifyListeners();
    } catch (_) {
      // 무시 — received 목록은 다음 loadAll()에서 다시 시도된다.
    }
  }
}
