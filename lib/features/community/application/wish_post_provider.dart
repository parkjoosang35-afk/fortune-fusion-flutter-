import 'package:flutter/foundation.dart';
import '../data/wish_post_repository.dart';
import '../domain/wish_post_model.dart';

class WishPostProvider extends ChangeNotifier {
  final WishPostRepository _repository;
  WishPostProvider(this._repository);

  List<WishPostModel> _posts = [];
  bool _isLoading = false;

  List<WishPostModel> get posts => _posts;
  bool get isLoading => _isLoading;

  Future<void> loadFeed() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getFeed();
    if (result.success) _posts = result.data!;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createPost(String content) async {
    final result = await _repository.createPost(content);
    if (result.success) {
      await loadFeed();
      return true;
    }
    return false;
  }
}
