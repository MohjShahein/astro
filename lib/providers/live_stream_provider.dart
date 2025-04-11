import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/live_stream.dart';
import '../models/live_chat_message.dart';

class LiveStreamProvider with ChangeNotifier {
  LiveStream? _currentStream;
  final List<LiveChatMessage> _chatMessages = [];
  bool _isJoined = false;

  LiveStream? get currentStream => _currentStream;
  List<LiveChatMessage> get chatMessages => _chatMessages;
  bool get isJoined => _isJoined;

  void setCurrentStream(LiveStream? stream) {
    _currentStream = stream;
    notifyListeners();
  }

  void setJoined(bool joined) {
    _isJoined = joined;
    notifyListeners();
  }

  void addChatMessage(LiveChatMessage message) {
    _chatMessages.add(message);
    notifyListeners();
  }

  void clearChatMessages() {
    _chatMessages.clear();
    notifyListeners();
  }

  void clear() {
    _currentStream = null;
    _chatMessages.clear();
    _isJoined = false;
    notifyListeners();
  }
}
