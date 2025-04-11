import 'package:flutter/foundation.dart';
import '../models/live_viewer.dart';

class LiveViewersProvider with ChangeNotifier {
  List<LiveViewer> _viewers = [];
  int _viewerCount = 0;
  bool _isLoading = false;
  String? _error;

  List<LiveViewer> get viewers => _viewers;
  int get viewerCount => _viewerCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void addViewer(LiveViewer viewer) {
    if (!_viewers.any((v) => v.userId == viewer.userId)) {
      _viewers.add(viewer);
      _viewerCount = _viewers.length;
      notifyListeners();
    }
  }

  void removeViewer(String userId) {
    _viewers.removeWhere((v) => v.userId == userId);
    _viewerCount = _viewers.length;
    notifyListeners();
  }

  void updateViewer(LiveViewer viewer) {
    final index = _viewers.indexWhere((v) => v.userId == viewer.userId);
    if (index != -1) {
      _viewers[index] = viewer;
      notifyListeners();
    }
  }

  void setViewers(List<LiveViewer> newViewers) {
    _viewers = newViewers;
    _viewerCount = _viewers.length;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  void clear() {
    _viewers.clear();
    _viewerCount = 0;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
