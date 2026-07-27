import 'package:flutter/foundation.dart';
import '../../../../core/utils/load_state.dart';
import '../data/face_repository.dart';
import '../domain/face_model.dart';

/// 07단계(추가) §3.3 - AI 관상 Provider
/// 손금(PalmProvider)과 동일한 패턴 - 카메라/갤러리로 선택한 이미지를
/// 임시 보관하는 [selectedImageBytes] 상태를 추가한다.
///
/// 07단계(추가, 수정) §3.3 - Flutter Web은 `dart:io`의 File을 지원하지 않으므로
/// (웹에서 File.readAsBytes 등 호출 시 UnsupportedError 발생), 웹/Android 모두에서
/// 동일하게 동작하는 [Uint8List](바이트 배열) 기반으로 이미지를 보관한다.
class FaceProvider extends ChangeNotifier {
  final FaceRepository _repository;
  FaceProvider(this._repository);

  LoadState<FaceResultModel> _state = const LoadState.initial();
  LoadState<FaceResultModel> get state => _state;

  List<FaceResultModel> _history = [];
  List<FaceResultModel> get history => _history;

  // 07단계(추가) §3.3 - 촬영/선택된 관상 사진(바이트). 분석 완료 즉시 자동 해제됨.
  Uint8List? _selectedImageBytes;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  bool get hasSelectedImage => _selectedImageBytes != null;

  /// FaceCaptureScreen에서 카메라 촬영 또는 갤러리 선택 완료 시 호출
  void setSelectedImage(Uint8List bytes) {
    _selectedImageBytes = bytes;
    notifyListeners();
  }

  /// 사용자가 미리보기에서 선택을 취소/재선택할 때 호출
  void clearSelectedImage() {
    _selectedImageBytes = null;
    notifyListeners();
  }

  Future<void> analyze() async {
    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.analyze(image: _selectedImageBytes);

    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '관상 분석에 실패했습니다.');
    }

    // 09단계 §7 개인정보보호 원칙 - 분석이 끝나면(성공/실패 무관) 사진은 즉시 파기(메모리 해제)
    _selectedImageBytes = null;
    notifyListeners();
  }

  Future<void> retry() => analyze();

  Future<void> loadHistory() async {
    final result = await _repository.getHistory();
    if (result.success) {
      _history = result.data!;
      notifyListeners();
    }
  }

  void selectFromHistory(String id) {
    final found = _history.where((e) => e.id == id).toList();
    if (found.isNotEmpty) {
      _state = LoadState.success(found.first);
      notifyListeners();
    }
  }
}
